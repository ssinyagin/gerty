#  Copyright (C) 2011  Stanislav Sinyagin
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

# Post-processing module for CISCO_WAN_3G_MIB data.
# It stores the results in a database.
# See for DB definitions:
#   share/sql/CISCO_WAN_3G_MIB.mysql.sql   


package Gerty::SNMP::Postprocess::CISCO_WAN_3G_MIB_dbstore;

use base qw(Gerty::PostprocessDBUpdate);

use strict;
use warnings;

use Date::Parse;
use JSON ();
use Digest::MD5 qw/md5_hex/;

sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    $self->register_action_processors({'c3g_gsm_stats' =>
                                           [ \&process_c3g_gsm_stats ]});
    return $self;
}



sub process_c3g_gsm_stats
{
    my $self = shift;    
    my $action = shift;
    my $result = shift;
    my $dblink = shift;

    my $data = $result->{'rawdata'};

    if( not defined($data->{'c3gGsmCurrentBand'}) )
    {
        return;
    }

    my $timestamp_str = $dblink->sql_unixtime_string($data->{'timestamp'});
    
    foreach my $phy (keys %{$data->{'c3gGsmCurrentBand'}})
    {
        if( defined($data->{'c3gCurrentServiceType'}{$phy}) )
        {
            $dblink->dbh->do
                ('INSERT INTO C3G_GSM_SRVTYPE ' .
                 ' (HOSTNAME, PHY_IDX, MEASURE_TS, ' .
                 '  GSM_SRV_TYPE, GSM_BAND) ' .
                 'VALUES(\'' . $self->sysname . '\', ' . $phy . ', ' .
                 $timestamp_str . ',' .
                 '\'' . $data->{'c3gCurrentServiceType'}{$phy} . '\', ' .
                 '\'' . $data->{'c3gGsmCurrentBand'}{$phy} . '\')');
        }
        
        if( defined($data->{'c3gGsmHistoryRssiPerMinute'}{$phy}) )
        {
            my $max_stored_ts = 0;
            
            my $r = $dblink->dbh->selectrow_arrayref
                ('SELECT MAX(MEASURE_TS) ' .
                 'FROM C3G_GSM_RSSI_MINUTE_HISTORY ' .
                 'WHERE HOSTNAME=\'' . $self->sysname . '\' AND ' .
                 ' PHY_IDX=' . $phy);
            if( defined($r) and defined($r->[0]) )
            {
                $max_stored_ts = str2time($r->[0]);
                if( not defined($max_stored_ts) )
                {
                    $Gerty::log->error
                        ('Cannot interpret SQL date string: "' .
                         $r->[0] . '". Aborting the action postprocessing');
                    return;
                }
            }
            
            foreach my $tuple
                (@{$data->{'c3gGsmHistoryRssiPerMinute'}{$phy}})
            {
                my ($rssi, $timestamp) = @{$tuple};
                if( $timestamp > $max_stored_ts )
                {
                    $dblink->dbh->do
                        ('INSERT INTO C3G_GSM_RSSI_MINUTE_HISTORY ' .
                         ' (HOSTNAME, PHY_IDX, MEASURE_TS, WEAKEST_RSSI) ' .
                         'VALUES(\'' . $self->sysname . '\', ' .
                         $phy . ', ' .
                         $dblink->sql_unixtime_string($timestamp) . ',' .
                         $rssi . ')');
                }
            }
        }

        $dblink->dbh->commit();
    }

    # Update hardware info
    foreach my $phy (keys %{$data->{'c3g_HardwareInfo'}})
    {
        # Encode hardware info in a JSON with sorted entries
        my $json = new JSON;
        $json->canonical(1);
        my $hwinfo_json_str =
            $json->encode($data->{'c3g_HardwareInfo'}{$phy});
        my $hwinfo_md5 = md5_hex($hwinfo_json_str);

        # Create a new entry if the previous one does not exist or has
        # a different MD5 sum
        my $need_new_entry = 0;
        
        my $r = $dblink->dbh->selectrow_arrayref
            ('SELECT MAX(BEGIN_TS) ' .
             'FROM C3G_HARDWAREINFO ' .
             'WHERE HOSTNAME=\'' . $self->sysname . '\' AND ' .
             ' PHY_IDX=' . $phy);
        if( not defined($r) or not defined($r->[0]) )
        {
            $need_new_entry = 1;
        }
        else
        {
            my $r1 = $dblink->dbh->selectrow_arrayref
                ('SELECT MD5HASH ' .
                 'FROM C3G_HARDWAREINFO ' .
                 'WHERE HOSTNAME=\'' . $self->sysname . '\' AND ' .
                 ' PHY_IDX=' . $phy . ' AND ' .
                 'BEGIN_TS=\'' . $r->[0] . '\'');
            if( $r1->[0] ne $hwinfo_md5 )
            {
                $need_new_entry = 1;
            }
        }

        if( $need_new_entry )
        {
            $dblink->dbh->do
                ('INSERT INTO C3G_HARDWAREINFO ' .
                 ' (HOSTNAME, PHY_IDX, BEGIN_TS, END_TS, MD5HASH, HW_JSON) ' .
                 'VALUES(\'' . $self->sysname . '\', ' .
                 $phy . ', ' .
                 $timestamp_str . ', ' . $timestamp_str . ', ' .
                 '\'' . $hwinfo_md5 . '\', \'' . $hwinfo_json_str . '\')');
        }
        else
        {
            $dblink->dbh->do
                ('UPDATE C3G_HARDWAREINFO ' .
                 'SET END_TS=' . $timestamp_str . ' ' .
                 'WHERE HOSTNAME=\'' . $self->sysname . '\' AND ' .
                 ' PHY_IDX=' . $phy . ' AND ' .
                 'BEGIN_TS=\'' . $r->[0] . '\'');
        }
        
        $dblink->dbh->commit();
    }
}


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
