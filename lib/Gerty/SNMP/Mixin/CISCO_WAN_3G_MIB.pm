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

# SNMP Action handlers for CISCO-WAN-3G-MIB


package Gerty::SNMP::Mixin::CISCO_WAN_3G_MIB;

use strict;
use warnings;
use JSON ();


our $action_handlers_registry = {
    'c3g_gsm_stats' => \&c3g_gsm_stats,    
};


our $retrieve_action_handlers = \&retrieve_action_handlers;


sub retrieve_action_handlers
{
    my $ahandler = shift;

    return $action_handlers_registry;
}



my %c3gSrvCap =
    (
     'oneXRtt'   => 1<<(0+1),
     'evDoRel0'  => 1<<(1+1),
     'evDoRelA'  => 1<<(2+1),
     'evDoRelB'  => 1<<(3+1),
     'gprs'      => 1<<(4+1),
     'edge'      => 1<<(5+1),
     'umtsWcdma' => 1<<(6+1),
     'hsdpa'     => 1<<(7+1),
     'hsupa'     => 1<<(8+1),
     'hspa'      => 1<<(9+1),
     'hspaPlus'  => 1<<(10+1),
    );

my %c3gGsmBand =
    (
     1 => 'unknown',
     2 => 'invalid',
     3 => 'none',
     4 => 'gsm850',
     5 => 'gsm900',
     6 => 'gsm1800',
     7 => 'gsm1900',
     8 => 'wcdma800',
     9 => 'wcdma850',
     10 => 'wcdma1900',
     11 => 'wcdma2100',
    );
     

sub c3g_gsm_stats
{
    my $ahandler = shift;
    my $action = shift;

    my $session = $ahandler->session();

    my $now = time();
    my $full_minute = $now - ($now % 60);
    
    my $result = {'timestamp' => $now,
                  'c3gGsmHistoryRssiPerMinute' => {},
                  'c3gCurrentServiceType' => {},
                  'c3gGsmCurrentBand' => {}};
    
    # CISCO-WAN-3G-MIB::c3gGsmHistoryRssiPerMinute
    {
        my $base = '1.3.6.1.4.1.9.9.661.1.3.4.3.1.2';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {            
            while( my( $oid, $val ) = each %{$table} )
            {
                my $phy = substr( $oid, $prefixLen );
                my @values = unpack('C*', $val);
                my $timestamp = $full_minute;
                my $timestamped_values = [];
                foreach my $val (@values)
                {
                    push( @{$timestamped_values}, [$val * -1, $timestamp] );
                    $timestamp -= 60;
                }
                
                $result->{'c3gGsmHistoryRssiPerMinute'}{$phy} =
                    $timestamped_values;
            }        
        }
        else
        {
            return {'success' => 0,
                    'content' =>
                        'Cannot retrieve ' .
                        'CISCO-WAN-3G-MIB::c3gGsmHistoryRssiPerMinute ' .
                        ' from ' . $ahandler->sysname . ': ' .
                        $session->error};
        }
    }

    # CISCO-WAN-3G-MIB::c3gCurrentServiceType
    {
        my $base = '1.3.6.1.4.1.9.9.661.1.1.1.5';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {            
            while( my( $oid, $val ) = each %{$table} )
            {
                my $phy = substr( $oid, $prefixLen );
                # decode BITS value
                my $srv_type_n = unpack('n', $val);
                my $srv_type;
                foreach my $type (keys %c3gSrvCap)
                {
                    if( $srv_type_n & $c3gSrvCap{$type} )
                    {
                        $srv_type = $type;
                        last;
                    }
                }
                
                $result->{'c3gCurrentServiceType'}{$phy} = $srv_type;
            }        
        }
        else
        {
            return {'success' => 0,
                    'content' =>
                        'Cannot retrieve ' .
                        'CISCO-WAN-3G-MIB::c3gCurrentServiceType ' .
                        ' from ' . $ahandler->sysname . ': ' .
                        $session->error};
        }
    }
    
    # CISCO-WAN-3G-MIB::c3gGsmCurrentBand
    {
        my $base = '1.3.6.1.4.1.9.9.661.1.3.4.1.1.3';
        my $prefixLen = length( $base ) + 1;
        my $table = $session->get_table( -baseoid => $base );
        
        if( defined( $table ) )
        {            
            while( my( $oid, $val ) = each %{$table} )
            {
                my $phy = substr( $oid, $prefixLen );
                $result->{'c3gGsmCurrentBand'}{$phy} = $c3gGsmBand{$val};
            }        
        }
        else
        {
            return {'success' => 0,
                    'content' =>
                        'Cannot retrieve ' .
                        'CISCO-WAN-3G-MIB::c3gGsmCurrentBand ' .
                        ' from ' . $ahandler->sysname . ': ' .
                        $session->error};
        }
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
