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

# SNMP Action handlers for HDSL2-SHDSL-LINE-MIB (RFC4319)

# Tested with:
#  Actelis Networks Inc., ML622, SW version 6.10-501V061601

package Gerty::SNMP::Mixin::HDSL2_SHDSL_LINE_MIB;

use strict;
use warnings;
use JSON ();


our $action_handlers_registry = {
    'hdsl_line_stats' => \&hdsl_line_stats,    
};


our $retrieve_action_handlers = \&retrieve_action_handlers;


sub retrieve_action_handlers
{
    my $ahandler = shift;

    return $action_handlers_registry;
}



my %hdslUnitId =
    (
     1 => 'xtuC',
     2 => 'xtuR',
     3 => 'xru1',
     4 => 'xru2',
     5 => 'xru3',
     6 => 'xru4',
     7 => 'xru5',
     8 => 'xru6',
     9 => 'xru7',
     10 => 'xru8',
    );

my %hdslUnitSide =
    (
     1 => 'networkSide',
     2 => 'customerSide',
    );

sub hdsl_line_stats
{
    my $ahandler = shift;
    my $action = shift;

    my $session = $ahandler->session();

    my $now = time();
    my $full_15min = $now - ($now % 900);

    # Number of 15-minute intervals to poll from device
    my $n15MinIntervals = $ahandler->device_attr('hdsl-15min-intervals');
    if( not defined($n15MinIntervals) )
    {
        $n15MinIntervals = 8;
    }

    my $oids_per_request = $ahandler->device_attr('hdsl-oids-per-request');
    if( not defined($oids_per_request) )
    {
        $oids_per_request = 20;
    }

    my $xtuc_only = $ahandler->device_attr('hdsl-xtuc-only');
    
    my $result = {'timestamp' => $now,
                  'hdsl_15min_counters' => {},
    };

    my %unit_instances;

    # get the number of repeater units on each line
    # HDSL2-SHDSL-LINE-MIB::hdsl2ShdslStatusNumAvailRepeaters
    {
        my $base = '1.3.6.1.2.1.10.48.1.2.1.1';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {            
            while( my( $oid, $val ) = each %{$table} )
            {
                my $ifIndex = substr( $oid, $prefixLen );
                # xtuC and xtuR are always present
                # Unless we want xtuC only, check the repeaters
                $unit_instances{$ifIndex}{1} = 1;
                if( not $xtuc_only )
                {
                    $unit_instances{$ifIndex}{2} = 1;
                
                    my $unitId = 3;
                    my $nRepeaters = int($val);
                    while( $nRepeaters > 0 )
                    {
                        $unit_instances{$ifIndex}{$unitId} = 1;
                        $unitId++;
                        $nRepeaters--;
                    }
                }
            }        
        }
        else
        {
            return {
                'success' => 0,
                'content' =>
                    'Cannot retrieve ' .
                    'HDSL2-SHDSL-LINE-MIB::' .
                    'hdsl2ShdslStatusNumAvailRepeaters ' .
                    ' from ' . $ahandler->sysname . ': ' .
                    $session->error};
        }
    }

    my @counter_instances;
    
    # get the endpoint information: side and wire pair
    # HDSL2-SHDSL-LINE-MIB::hdsl2ShdslEndpointCurrSnrMgn
    {
        my $base = '1.3.6.1.2.1.10.48.1.5.1.2';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {            
            while( my( $oid, $val ) = each %{$table} )
            {
                my $INDEX = substr( $oid, $prefixLen );
                my($ifIndex, $unitId, $side, $wirepair) = split(/\./, $INDEX);
                if( $unit_instances{$ifIndex}{$unitId} )
                {
                    push(@counter_instances, $INDEX);
                }
            }        
        }
        else
        {
            return {
                'success' => 0,
                'content' =>
                    'Cannot retrieve ' .
                    'HDSL2-SHDSL-LINE-MIB::' .
                    'hdsl2ShdslEndpointCurrSnrMgn ' .
                    ' from ' . $ahandler->sysname . ': ' .
                    $session->error};
        }
    }

    my %results_15min;
    
    # HDSL2-SHDSL-LINE-MIB::hdsl2Shdsl15MinIntervalTable
    {
        # Instead of walking through the whole table, retrieve only needed
        # OIDs. 
        my %basePrefixes =
            ('ES'           => '1.3.6.1.2.1.10.48.1.6.1.2',
             'SES'          => '1.3.6.1.2.1.10.48.1.6.1.3',
             'CRCA'         => '1.3.6.1.2.1.10.48.1.6.1.4',
             'LOSWS'        => '1.3.6.1.2.1.10.48.1.6.1.5',
             'UAS'          => '1.3.6.1.2.1.10.48.1.6.1.6');

        while(my($base_name, $base_oid) = each %basePrefixes)
        {
            my @oids;
            foreach my $INDEX (@counter_instances)
            {
                for( my $intvl = 1; $intvl <= $n15MinIntervals; $intvl++ )
                {
                    push(@oids, $base_oid . '.' . $INDEX . '.' . $intvl);
                }                    
            }

            while( scalar(@oids) > 0 )
            {
                my @request_oids;
                while( scalar(@request_oids) < $oids_per_request and
                       scalar(@oids) > 0 )
                {
                    push(@request_oids, pop(@oids));
                }

                my $r =
                    $session->get_request('-varbindlist' => \@request_oids);
                if( defined($r) )
                {
                    my $prefixLen = length( $base_oid ) + 1;

                    while(my($oid, $val) = each %{$r})
                    {
                        my $INDEX = substr( $oid, $prefixLen );
                        $results_15min{$INDEX}{$base_name} = $val;
                    }
                }
                else
                {
                    return {
                        'success' => 0,
                        'content' =>
                            'Cannot retrieve the following OIDs: ' .
                            join(', ', @request_oids) .
                            ' from ' . $ahandler->sysname . ': ' .
                            $session->error};
                }                
            }
        }    
    }

    # decode the results
    my %ifName;
    
    foreach my $INDEX (keys %results_15min)
    {
        my($ifIndex, $unitId, $sideId, $wirepairId, $intvl) =
            split(/\./, $INDEX);

        my $intf = $ifName{$ifIndex};
        if( not defined($intf) )
        {
            my $intf_info = $ahandler->get_interface_info($ifIndex);
            if( not defined($intf_info) )
            {
                return {
                    'success' => 0,
                    'content' =>
                        'Cannot retrieve interface name for ifIndex=' .
                        $ifIndex . ' from ' . $ahandler->sysname};
            }

            $intf = $ifName{$ifIndex} = $intf_info->{'name'};
        }

        my $unit = $hdslUnitId{$unitId};
        my $side = $hdslUnitSide{$sideId};
        my $wirepair = 'wirepair' . $wirepairId;
        my $intvl_timestamp = $full_15min - (900*($intvl-1));
        
        $result->{'hdsl_15min_counters'}{$intf}{$unit}{$side}{
            $wirepair}{$intvl_timestamp} = $results_15min{$INDEX};
    }
        
    my $json = new JSON;
    $json->pretty(1);
    
    return {
        'success' => 1,
        'content' => $json->encode($result),
        'rawdata' => $result,
        'has_json' => 1,
        'has_rawdata' => 1,
    };
}


        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
