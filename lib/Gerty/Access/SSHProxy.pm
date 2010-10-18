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

# SSH jump-host access


package Gerty::Access::SSHProxy;

use base qw(Gerty::Access::CLI);

use strict;
use warnings;
use Expect qw(exp_continue);


     
sub new
{
    my $class = shift;    
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);
    
    my $sysname = $self->{'options'}->{'device'}->{'SYSNAME'};

    # Fetch mandatory attributes

    foreach my $attr
        ('sshproxy.hostname', 'sshproxy.port', 'sshproxy.login-timeout',
         'sshproxy.ssh-command', 'sshproxy.telnet-command')
    {
        my $val = $self->device_attr($attr);
        if( not defined($val) )
        {
            $Gerty::log->error
                ('Missing mandatory attribute "' . $attr . '" for device: ' .
                 $sysname);
            return undef;
        }
        else
        {
            $self->{'attr'}{$attr} = $val;
        }       
    }
        
    # Fetch mandatory credentials
    
    foreach my $attr ('sshproxy.username', 'sshproxy.password')
    {
        my $val = $self->device_credentials_attr($attr);
        if( not defined($val) )
        {
            $Gerty::log->error
                ('Missing mandatory credentials attribute "' .
                 $attr . '" for device: ' .
                 $sysname);
            return undef;
        }
        else
        {
            $self->{'attr'}{$attr} = $val;
        }       
    }

    return $self;
}





# Returns an Expect object after authentication
sub connect
{
    my $self = shift;

    my $exp = $self->_open_expect();
    
    my $sysname = $self->{'options'}->{'device'}->{'SYSNAME'};
    my $proxyhost = $self->{'attr'}{'sshproxy.hostname'};
    
    $Gerty::log->debug('Connecting to SSH proxy: ' . $proxyhost);

    my @exec_args =
        ($Gerty::external_executables{'ssh'},
         '-o', 'NumberOfPasswordPrompts=1',
         '-p', $self->{'attr'}{'sshproxy.port'},
         '-l', $self->{'attr'}{'sshproxy.username'},
         $proxyhost);
    
    if( not $exp->spawn(@exec_args) )
    {
        $Gerty::log->error('Failed spawning command "' .
                           join(' ', @exec_args) . '": ' . $!);
        return undef;
    }

    my $password = $self->{'attr'}{'sshproxy.password'};
    my $timeout =  $self->{'attr'}{'sshproxy.login-timeout'};
    my $prompt = $self->{'attr'}{'sshproxy.prompt'};    
    my $failure;

    # SSH jumphost may print some garbage like MOTD, so we
    # accept anything within sshproxy.login-timeout
    $exp->expect
        ( $timeout,
          ['-re', qr/yes\/no.*/i, sub {
              $exp->send("yes\r"); exp_continue;}],
          ['-re', qr/password:/i, sub {
              $exp->send($password . "\r"); exp_continue;}],          
          ['-re', qr/closed/i, sub {$failure = 'Connection closed'}],
          ['-re', qr/.+/, sub {exp_continue}],         
          ['eof', sub {$failure = 'Connection closed'}],
          );
    
    if( defined($failure))
    {
        $Gerty::log->error
            ('Failed logging into ' . $proxyhost . ': ' . $failure);
        $exp->hard_close();
        return undef;
    }    
    
    my $method = $self->{'attr'}{'cli.access-method'};            
    my $ipaddr = $self->{'options'}->{'device'}{'ADDRESS'};
    
    $Gerty::log->debug('Connecting through SSH proxy to ' .
                       $ipaddr . ' with ' . $method);
    
    if( $method eq 'ssh' )
    {
        $exp->send($self->{'attr'}{'sshproxy.ssh-command'} . ' ' .
                   '-o NumberOfPasswordPrompts=1 ' .
                   '-p ' . $self->{'attr'}{'cli.ssh-port'} . ' ' .
                   '-l ' . $self->{'attr'}{'cli.auth-username'} . ' ' .
                   $ipaddr .
                   "\r");
        
        if( not $self->_login_ssh($exp) )
        {
            return undef;
        }        
    }
    elsif( $method eq 'telnet' )
    {
        $exp->send($self->{'attr'}{'sshproxy.telnet-command'} . ' ' .
                   $ipaddr . ' ' .
                   $self->{'attr'}{'cli.telnet-port'} .
                   "\r");
        
        if( not $self->_login_telnet($exp) )
        {
            return undef;
        }        
    }
    
    $Gerty::log->debug('Logged in at ' . $ipaddr);
    $self->{'expect'} = $exp;
    return $exp;
}



             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
