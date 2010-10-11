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

# Gerty device class

package Gerty::DeviceClass;

use strict;
use warnings;
use Gerty::ConfigFile;

# Cache the devclass objects
my %cache;

sub new
{
    my $self = {};
    my $class = shift;    
    $self->{'options'} = shift;
    bless $self, $class;


    my $classname = $self->{'options'}{'class'};
    if( defined($cache{$classname}) )
    {
        return $cache{$classname};
    }
        
    my $filename;
    my $found;
    
    my @search_paths =
        sort {$Gerty::devclass_paths{$a} <=> $Gerty::devclass_paths{$b}}
    keys %Gerty::devclass_paths;
        
    foreach my $path (@search_paths)
    {
        $filename = $path . '/' . $classname . '.ini';
        if( -r $filename )
        {
            $found = 1;
            last;
        }
    }

    if( not $found )    
    {
        $Gerty::log->critical
            ('Cannot find INI file for device class "' . $classname .
             '". Searched in: ' . join(', ', @search_paths));
        return undef;
    }
    
    my $cfg = Gerty::ConfigFile->load( $filename );
    return undef unless $cfg;
    
    $self->{'cfg'} = $cfg->{'devclass'}{$classname};
    if( not defined($self->{'cfg'}) )
    {
        $Gerty::log->critical
            ('Cannot find section [devclass ' . $classname . '] in ' .
             $filename);
        return undef;
    }

    $self->{'parents'} = [];
    
    if( defined($self->{'cfg'}{'inherit'}) )
    {
        foreach my $parentname (split(/\s*,\s*/o, $self->{'cfg'}{'inherit'}))
        {
            my $parent = new Gerty::DeviceClass({'class' => $parentname});
            if( not $parent )
            {
                $Gerty::log->critical
                    ($classname . ': cannot find parent class ' . $parentname);
                return undef;
            }

            push(@{$self->{'parents'}}, $parent);
        }        
    }

    $cache{$classname} = $self;
    return $self;
}


sub classname
{
    my $self = shift;
    return $self->{'options'}{'class'};
}


sub attr
{
    my $self = shift;
    my $attr = shift;

    my $ret = $self->{'cfg'}{$attr};
    if( defined($ret) )
    {
        $Gerty::log->debug('Found "' . $attr . '" in devclass "' .
                           $self->classname() . '"');
        return $ret;
    }
    else
    {
        $Gerty::log->debug('Did not find "' . $attr . '" in devclass "' .
                           $self->classname() .
                           '". Looking up at parent classes');
    }
    
    foreach my $parent (reverse @{$self->{'parents'}})
    {
        $ret = $parent->attr( $attr );
        if( defined($ret) )
        {
            return $ret;
        }
        else
        {
            $Gerty::log->debug('Did not find "' . $attr . '" in devclass "' .
                               $parent->classname() .
                               '". Looking up further at parent classes');
        }
    }
    
    return undef;    
}





1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
