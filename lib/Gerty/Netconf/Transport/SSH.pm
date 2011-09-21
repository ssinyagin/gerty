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

# SSH transport for Netconf
# We don't use Gerty::CLI::DirectAccess because of too many differences,
# and mainly because there's no command-line prompt in Netconf


package Gerty::Netconf::Transport::SSH;

use base qw(Gerty::Netconf::Transport::Expect);

use strict;
use warnings;
use Expect qw(exp_continue);
use Date::Format;


sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);
    
    # Fetch mandatory attributes
    
    foreach my $attr
        ('netconf.ssh-port', 'netconf.ssh-subsystem',
         'netconf.ssh-use-password')
    {
        my $val = $self->device_attr($attr);
        if( not defined($val) )           
        {
            $Gerty::log->error
                ('Missing mandatory attribute "' .
                 $attr . '" for device: ' . $self->sysname);
            return undef;
        }
        $self->{'attr'}{$attr} = $val;        
    }

    my @mandatory_cred_attrs = ('netconf.auth-username');
    if( $self->{'attr'}{'netconf.ssh-use-password'} )
    {     
        push(@mandatory_cred_attrs, 'netconf.auth-password');
    }
    
    # Fetch mandatory credentials
    
    foreach my $attr (@mandatory_cred_attrs)
    {
        my $val = $self->device_credentials_attr($attr);
        if( not defined($val) )
        {
            $Gerty::log->error
                ('Missing mandatory credentials attribute "' .
                 $attr . '" for device: ' .
                 $self->sysname);
            return undef;
        }
        else
        {
            $self->{'attr'}{$attr} = $val;
        }       
    }

    return $self;
}


    

# Returns true in case of success

sub connect
{
    my $self = shift;

    my $exp = $self->_open_expect();
    
    my $ipaddr = $self->device->{'ADDRESS'};
    
    $Gerty::log->debug('Connecting to ' . $ipaddr . ' with Netconf over SSH');

    my @exec_args =
        ($Gerty::external_executables{'ssh'},
         '-p', $self->{'attr'}{'netconf.ssh-port'},
         '-l', $self->{'attr'}{'netconf.auth-username'});

    if( $self->{'attr'}{'netconf.ssh-use-password'} )
    {
        push(@exec_args,
             '-o', 'NumberOfPasswordPrompts=1',
             '-o', 'PasswordAuthentication=yes',
             '-o', 'PreferredAuthentications=keyboard-interactive,password');
    }
    else
    {
        push(@exec_args,
             '-o', 'PasswordAuthentication=no');
    }

    push(@exec_args, '-s', $ipaddr, $self->{'attr'}{'netconf.ssh-subsystem'});

    if( not $exp->spawn(@exec_args) )
    {
        $Gerty::log->error('Failed spawning command "' .
                           join(' ', @exec_args) . '": ' . $!);
        return undef;
    }


    # Handle unknown host and password
    my $password = $self->{'attr'}{'netconf.auth-password'};
    my $failure;
    
    if( not defined
        $exp->expect
        ( $self->timeout,
          ['-re', qr/yes\/no.*/i, sub {
              $exp->send("yes\r"); exp_continue;}],
          ['-re', qr/password:/i, sub {
              $exp->send($password . "\r"); exp_continue;}],
          [']]>]]>'],
          ['timeout', sub {$failure = 'Connection timeout'}],
          ['-re', qr/connection .*closed/i,
           sub {$failure = 'Connection closed'}],
          ['eof', sub {$failure = 'Connection closed'}],
          ) )
    {
        $Gerty::log->error
            ('Could not match the output for ' . $self->sysname . ': ' . 
             $exp->before());
        $exp->hard_close();
        return undef;
    }
        
    if( defined($failure))
    {
        $Gerty::log->error
            ('Failed logging into ' . $self->sysname . ': ' . $failure);
        $exp->hard_close();
        return undef;
    }

    # we matched the first message from the server, which is usually <hello>
    # It may contain some garbage from SSH MOTD in the beginning.
    my $hellomsg = $exp->before();
    $hellomsg =~ s/[^\<]+//mo;
    $self->add_outstanding_message($hellomsg);
    
    $Gerty::log->debug('Logged in at ' . $ipaddr);
    return 1;
}


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
