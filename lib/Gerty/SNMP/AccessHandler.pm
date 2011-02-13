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


package Gerty::SNMP::AccessHandler;

use base qw(Gerty::HandlerBase);

use strict;
use warnings;

use Net::SNMP;

my %has =
    ('session' => 1);

my %valid_snmp_version =
    ('snmpv1' =>1,
     'snmpv2c' => 1,
     'snmpv3' => 1);

sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    # See Net::SNMP for attribute documentation
    
    # Fetch mandatory attributes
    
    foreach my $attr
        ('snmp.version', 'snmp.timeout', 'snmp.retries')
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

    if( not $valid_snmp_version{$self->{'attr'}{'snmp.version'}} )
    {
        $Gerty::log->error
            ('Invalid SNMP version "' .
             $self->{'attr'}{'snmp.version'} .
             '" for device: ' . $self->sysname);
        return undef;
    }
        
    my @mandatory_cred_attrs;
    my @optional_cred_attrs;
    my @mandatory_attrs;
    my @optional_attrs =
        ('snmp.port', 'snmp.domain', 'snmp.localaddr',
         'snmp.localport', 'snmp.maxmsgsize' );
    
    if( $self->{'attr'}{'snmp.version'} eq 'snmpv3')
    {
        push(@mandatory_cred_attrs, 'snmp.username');
        push(@optional_cred_attrs,
             'snmp.authkey',
             'snmp.authpassword',
             'snmp.privkey',
             'snmp.privpassword');
        push(@optional_attrs, 
             'snmp.authprotocol',
             'snmp.privprotocol');
    }
    else
    {
        push(@mandatory_cred_attrs, 'snmp.community');
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
    
    # Fetch mandatory attributes, if any
    
    foreach my $attr (@mandatory_attrs)
    {
        my $val = $self->device_attr($attr);
        if( not defined($val) )           
        {
            $Gerty::log->error
                ('Missing mandatory attribute "' .
                 $attr . '" for device: ' . $self->sysname);
            return undef;
        }
        else
        {
            $self->{'attr'}{$attr} = $val;
        }
    }

    # Fetch optional credentials
    
    foreach my $attr (@optional_cred_attrs)
    {
        my $val = $self->device_credentials_attr($attr);
        if( defined($val) )
        {
            $self->{'attr'}{$attr} = $val;
        }       
    }

    # Fetch optional attributes

    foreach my $attr (@optional_attrs)
    {
        my $val = $self->device_attr($attr);
        if( defined($val) )
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

    my $ipaddr = $self->device->{'ADDRESS'};
    
    $Gerty::log->debug('Opening SNMP session to ' . $ipaddr);

    my %args = ('-hostname' => $ipaddr,
                '-nonblocking' => 0,
                '-translate' => ['-all', 0]);
    
    foreach my $arg
        ('port', 'localaddr', 'localport', 'version', 'domain', 'timeout',
         'retries', 'maxmsgsize', 'community', 'username', 'authkey',
         'authpassword', 'authprotocol', 'privkey', 'privpassword',
         'privprotocol')
    {
        my $val = $self->{'attr'}{'snmp.' . $arg};
        if( defined($val) )
        {
            $args{'-' . $arg} = $val;
        }
    }

    my ($session, $error) = Net::SNMP->session( %args );
    if( not defined($session) )
    {
        $Gerty::log->error
            ('Cannot create SNMP session for ' . $self->sysname .
             ': ' . $error);
        return undef;
    }
    
    $self->{'session'} = $session;
    return 1;
}


sub close
{
    my $self = shift;
    
    $self->{'session'}->close();
    $self->{'session'} = undef;
}
    



sub has
{
    my $self = shift;
    my $what = shift;
    return $has{$what};
}


sub session {shift->{'session'}};


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
