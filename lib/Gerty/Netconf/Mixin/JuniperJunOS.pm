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

# NETCONF actions for Juniper JunOS devices


package Gerty::Netconf::Mixin::JuniperJunOS;

use strict;
use warnings;

use Gerty::Netconf::RPCRequest;
use JSON ();

our $retrieve_action_handlers = \&retrieve_action_handlers;


sub retrieve_action_handlers
{
    my $ahandler = shift;

    my $ret = {
        'junos.get-vpls-mac-counts' => \&get_vpls_mac_counts,
    };

    my $actions = $ahandler->device_attr('+junos.command-actions');
    if( defined($actions) )
    {
        foreach my $action (split(/,/o, $actions))
        {
            my $attr = $action . '.command';
            my $cmd = $ahandler->device_attr($attr);
            if( not defined($cmd) or length($cmd) == 0 )
            {
                $Gerty::log->error
                    ('+junos.command-actions defines the action "' .
                     $action . '", but attribute "' . $attr .
                     '" is not defined for device: ' .
                     $ahandler->sysname);
                next;
            }

            $ahandler->{'junos_cmdaction_command'}{$action} = $cmd;            
            $ret->{$action} = \&command;    
        }
    }

    return $ret;
};




sub command
{
    my $ahandler = shift;
    my $action = shift;

    my $req = new Gerty::Netconf::RPCRequest;
    my $method_node = $req->set_method('command');

    my $text_node = XML::LibXML::Text->new
        ( $ahandler->{'junos_cmdaction_command'}{$action} );    
    $method_node->appendChild($text_node);

    my $reply = $ahandler->send_rpc($req);
    if( not defined($reply) )
    {
        return {'success' => 0,
                'content' => 'Failed to send Netconf RPC request'};
    }
        
    return {'success' => 1, 'content' => $reply->doc->toString()};
}


# Retrieve VPLS MAC counts
# http://goo.gl/KeCjX
#  <rpc>
#    <get-vpls-mac-table>
#      <count/>
#    </get-vpls-mac-table>
#  </rpc>

my %rdb_blacklist = ('__juniper_private1__' => 1);

sub get_vpls_mac_counts
{
    my $ahandler = shift;

    my $req = new Gerty::Netconf::RPCRequest;
    my $method_node = $req->set_method('get-vpls-mac-table');
    $method_node->appendChild($req->doc->createElement('count'));
    
    my $reply = $ahandler->send_rpc($req);
    if( not defined($reply) )
    {
        return {'success' => 0,
                'content' => 'Failed to send Netconf RPC request'};
    }

    if( $ahandler->device_attr('junos.netconf.rawxml') )
    {
        return {'success' => 1, 'content' => $reply->doc->toString()};
    }
    
    my $ret = {};
    foreach my $entry_node
        ($reply->xpc->findnodes('//netconf:l2ald-rtb-mac-count-entry'))
    {
        my $r = {};
        
        my $rtb_name =
            $reply->xpc->findvalue('netconf:rtb-name', $entry_node);
        
        next if $rdb_blacklist{$rtb_name};

        # Convert count strings into numbers
        $r->{'total_macs'} =
            0 + $reply->xpc->findvalue('netconf:rtb-mac-count', $entry_node);

        # per-interface MAC counts
        
        $r->{'interface_macs'} = {};
        foreach my $if_node
            ($reply->xpc->findnodes('.//netconf:l2ald-rtb-if-mac-count-entry',
                                    $entry_node))
        {
            my $if_name =
                $reply->xpc->findvalue('netconf:interface-name', $if_node);
            my $mac_count =
                0 + $reply->xpc->findvalue('netconf:mac-count', $if_node);
            
            $r->{'interface_macs'}{$if_name} = $mac_count;
        }

        # per-VLAN MAC counts
        
        $r->{'vlan_macs'} = {};
        foreach my $vlan_node
            ($reply->xpc->findnodes
             ('.//netconf:l2ald-rtb-learn-vlan-mac-count-entry', $entry_node))
        {
            my $vlan =
                $reply->xpc->findvalue('netconf:learn-vlan', $vlan_node);
            my $mac_count =
                0 + $reply->xpc->findvalue('netconf:mac-count', $vlan_node);
            
            $r->{'vlan_macs'}{$vlan} = $mac_count;
        }

        
        $ret->{$rtb_name} = $r;
    }

    my $json = new JSON;
    $json->pretty(1);
    
    return {
        'success' => 1,
        'content' => $json->encode($ret),
        'rawdata' => $ret,
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
