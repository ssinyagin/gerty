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

#  SNMP actions


package Gerty::SNMP::ActionHandler;

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

    foreach my $method ('session')
    {
        if( not $acc->has($method) )
        {
            $Gerty::log->critical
                ('The access handler for device "' .
                 $self->sysname .
                 '" does not provide "' . $method . '" method');
            return undef;
        }
    }

    $self->init_mixins('+snmp.handler-mixins');
        
    return $self;
}


sub session
{
    my $self = shift;
    return $self->device->{'ACCESS_HANDLER'}->session();
}


# Helper utilities common to most SNMP devices

my %ifMibOID =
    ('ifIndex' => '1.3.6.1.2.1.2.2.1.1',
     'ifDescr' => '1.3.6.1.2.1.2.2.1.2',
     'ifName'  => '1.3.6.1.2.1.31.1.1.1.1',
     'ifAlias' => '1.3.6.1.2.1.31.1.1.1.18',
    );
     

my %default_interface_params =
    ('name' => 'ifName',
     'description' => 'ifDescr');

# retrieve interface and description
sub get_interface_info
{
    my $self = shift;
    my $ifIndex = shift;
    my $hints = shift;

    my %request_attrs;
    
    foreach my $attr ('name', 'description')
    {
        my $oid_name;
        if( defined($hints->{$attr}) )
        {
            $oid_name = $hints->{$attr};
        }
        else
        {
            $oid_name = default_interface_params{$attr};
        }

        $request_attrs{$ifMibOID{$oid_name} . '.' . $ifIndex} = $attr;
    }

    my $result = $self->session->get_request
        ('-varbindlist' => [keys %request_attrs]);

    if( not $result )
    {
        return undef;
    }

    my $ret = {};
    
    foreach my $oid (keys %{$result})
    {
        $ret->{ $request_attrs{$oid} } = $result->{$oid};
    }

    return $ret;
}
    


        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
