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

#  TL1 actions


package Gerty::TL1::ActionHandler;

use base qw(Gerty::MixinLoader);

use strict;
use warnings;


sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    my $acc = $self->device->{'ACCESS_HANDLER'};

    foreach my $method ('tl1_command')
    {
        if( not $acc->can($method) )
        {
            $Gerty::log->critical
                ('The access handler for device "' .
                 $self->sysname .
                 '" does not provide "' . $method . '" method');
            return undef;
        }
    }

    # retrieve command actions and their attributes
    $self->{'command_actions'} = {};
    my $actions_list = $self->device_attr('+tl1.command-actions');
    if( defined($actions_list) )
    {
        foreach my $action (split(/,/o, $actions_list))
        {
            $self->{'command_actions'}{$action} = [];
            
            my $multicmd = $self->device_attr($action . '.multicommand');
            
            my @suffixes;
            if( $multicmd and $multicmd > 0 )
            {
                foreach my $i (1 .. $multicmd)
                {
                    push( @suffixes, '-' . $i );
                }
            }
            else
            {
                push( @suffixes, '' );
            }

            foreach my $suffix (@suffixes)
            {
                my $attr = $action . '.command' . $suffix;
                
                my $cmd = $self->device_attr($attr);
                if( not defined($cmd) )
                {
                    $Gerty::log->error
                        ('+tl1.command-actions defines the action "' .
                         $action . '", but attribute "' . $attr .
                         '" is not defined for device: ' .
                         $self->sysname);
                    next;
                }

                my $tl1_command = {'cmd' => $cmd};
                foreach my $arg ('tid', 'aid', 'ctag', 'params')
                {
                    my $val =
                        $self->device_attr($action . '.' . $arg . $suffix);
                    if( defined($val) )
                    {
                        $tl1_command->{$arg} = $val;
                    }
                }

                push(@{$self->{'command_actions'}{$action}}, $tl1_command);
            }
        }
    }

    $self->init_mixins('+tl1.handler-mixins');
        
    return $self;
}


sub init
{
    my $self = shift;
    
    my $acc = $self->device->{'ACCESS_HANDLER'};

    if( $acc->login() )
    {
        $Gerty::log->debug($self->sysname . ': Logged in for TL1 session');
    }
    else
    {
        $Gerty::log->error
            ($self->sysname . ': Failed to log in for TL1 session');
        return undef;
    }

    return 1;
}


sub supported_actions
{
    my $self = shift;

    my $ret = [];
    push(@{$ret}, keys %{$self->{'command_actions'}});
    push(@{$ret}, @{$self->SUPER::supported_actions()});

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
            ' in Gerty::TL1::ActionHandler';
        $Gerty::log->error($err);
        return {'success' => 0, 'content' => $err};
    }
    
    my $acc = $self->device->{'ACCESS_HANDLER'};
    my $content = '';
    
    foreach my $cmd_args (@{$self->{'command_actions'}{$action}})
    {
        my $result = $acc->tl1_command($cmd_args);
        if( $result->{'success'} )
        {
            $content .= join("\n", @{$result->{'response'}}) . "\n";
        }
        else
        {
            return {'success' => 0, 'content' => $result->{'error'}};
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
