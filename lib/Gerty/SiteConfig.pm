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

# Gerty site config

package Gerty::SiteConfig;

use strict;
use warnings;
use Gerty::ConfigFile;


sub new
{
    my $self = {};
    my $class = shift;
    $self->{'options'} = shift;
    bless $self, $class;


    my $path = $self->{'options'}{'path'};
    my $filename = $path . '/siteconfig.ini';
    if( not -r $filename )
    {
        $Gerty::log->critical('Missing site configuration file: ' . $filename);
        return undef;
    }
    
    $self->{'cfg'} = Gerty::ConfigFile->load( $filename );
    return undef unless $self->{'cfg'};

    if( not defined($self->{'cfg'}{'devices'}) )
    {
        $Gerty::log->critical
            ('Site config must contain at least one [devices] section: ' .
             $filename);
        return undef;
    }
    
    my $devclasses_path = $path . '/devclases';
    if( -d $devclasses_path )
    {
        $Gerty::log->debug('Adding ' . $devclasses_path .
                           ' to devclass search paths');
        $Gerty::devclass_paths{$devclasses_path} = 300;
    }

    
    return $self;
}


sub devlist
{
    my $self = shift;
    my $listname = shift;

    return $self->{'cfg'}{'devices'}{$listname};
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
