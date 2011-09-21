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

# TCP socket transport for TL1


package Gerty::TL1::Transport::RawTCP;

use base qw(Gerty::TL1::MessageHandler);

use strict;
use warnings;
use IO::Socket::INET;

sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);
    
    # Fetch mandatory attributes
    
    foreach my $attr ('tl1.port', 'tl1.socket-timeout')
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

    return $self;
}


    

# Returns true in case of success

sub connect
{
    my $self = shift;
    
    my $ipaddr = $self->device->{'ADDRESS'};
    my $port = $self->{'attr'}{'tl1.port'};
    
    $Gerty::log->debug('Connecting to ' . $ipaddr .
                       ' with TL1 over raw TCP on port ' . $port);
    
    my $sock = IO::Socket::INET->new
        (PeerAddr => $ipaddr,
         PeerPort => $port,
         Proto    => 'tcp',
         Timeout => $self->{'attr'}{'tl1.socket-timeout'});

    if( not defined($sock) )
    {
        $Gerty::log->error
            ('Failed to connect to ' . $ipaddr .
             ' with TL1 over raw TCP on port ' . $port . ': ' . $!);
        return undef;
    }
    
    $self->_open_expect($sock);
    
    return 1;
}


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
