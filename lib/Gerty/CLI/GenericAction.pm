#  Copyright (C) 2010  Stanislav Sinyagin
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software

# Parent class for command-line interface handlers


package Gerty::CLI::GenericAction;

use base qw(Gerty::MixinLoader);

use strict;
use warnings;
use Expect qw(exp_continue);


# In case of initialization errors, print errors, but try not to
# abort the job execution. The CLI session is already initialized, so
# try to get the best of it

sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    my $acc = $self->device->{'ACCESS_HANDLER'};
    if( not $acc->has('expect') )
    {
        $Gerty::log->critical
            ('The access handler for device "' .
             $self->sysname .
             '" does not provide "expect" method');
        return undef;
    }
    
    foreach my $attr
        ( 'admin-mode', 'cli.timeout', 'cli.user-prompt', 'cli.admin-prompt',
          'cli.comment-string', '+cli.command-actions', 'cli.error-regexp',
          '+cli.handler-mixins')
    {
        $self->{$attr} = $self->device_attr($attr);
    }

    $self->{'prompt'} = $self->{'cli.user-prompt'};

    $self->{'command_actions'} = {};
    if( defined( $self->{'+cli.command-actions'} ) )        
    {
        foreach my $action (split(/,/o, $self->{'+cli.command-actions'}))
        {
            my $multicmd = $self->device_attr($action . '.multicommand');

            my @attrs;
            if( $multicmd and $multicmd > 0 )
            {
                foreach my $i (1 .. $multicmd)
                {
                    push( @attrs, $action . '.command-' . $i );
                }
            }
            else
            {
                push( @attrs, $action . '.command' );
            }

            my $commands = [];            
            foreach my $attr (@attrs)
            {
                my $cmd = $self->device_attr($attr);
                if( not defined($cmd) )
                {
                    $Gerty::log->error
                        ('+cli.command-actions defines the action "' .
                         $action . '", but attribute "' . $attr .
                         '" is not defined for device: ' .
                         $self->sysname);
                    next;
                }
                
                push( @{$commands}, $cmd );
                
                if( $Gerty::debug_level >= 2 )
                {
                    $Gerty::log->debug
                        ($self->sysname . ': ' .
                         'registered command "' . $cmd . '" for action "' .
                         $action . '"');
                }
            }

            if( scalar(@{$commands}) )
            {
                $self->{'command_actions'}{$action} = $commands;
                $Gerty::log->debug
                    ($self->sysname . ': ' .
                     'registered CLI action "' . $action . '"');
            }
        }            
    }

    # initialize mix-in modules

    $self->init_mixins('+cli.handler-mixins');
    
    foreach my $action (keys %{$self->{'command_actions'}})
    {
        if( $self->is_mixin_action($action) )
        {
            $Gerty::log->error
                ('Action ' . $action . ' defined in "+cli.command-actions" ' .
                 'conflicts with the action defined in mix-in module ' .
                 $self->mixin_origin($action));
        }
    }
    
    return $self;
}



sub expect
{
    my $self = shift;
    
    my $acc = $self->device->{'ACCESS_HANDLER'};
    return $acc->expect();
}
    


sub exec_command
{
    my $self = shift;
    my $cmd = shift;

    my $exp = $self->expect;
    my $failure;

    $Gerty::log->debug('Running a command: "' . $cmd . '" on "' .
                       $self->sysname . '"');
    
    $exp->send($cmd . "\r");    
    my $result = $exp->expect
        ( $self->{'cli.timeout'},
          ['-re', $self->{'prompt'}],
          ['timeout', sub {$failure = 'Connection timeout'}],
          ['eof', sub {$failure = 'Connection closed'}]);
    
    if( not $result )
    {
        my $err = 'Could not match the output for ' .
            $self->sysname . ': ' . $exp->before();
        
        $Gerty::log->error($err);            
        return {'success' => 0, 'content' => $err};
    }
    
    if( defined($failure) )
    {
        my $err = 'Failed executing "' . $cmd . '" for ' .
            $self->sysname . ': ' . $failure;
        
        $Gerty::log->error($err);
        return {'success' => 0, 'content' => $err};
    }

    my $content = $exp->before();
    $content =~ s/\r\n/\n/ogm;

    # outcomment the command from the top if it was echoed
    if( index($content, $cmd) == 0 and defined($self->{'cli.comment-string'}) )
    {
        $content = $self->{'cli.comment-string'} . ' ' . $content;
    }

    if( defined($self->{'cli.error-regexp'}) and
        length($self->{'cli.error-regexp'}) > 0 )
    {
        foreach my $line (split/\n/, $content)
        {
            if( $line =~ $self->{'cli.error-regexp'} )
            {
                my $err = 'Command "' . $cmd . '" failed on device "' .
                    $self->sysname . '": ' . $line;
                $Gerty::log->error($err);
                return {'success' => 0, 'content' => $err};
            }
        }
    }
    
    return {'success' => 1, 'content' => $content};
}



sub supported_actions
{
    my $self = shift;

    my $ret = [];
    push( @{$ret}, keys %{$self->{'command_actions'}} );
    push( @{$ret}, @{$self->SUPER::supported_actions()});
    return $ret;
}



sub do_action
{
    my $self = shift;    
    my $action = shift;

    if( $self->is_mixin_action($action) )
    {
        return $self->SUPER::do_action($action);        
    }
    
    if( not defined($self->{'command_actions'}{$action}) )
    {
        my $err = 'Unsupported action: ' . $action .
            ' in Gerty::CLI::GenericAction';
        $Gerty::log->error($err);
        return {'success' => 0, 'content' => $err};
    }
    
    my $content = '';
    foreach my $cmd (@{$self->{'command_actions'}{$action}})
    {
        my $result = $self->exec_command( $cmd );
        if( $result->{'success'} )
        {
            $content .= $result->{'content'};
        }
        else
        {
            return $result;
        }
    }
    
    return {'success' => 1, 'content' => $content};
}



        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
