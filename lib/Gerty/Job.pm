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
use Net::hostent;
use Socket;
use IO::File;

use Gerty::ConfigFile;
use Gerty::SiteConfig;
use Gerty::DeviceClass;


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
    foreach my $listname ( split(/\s*,\s*/o, $self->{'cfg'}{'devlists'}) )
    {
        my $list = $self->{'siteconfig'}->devlist($listname);
        if( not $list )
        {
            $Gerty::log->critical('Failed to initialize device list named "' .
                                  $listname . '" in siteconfig');
            return undef;
        }

        $self->{'devlists'}{$listname} = $list;        
    }
    
    return $self;
}



sub load_and_execute
{
    my $self = shift;
    my $dev = shift;
    my $handler_attr = shift;
    my $method = shift;
    my @args = @_;

    my $module = $self->device_attr($dev, $handler_attr);
    if( not defined($module) )
    {
        $Gerty::log->critical
            ('Missing mandatory attribute "' . $handler_attr .
             '" for device "' . $dev->{'SYSNAME'} . '"');
        return undef;
    }
    
    eval(sprintf('require %s', $module));
    if( $@ )
    {
        $Gerty::log->critical
            ('Error loading Perl module ' . $module .
             ' specified in "' . $handler_attr . '" for device "' .
             $dev->{'SYSNAME'} . '": ' . $@);
        return undef;            
    }
    
    my $ret = eval(sprintf('%s->%s(@args)', $module, $method));
    if( $@ )
    {
        $Gerty::log->critical
            ('Error executing ' . $module . '->' . $method . ': ' . $@);
        return undef;
    }
    
    return $ret;
}



sub attr
{
    my $self = shift;
    my $attr = shift;
    
    return $self->{'cfg'}{$attr};
}


# retrieve device parameters according to the hierarchy
sub retrieve_device_attr
{
    my $self = shift;
    my $dev = shift;
    my $attr = shift;

    $Gerty::log->debug('Retrieving attribute "' . $attr .
                       '" for device "' . $dev->{'SYSNAME'});

    # First look up at the job level
    my $ret = $self->attr($attr);
    if( defined($ret) )
    {
        $Gerty::log->debug('Retrieved "' . $attr .
                           '"="' . $ret . '" from job level');
        return $ret;
    }

    # Look up in [siteconfig]
    $ret = $self->{'siteconfig'}->attr($attr);
    if( defined($ret) )
    {
        $Gerty::log->debug('Retrieved "' . $attr .
                           '"="' . $ret . '" from siteconfig level');
        return $ret;
    }

    # Look up in device list
    my $listname = $dev->{'DEVLIST'};
    $ret = $self->{'devlists'}{$listname}->attr($attr);
    if( defined($ret) )
    {
        $Gerty::log->debug('Retrieved "' . $attr .
                           '"="' . $ret . '" from devicelist level');
        return $ret;
    }
    
    # Look up in the class hierarchy
    $ret = $self->{'devclasses'}{$dev->{'DEVCLASS'}}->attr($attr);
    if( defined($ret) )
    {
        $Gerty::log->debug('Retrieved "' . $attr .
                           '"="' . $ret . '" from devclass level');
    }
    else
    {
        $Gerty::log->debug('"' . $attr . '" is undefined');
    }
    return $ret;
}


# retrieve the attribute and do variable substitution
sub device_attr
{
    my $self = shift;
    my $dev = shift;
    my $attr = shift;

    my $value = $self->retrieve_device_attr($dev, $attr);
    if( not defined($value) )
    {
        $value = $self->retrieve_device_attr($dev, $attr . '-default');
    }
    return undef unless defined($value);

    while( $value =~ /\$\{([^\}]+)\}/o )
    {
        my $lookup = $1;

        # stupidity check: infinite loop prevention
        if( $lookup eq $attr )
        {
            $Gerty::log->error
                ('Infinite loop in variable expansion ${' . $lookup .
                 '} for device: ' . $dev->{'SYSNAME'});
            return undef;
        }
        
        my $subst = $self->device_attr($dev, $lookup);
        if( not defined($subst) )
        {
            $Gerty::log->error
                ('Cannot expand variable ${' . $lookup .
                 '} for device: ' . $dev->{'SYSNAME'});
            return undef;
        }
        
        $value =~ s/\$\{$lookup\}/$subst/g;
    }

    return $value;
}
    


sub device_credentials_attr
{
    my $self = shift;
    my $dev = shift;
    my $attr = shift;
    
    my $source = $self->device_attr($dev, 'credentials-source');
    if( not defined( $source ) )
    {
        $Gerty::log->error
            ('Mandatory attribute "credentials-source" is not defined for ' .
             'device ' . $dev->{'SYSNAME'});
        return undef;
    }
    
    if( $source eq 'inline' )
    {
        return( $self->device_attr($dev, $attr) );
    }
    else
    {
        return( $self->load_and_execute($dev, 'credentials-source',
                                        'device_credentials_attr',
                                        $dev, $attr));
    }
}
    

# fetch and validate the devices
sub retrieve_devices
{
    my $self = shift;

    my $ret = [];
    my %seen;
    
    foreach my $devlist ( values %{$self->{'devlists'}} )
    {
        my $devices = $devlist->retrieve_devices();
        foreach my $dev ( @{$devices} )
        {
            if( not defined($dev->{'SYSNAME'}) )
            {
                $Gerty::log->error
                    ('Mandatory attribute SYSNAME is not defined for a ' .
                     'device from ' . $dev->{'SOURCE'});
                next;
            }

            my $sysname = $dev->{'SYSNAME'};

            if( $seen{$sysname} )
            {
                $Gerty::log->error
                    ('Duplicate SYSNAME for a device from ' .
                     $dev->{'SOURCE'});
                next;
            }
            else
            {
                $seen{$sysname} = 1;
            }

            # load device class
            if( not defined($self->{'devclasses'}{$dev->{'DEVCLASS'}}) )
            {
                my $class =
                    new Gerty::DeviceClass({class => $dev->{'DEVCLASS'}});
                return undef unless $class;                
                $self->{'devclasses'}{$dev->{'DEVCLASS'}} = $class;
            }
            
            if( not defined($dev->{'ADDRESS'}) )
            {
                # Sysname could actually be the IP address
                if( $sysname =~ /^[0-9]+\./o or
                    $sysname =~ /^[0-9a-f]+\:/oi )
                {
                    $Gerty::log->debug
                        ('SYSNAME' . $sysname . ' looks like IP address');
                    $dev->{'ADDRESS'} = $sysname;
                }
                else
                {
                    $Gerty::log->debug
                        ('ADDRESS is not defined for "' . $sysname .
                         '". Trying to resolve the name in DNS');
                    
                    my $hostname = $sysname;
                    if( index($hostname, '.') < 0 )
                    {
                        my $domain_name =
                            $self->device_attr($dev, 'domain-name');
                        if( defined($domain_name) )
                        {
                            $hostname .= '.' . $domain_name;
                        }
                    }
                    my $h = gethost($hostname);
                    if( not defined( $h ) )
                    {
                        $Gerty::log->error
                            ('Cannot resolve DNS name: ' . $hostname);
                        next;
                    }

                    my @addresses = @{$h->addr_list()};
                    if( scalar(@addresses) > 1 )
                    {
                        $Gerty::log->warning
                            ('DNS name ' . $hostname . ' resolves into more ' .
                             'than one IP address');
                    }

                    my $ipaddr = inet_ntoa($addresses[0]);
                    $Gerty::log->debug
                        ('Resolved ' . $sysname . ' into ' . $ipaddr);

                    $dev->{'ADDRESS'} = $ipaddr;
                }
            }

            push(@{$ret}, $dev);
        }        
    }

    return $ret;
}



sub init_access
{
    my $self = shift;
    my $dev = shift;

    my $acc = $self->load_and_execute
        ($dev, 'access-handler', 'new',
         {'job' => $self, 'device' => $dev});
    
    if( not defined($acc) )
    {
        return 0;
    }
    
    $dev->{'ACCESS_HANDLER'} = $acc;
    return 1;
}



sub execute
{
    my $self = shift;
    my $devices = shift;

    foreach my $dev (@{$devices})
    {
        my $acc = $dev->{'ACCESS_HANDLER'};
        next unless $acc->connect();
        
        my $handler = $self->load_and_execute
            ($dev, 'command-handler', 'new',
             {'job' => $self, 'device' => $dev});

        if( not $handler )
        {
            $Gerty::log->error
                ('Failed to initialize the command handler for device "' .
                 $dev->{'SYSNAME'});
            $acc->close();
            next;
        }

        my $actions = $handler->supported_actions();
        $Gerty::log->debug('Actions supported for ' . $dev->{'SYSNAME'} .
                           ': ' . join(', ', @{$actions}));
        
        foreach my $action (@{$actions})
        {
            if( $self->device_attr($dev, 'do-' . $action) )
            {
                my $path = $self->device_attr($dev, $action . '-path');
                if( not defined($path) )
                {
                    $Gerty::log->debug
                        ($action . '-path is not defined for ' .
                         $dev->{'SYSNAME'} . ', trying default-output-path');
                    $path = $self->device_attr($dev, 'default-output-path');
                    if( not defined($path) )
                    {
                        $Gerty::log->error
                            ('Neither ' . $action .
                             '-path nor default-output-path is defined for ' .
                             $dev->{'SYSNAME'} . '. Skipping the action: ' .
                             $action);
                        next;
                    }
                }

                if( not -d $path )
                {
                    $Gerty::log->critical
                        ('No such directory: "' . $path .
                         '". Skipping action ' .  $action .
                         ' for device ' . $dev->{'SYSNAME'});
                    next;
                }
                
                my $fname = $path . '/' .
                    $dev->{'SYSNAME'} . '.' . $action;
                
                my $fh = new IO::File($fname, 'w');
                if( not $fh )
                {
                    $Gerty::log->critical('Cannot open file ' .
                                          $fname . ' for writing: ' . $!);
                    return next;
                }
                
                my $out = $handler->do_action($action);
                if( defined($out) )
                {
                    $fh->print($out);
                }
                
                $fh->close();

                # If postprocess handler is defined, hand over the control
                # immediately (must not take too much time, as we still have
                # CLI session open)

                my $pp_attr = $action . '-postprocess';
                if( defined( $self->device_attr($dev, $pp_attr) ) )
                {
                    my $pp_handler = $self->load_and_execute
                        ($dev, $pp_attr, 'new',
                         {'job' => $self, 'device' => $dev});
                    
                    if( $pp_handler )
                    {
                        $pp_attr->process($fname);
                    }                    
                }
            }
        }                
    }
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
