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

# A list of Gerty devices


package Gerty::DeviceList;

use strict;
use warnings;


sub new
{
    my $self = {};
    my $class = shift;    
    $self->{'listname'} = shift;
    $self->{'options'} = shift;
    bless $self, $class;

    # check mandatory attributes
    foreach my $attr ('source.type', 'source.fields', 'devclass')
    {
        if( not defined($self->{'options'}{$attr}) )
        {
            $Gerty::log->critical
                ('Missing mandatory attribute "' . $attr .
                 '" in device list "' . $self->{'listname'} . '"');
            return undef;
        }
    }

    my $driver = $self->{'options'}{'source.type'};
    eval(sprintf('require %s', $driver));
    if( $@ )
    {
        $Gerty::log->critical
            ('Cannot load device list driver ' . $driver . ': ' . $@);
        return undef;
    }

    $self->{'driver'} = eval('new ' . $driver .
                             '($self->{\'listname\'}, $self->{\'options\'})');
    if( $@ )
    {
        $Gerty::log->critical($@);
        return undef;
    }
    
    if( not defined($self->{'driver'}) )
    {
        $Gerty::log->critical
            ('Failed to initialize device list driver ' . $driver);
        return undef;
    }
        
    return $self;
}


sub attr
{
    my $self = shift;
    my $attr = shift;

    return $self->{'options'}{$attr};
}


sub retrieve_devices
{
    my $self = shift;
    
    # Retrieve raw tabular data and process it according to 'source.fields'
    my $data = $self->{'driver'}->retrieve_devices();
    if( not defined($data) )
    {
        $Gerty::log->critical('Failed to retrieve the devices from the list ' .
                              $self->{'listname'});
        return [];
    }
    
    my @fields = split(/\s*,\s*/o, $self->{'options'}{'source.fields'});
                       
    my $ret = [];
    foreach my $row ( @{$data} )
    {
        my $dev_attr = {};
        my @row_values = @{$row->{'values'}};
        
        foreach my $field ( @fields )
        {
            my $val = shift( @row_values );
            if( defined($val) and $val ne '' )
            {
                $dev_attr->{$field} = $val;
            }
        }
        
        # Inherit device class from the list attribute
        if( not defined($dev_attr->{'DEVCLASS'}) )
        {
            $dev_attr->{'DEVCLASS'} = $self->{'options'}{'devclass'};
        }

        $dev_attr->{'SOURCE'} = $row->{'source'};
        $dev_attr->{'DEVLIST'} = $self->{'listname'};
        
        push(@{$ret}, $dev_attr);
    }
    
    return $ret;
}


    

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
