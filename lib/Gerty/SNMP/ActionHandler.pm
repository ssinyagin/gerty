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




    

        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
