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

# Command-line interface for Cisco-like devices


package Gerty::CLI::CiscoLike;
use base qw(Gerty::CLI::GenericAction);

use strict;
use warnings;
use Expect qw(exp_continue);


my %supported_actions =
    ('config-backup' => 'config_backup');

    
sub init
{
    my $self = shift;

    # Check if we have '#' or '>' prompt, and switch to enable mode if needed
    
    my $admin_already = $self->check_admin_mode();
    if( not defined($admin_already) )
    {
        return undef;
    }
        
    if( (not $admin_already) and $self->{'admin-mode'} )
    {
        my $epasswd = $self->device_credentials_attr('cli.auth-epassword');
        if( not defined( $epasswd ) )
        {
            $Gerty::log->error
                ('Missing attribute "cli.auth-epassword" for ' .
                 $self->sysname);
            return undef;
        }
        
        if( not $self->set_admin_mode( $epasswd ) )
        {
            $Gerty::log->error
                ('Failed to switch into enable mode for ' . $self->sysname);
            return undef;
        }
    }
    
    $self->SUPER::init();
    
    my @cmd;
    foreach my $item (split(/\s*,\s*/o,
                            $self->device_attr('cli.init-terminal')))
    {
        my $command = $self->device_attr($item . '.command');
        if( defined($command) )
        {
            push(@cmd, $command);                
        }
        else
        {
            $Gerty::log->error('"cli.init-terminal" lists ' . $item .
                               ', but the attribute ' .
                               $item . '.command is not defined for device ' .
                               $self->sysname);
            return undef;
        }
    }

    foreach my $command ( @cmd )
    {
        my $result = $self->exec_command($command);
        if( not $result->{'success'} )
        {
            return undef;
        }
    }

    return 1;
}


    
sub check_admin_mode
{
    my $self = shift;

    my $exp = $self->expect;
    my $admin_mode = 0;
    my $failure;
    
    $exp->send("\r");    
    $exp->expect
        ( $self->{'cli.timeout'},
          ['-re', $self->{'cli.admin-prompt'}, sub {$admin_mode = 1}],
          ['-re', $self->{'cli.user-prompt'}],          
          ['timeout', sub {$failure = 'Connection timeout'}],
          ['eof', sub {$failure = 'Connection closed'}]);

    if( defined($failure) )
    {
        $Gerty::log->error
            ('Failed to determine if we run in admin mode for ' .
             $self->sysname . ': ' . $failure);
        return undef;
    }

    return $admin_mode;
}



sub set_admin_mode
{
    my $self = shift;
    my $epasswd = shift;

    my $exp = $self->expect;
    my $enablecmd = $self->device_attr('cli.admin-mode.command');
    my $failure;

    $Gerty::log->debug('Setting admin mode for ' . $self->sysname);

    $exp->send($enablecmd . "\r");    
    my $result = $exp->expect
        ( $self->{'cli.timeout'},
          ['-re', qr/password:/i, sub {
              $exp->send($epasswd . "\r"); exp_continue;}],
          ['-re', $self->{'cli.admin-prompt'}],
          ['-re', $self->{'cli.user-prompt'}, sub {
              $failure = 'Access denied'}],          
          ['timeout', sub {$failure = 'Connection timeout'}],
          ['eof', sub {$failure = 'Connection closed'}]);
    
    if( not $result )
    {
        $Gerty::log->error
            ('Could not match the output for ' .
             $self->sysname . ': ' . $exp->before());            
        return undef;
    }
    
    if( defined($failure) )
    {
        $Gerty::log->error
            ('Failed switching to admin mode for ' .
             $self->sysname . ': ' . $failure);
        return undef;
    }

    return 1;
}




sub supported_actions
{
    my $self = shift;

    my $ret = [];
    push(@{$ret}, keys %supported_actions);
    push(@{$ret}, @{$self->SUPER::supported_actions()});

    return $ret;
}


sub do_action
{
    my $self = shift;    
    my $action = shift;

    if( defined($supported_actions{$action}) )
    {
        my $method = $supported_actions{$action};
        return $self->$method($action);
    }

    return $self->SUPER::do_action($action);
}



sub config_backup
{
    my $self = shift;    

    my $cmd = $self->device_attr('config-backup.command');
    if( not defined($cmd) )
    {
        my $err = 'Missing parameter config-backup.command for ' .
            $self->sysname;
        $Gerty::log->error($err);
        return {'success' => 0, 'content' => $err};
    }
    
    my $result = $self->exec_command( $cmd );
    if( $result->{'success'} )
    {
        my $excl = $self->device_attr('config-backup.exclude');
        if( defined($excl) )
        {
            foreach my $pattern_name (split(/\s*,\s*/o, $excl))
            {
                my $regexp = $self->device_attr($pattern_name . '.regexp');
                if( defined($regexp) )
                {
                    $result->{'content'} =~ s/$regexp//m;
                }
                else
                {
                    my $err = 'config-backup.exclude points to ' .
                        $pattern_name . ', but parameter ' . $pattern_name .
                        '.regexp is not defined for ' .
                        $self->sysname;                    
                    $Gerty::log->error($err);
                    return {'success' => 0, 'content' => $err};
                }
            }
        }
    }
    
    return $result;
}



        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
