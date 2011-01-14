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

our $retrieve_action_handlers = \&retrieve_action_handlers;


sub retrieve_action_handlers
{
    my $self = shift;

    my $ret = {
        'junos.get-vpls-mac-table' => \&get_vpls_mac_table,
    };

    my $actions = $self->device_attr('+junos.command-actions');
    if( defined($actions) )
    {
        foreach my $action (split(/,/o, $actions))
        {
            my $attr = $action . '.command';
            my $cmd = $self->device_attr($attr);
            if( not defined($cmd) or length($cmd) == 0 )
            {
                $Gerty::log->error
                    ('+junos.command-actions defines the action "' .
                     $action . '", but attribute "' . $attr .
                     '" is not defined for device: ' .
                     $self->sysname);
                next;
            }

            $self->{'junos_cmdaction_command'}{$action} = $cmd;            
            $ret->{$action} = \&command;    
        }
    }

    return $ret;
};




sub command
{
    my $self = shift;
    my $action = shift;

    my $req = new Gerty::Netconf::RPCRequest;
    my $method_node = $req->set_method('command');

    my $text_node = XML::LibXML::Text->new
        ( $self->{'junos_cmdaction_command'}{$action} );    
    $method_node->appendChild($text_node);

    my $reply = $self->send_rpc($req);
    if( not defined($reply) )
    {
        return {'success' => 0,
                'content' => 'Failed to send Netconf RPC request'};
    }
        
    return {'success' => 1, 'content' => $reply->doc->toString()};
}




sub get_vpls_mac_table
{
    my $self = shift;
    # TODO
}


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
