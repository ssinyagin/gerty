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

# Post-processing module for CISCO_WAN_3G_MIB data.
# It stores the results in a database.
# See for DB definitions:


package Gerty::SNMP::Postprocess::CISCO_WAN_3G_MIB_dbstore;

use base qw(Gerty::PostprocessDBUpdate);

use strict;
use warnings;

use Date::Parse;

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
    
    foreach my $phy (keys %{$data->{'c3gGsmCurrentBand'}})
    {
        if( defined($data->{'c3gCurrentServiceType'}{$phy}) )
        {
            $dblink->dbh->do
                ('INSERT INTO C3G_GSM_SRVTYPE ' .
                 ' (HOSTNAME, PHY_IDX, MEASURE_TS, ' .
                 '  GSM_SRV_TYPE, GSM_BAND) ' .
                 'VALUES(\'' . $self->sysname . '\', ' . $phy . ', ' .
                 $dblink->sql_unixtime_string($data->{'timestamp'}) . ',' .
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
}


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
