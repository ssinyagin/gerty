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

# NETCONF post-processing for Juniper JunOS devices
# It stores the results in a database.
# See for DB definitions:
#   share/sql/JunOSDBStore.dbinit.oracle.sql 


package Gerty::Netconf::Postprocess::JunOSDBStore;

use base qw(Gerty::HandlerBase);

use strict;
use warnings;

use JSON ();
use Date::Format;
use Gerty::DBLink;

my %action_processor =
    (
     'junos.get-vpls-mac-counts' => \&process_vpls_mac_counts,
     );
    
sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    return $self;
}



sub process_result
{
    my $self = shift;    
    my $action = shift;
    my $result = shift;

    if( ref($action_processor{$action}) )
    {
        if( $self->device_attr($action . '.update-db') )
        {
            my $dblink_name = $self->device_attr('junos.postprocess.dblink');
            
            if( not defined($dblink_name) )
            {
                $Gerty::log->error
                    ('Missing a mandatory attribute ' .
                     '"junos.postprocess.dblink". Skipping the ' .
                     'prostprocessing step for the action ' .
                     $action . ' for device: ' .
                     $self->sysname);
                return;
            }

            my $dblink = new Gerty::DBLink
                ({'job' => $self->job, 'device' => $self->device,
                  'dblink' => $dblink_name});
            if( $dblink->connect() )
            {
                &{$action_processor{$action}}($self, $action,
                                              $result, $dblink);
                $dblink->disconnect();
            }
            else
            {
                $Gerty::log->error
                    ('Failed to connect to the database. ' .
                     'Skipping the prostprocessing step for the action ' .
                     $action . ' for device: ' . $self->sysname);
                return;
            }
        }
    }
}



sub process_vpls_mac_counts
{
    my $self = shift;    
    my $action = shift;
    my $result = shift;
    my $dblink = shift;

    my $json = new JSON;
    my $data = $json->decode($result->{'content'});
    
    if( not defined($data) )
    {
        $Gerty::log->error( 'Error in action post-processing' .
                            'Cannot parse JSON in results of action "' .
                            $action . '" for device: ' . $self->sysname );
        return;
    }

    my $now = 'to_date(\'' . time2str('%Y%m%d%H%M%S', time()) .
        '\',\'YYYYMMDDHH24MISS\')';
    
    while(my ($instance, $r) = each %{$data})
    {
        if( defined($r->{'total_macs'}) )
        {
            update_mac_counts
                ($dblink->dbh,
                 $now,
                 {'HOSTNAME' => $self->sysname,
                  'INSTANCE_NAME' => $instance,
                  'MAC_COUNT' => $r->{'total_macs'}});
        }

        if( defined($r->{'interface_macs'}) )
        {
            while(my ($intf, $count) = each %{$r->{'interface_macs'}})
            {
                update_mac_counts
                    ($dblink->dbh,
                     $now,
                     {'HOSTNAME' => $self->sysname,
                      'INSTANCE_NAME' => $instance,
                      'INTERFACE_NAME' => $intf,
                      'MAC_COUNT' => $count});
            }
        }

        if( defined($r->{'vlan_macs'}) )
        {
            while(my ($vlan, $count) = each %{$r->{'vlan_macs'}})
            {
                update_mac_counts
                    ($dblink->dbh,
                     $now,
                     {'HOSTNAME' => $self->sysname,
                      'INSTANCE_NAME' => $instance,
                      'VLAN_NUM' => $vlan,
                      'MAC_COUNT' => $count});
            }
        }
    }
}



sub update_mac_counts
{
    my $dbh = shift;
    my $now = shift;
    my $v = shift;
    

    my @columns;
    my @values;

    foreach my $col ('HOSTNAME', 'INSTANCE_NAME',
                     'INTERFACE_NAME', 'VLAN_NUM', 'MAC_COUNT')
    {
        if( defined($v->{$col}) )
        {
            push(@columns, $col);
            push(@values, '\'' . $v->{$col} . '\'');
        }
    }
    
    $dbh->do
        ('INSERT INTO JNX_VPLS_MAC_COUNT_HISTORY ' .
         '(' . join(',', @columns) . ', UPDATE_TS) ' .
         'VALUES(' . join(',', @values) . ',' . $now . ')'); 
    
    $dbh->commit();
}

             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
