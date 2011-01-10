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

# Abstract handler parent class


package Gerty::HandlerBase;

use strict;
use warnings;


     
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
    
    return $self;
}


sub job
{
    my $self = shift;
    return $self->{'job'};
}


sub device
{
    my $self = shift;
    return $self->{'device'};
}


sub sysname
{
    my $self = shift;
    return $self->{'device'}->{'SYSNAME'};
}


sub device_attr
{
    my $self = shift;
    my $attr = shift;

    return $self->{'job'}->device_attr($self->{'device'}, $attr);
}


sub device_credentials_attr
{
    my $self = shift;
    my $attr = shift;

    return $self->{'job'}->device_credentials_attr
        ( $self->{'device'}, $attr );
}



    


        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
