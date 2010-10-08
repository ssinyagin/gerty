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
use Gerty::DeviceList;

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
    
    my $devclasses_path = $path . '/devclasses';
    if( -d $devclasses_path )
    {
        $Gerty::log->debug('Adding ' . $devclasses_path .
                           ' to devclass search paths');
        $Gerty::devclass_paths{$devclasses_path} = 300;
    }

    my $perlpath = $path . '/lib';
    if( -d $perlpath )
    {
        $Gerty::log->debug('Adding ' . $perlpath . ' to @INC');
        unshift( @INC, $perlpath );
    }
    
    # Expand ${variable-expansions}
    if( defined($self->{'cfg'}{'siteconfig'}) )
    {
        while( my($attr, $value) = each %{$self->{'cfg'}{'siteconfig'}} )
        {
            my $changed = 0;
            while( $value =~ /\$\{([^\}]+)\}/o )
            {
                my $lookup = $1;
                my $subst = $self->{'cfg'}{'siteconfig'}{$lookup};
                if( defined($subst) )
                {
                    $value =~ s/\$\{$lookup\}/$subst/g;
                    $changed = 1;
                }
                else
                {
                    $Gerty::log->critical
                        ('Cannot expand variable ${' . $lookup . '} in ' .
                         '[siteconfig] section in ' . $filename);
                    return undef;
                }                    
            }

            if( $changed )
            {
                $self->{'cfg'}{'siteconfig'}{$attr} = $value;
            }
        }
    }


    foreach my $listname (keys %{$self->{'cfg'}{'devices'}})
    {
        while( my($attr, $value) =
               each %{$self->{'cfg'}{'devices'}{$listname}} )
        {
            my $changed = 0;
            while( $value =~ /\$\{([^\}]+)\}/o )
            {
                my $lookup = $1;
                my $subst = $self->{'cfg'}{'devices'}{$listname}{$lookup};
                if( not defined($subst) )
                {
                    $subst = $self->{'cfg'}{'siteconfig'}{$lookup};
                }

                if( defined($subst) )
                {
                    $value =~ s/\$\{$lookup\}/$subst/g;
                    $changed = 1;
                }
                else
                {
                    $Gerty::log->critical
                        ('Cannot expand variable ${' . $lookup . '} in ' .
                         'device list "' . $listname . '" in ' . $filename);
                    return undef;
                }                    
            }

            if( $changed )
            {
                $self->{'cfg'}{'devices'}{$listname}{$attr} = $value;
            }
        }
        
    }
    return $self;
}





sub attr
{
    my $self = shift;
    my $attr = shift;

    if( defined( $self->{'cfg'}{'siteconfig'} ) )
    {
        return $self->{'cfg'}{'siteconfig'}{$attr};
    }
    else
    {
        return undef;
    }
}



sub devlist
{
    my $self = shift;
    my $listname = shift;

    if( not defined($self->{'cfg'}{'devices'}{$listname}) )
    {
        $Gerty::log->critical
            ('Cannot find device list definition: ' . $listname);
        return undef;
    }

    
    return Gerty::DeviceList->new($listname,
                                  $self->{'cfg'}{'devices'}{$listname});
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
