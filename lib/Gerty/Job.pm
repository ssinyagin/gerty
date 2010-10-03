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

package Gerty::Job;

use strict;
use warnings;
use Gerty::ConfigFile;
use Gerty::SiteConfig;


sub new
{
    my $self = {};
    my $class = shift;
    $self->{'options'} = shift;
    bless $self, $class;


    my $filename = $self->{'options'}{'file'};

    my $cfg = Gerty::ConfigFile->load( $filename );
    return undef unless $cfg;
    
    if( not ref($cfg->{'job'}) )
    {
        $Gerty::log->critical
            ('Missing mandatory section [job] in ' .
             ' in job definition file ' . $filename);
        return undef;
    }
            
    $self->{'cfg'} = $cfg->{'job'};    
        
    # override attributes from CLI arguments
    if( defined($self->{'options'}{'attrs'}) )
    {
        foreach my $attr (keys %{$self->{'options'}{'attrs'}})
        {
            $self->{'cfg'}{$attr} = $self->{'options'}{'attrs'}{$attr};
        }
    }
    
    # check mandatory attributes
    foreach my $attr ('title', 'siteconfig', 'devlists')
    {
        if( not defined($self->{'cfg'}{$attr}) )
        {
            $Gerty::log->critical('Missing mandatory attribute ' . $attr .
                                  ' in job definition file ' . $filename);
            return undef;
        }
    }

    # set defaults for optional attributes    
    if( not defined($self->{'cfg'}{'description'}) )
    {
        $self->{'cfg'}{'description'} = '';
    }    
    if( not defined($self->{'cfg'}{'parallel'}) or
        $self->{'cfg'}{'parallel'} < 1 )
    {
        $self->{'cfg'}{'parallel'} = 1;
    }

    # load the site config
    $self->{'siteconfig'} =
        new Gerty::SiteConfig({'path' => $self->{'cfg'}{'siteconfig'}});
    return undef unless $self->{'siteconfig'};

    # initialize devlists
    foreach my $devlist ( split(/\s*,\s*/o, $self->{'cfg'}{'devlists'}) )
    {
        my $list = $self->{'siteconfig'}->devlist($devlist);
        if( not $list )
        {
            $Gerty::log->critical('Cannot find device list named "' .
                                  $devlist . '" in siteconfig');
            return undef;
        }

        $self->{'devlists'}{$devlist} = $list;        
    }
    
    return $self;
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
