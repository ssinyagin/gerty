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

# Device list driver: imports devices from a file


package Gerty::DeviceList::File;

use strict;
use warnings;
use IO::File;

# File types can be extended by plugins
# The hash array defines processing methods and mandatory attributes
our %filetypes =
    ('plain' => {
         'process' => \&process_plain,
         'attrs' => {
             'source.delimiter' => 1,
         },
     },
     );


     
sub new
{
    my $self = {};
    my $class = shift;    
    $self->{'listname'} = shift;
    $self->{'options'} = shift;
    bless $self, $class;

    # check mandatory attributes
    foreach my $attr ('source.filename', 'source.filetype')
    {
        if( not defined($self->{'options'}{$attr}) )
        {
            $Gerty::log->critical
                ('Missing mandatory attribute "' . $attr .
                 '" in device list "' . $self->{'listname'} . '"');
            return undef;
        }        
    }

    my $ftype = $self->{'options'}{'source.filetype'};
    if( not defined( $filetypes{$ftype} ) )
    {
        $Gerty::log->critical
            ('File type ' . $ftype . ' is unknown to ' .
             'Gerty::DeviceList::File');
        return undef;
    }

    if( not -r $self->{'options'}{'source.filename'} )
    {
        $Gerty::log->critical
            ('File ' . $self->{'options'}{'source.filename'} .
             ' does not exist or is unreadable');
        return undef;
    }

    if( defined($filetypes{$ftype}{'attrs'}) )
    {
        while( my($attr, $mandatory) = each %{$filetypes{$ftype}{'attrs'}} )
        {
            if( $mandatory and not defined($self->{'options'}{$attr}) )
            {
                $Gerty::log->critical
                    ('Missing mandatory attribute "' . $attr .
                     '" in device list "' . $self->{'listname'} . '"');
                return undef;
            }
        }
    }
       
    return $self;
}


sub retrieve_devices
{
    my $self = shift;

    $Gerty::log->debug('Gerty::DeviceList::File - processing ' .
                       $self->{'options'}{'source.filename'});
    
    my $ftype = $self->{'options'}{'source.filetype'};
    my $ret = &{$filetypes{$ftype}{'process'}}($self);
    
    $Gerty::log->debug('Gerty::DeviceList::File - retrieved  ' .
                       scalar(@{$ret}) . ' devices');
    return $ret;
}
    


sub process_plain
{
    my $self = shift;

    my $filename = $self->{'options'}{'source.filename'};
    my $fh = new IO::File($filename, 'r');
    if( not $fh )
    {
        $Gerty::log->critical('Cannot open file ' . $filename . ': ' . $!);
        return undef;
    }

    my $ret = [];
    
    my $delimiter = $self->{'options'}{'source.delimiter'};
    my $comment = $self->{'options'}{'source.comment'};
    $comment = '^\#' unless defined $comment;

    my $lineno = 0;
    while(<$fh>)
    {
        $lineno++;
        s/^\s+//m;
        s/\s+$//m;
        next if /^\s*$/;
        next if ($_ =~ $comment);
        
        my @values = split($delimiter, $_);
        next if not scalar(@values);

        push(@{$ret}, {'values' => [ @values ],
                       'source' => $filename . ' line ' . $lineno});
    }

    return $ret;
}
    



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
