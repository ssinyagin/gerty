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

# Gerty job initiation and execution

package Gerty::ConfigFile;

use strict;
use warnings;
use Config::Any;

sub load
{
    my $class = shift;
    my $filename = shift;

    $Config::Any::INI::MAP_SECTION_SPACE_TO_NESTED_KEY = 1;
    
    my $result = 
        Config::Any->load_files
        ( { 'files' => [$filename],
            'force_plugins' => ['Config::Any::INI'],
            'flatten_to_hash' => 1 } );
    
    if( $@ )
    {
        $Gerty::log->critical
            ('Gerty::ConfigFile::new: Error loading ' . $filename . ': ' .
             $@);
        return undef;
    }

    $Gerty::log->debug('Loaded INI file: ' . $filename);  
    return $result->{$filename};
}





1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
