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


package Gerty::CLIHandler::Generic;

use strict;
use warnings;
use Expect qw(exp_continue);


     
sub new
{
    my $class = shift;
    my $options = shift;
    my $self = {};
    bless $self, $class;
    
    foreach my $opt ('job', 'device')
    {
        if( not defined( $options->{$opt} ) )
        {
            $Gerty::log->critical($class . '::new - missing ' . $opt);
            return undef;
        }
    }

    $self->{'device'} = $options->{'device'};
    $self->{'job'} = $options->{'job'};
    my $acc = $self->{'device'}->{'ACCESS_HANDLER'};
    if( not $acc->has('expect') )
    {
        $Gerty::log->critical
            ('The access handler for device "' .
             $self->{'device'}->{'SYSNAME'} .
             '" does not provide "expect" method');
        return undef;
    }
    
    $self->{'expect'} = $acc->expect();

    foreach my $attr
        ( 'admin-mode', 'cli.timeout', 'cli.user-prompt', 'cli.admin-prompt',
          'cli.comment-string', 'cli.command-actions', 'cli.error-regexp' )
    {
        $self->{$attr} = $self->device_attr($attr);
    }

    $self->{'prompt'} = $self->{'cli.user-prompt'};

    $self->{'command_actions'} = {};
    if( defined( $self->{'cli.command-actions'} ) )        
    {
        foreach my $action (split(/\s*,\s*/o, $self->{'cli.command-actions'}))
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

            $self->{'command_actions'}{$action} = [];
            
            foreach my $attr (@attrs)
            {
                my $cmd = $self->device_attr($attr);
                if( not defined($cmd) )
                {
                    $Gerty::log->error
                        ('cli.command-actions defines the action "' .
                         $action . '", but attribute "' . $attr .
                         '" is not defined for device: ' .
                         $self->{'device'}->{'SYSNAME'});
                    return undef;
                }
                push( @{$self->{'command_actions'}{$action}}, $cmd );
            }            
        }                
    }

    return $self;
}



sub device_attr
{
    my $self = shift;
    my $attr = shift;

    return $self->{'job'}->device_attr($self->{'device'}, $attr);
}



sub exec_command
{
    my $self = shift;
    my $cmd = shift;

    my $exp = $self->{'expect'};
    my $sysname = $self->{'device'}->{'SYSNAME'};
    my $failure;

    $Gerty::log->debug('Running a command: "' . $cmd . '" on "' .
                       $sysname . '"');
    
    $exp->send($cmd . "\r");    
    my $result = $exp->expect
        ( $self->{'cli.timeout'},
          ['-re', $self->{'prompt'}],
          ['timeout', sub {$failure = 'Connection timeout'}],
          ['eof', sub {$failure = 'Connection closed'}]);
    
    if( not $result )
    {
        my $err = 'Could not match the output for ' .
            $sysname . ': ' . $exp->before();
        
        $Gerty::log->error($err);            
        return {'success' => 0, 'content' => $err};
    }
    
    if( defined($failure) )
    {
        my $err = 'Failed executing "' . $cmd . '" for ' .
            $sysname . ': ' . $failure;
        
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
                    $sysname . '": ' . $line;
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
    return [ keys %{$self->{'command_actions'}} ];
}



sub do_action
{
    my $self = shift;    
    my $action = shift;

    if( not defined($self->{'command_actions'}{$action}) )
    {
        my $err = 'Unsupported action: ' . $action .
            ' in Gerty::CLIHandler::Generic';
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
