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

#  NETCONF actions


package Gerty::Netconf::ActionHandler;

use base qw(Gerty::MixinLoader);

use strict;
use warnings;

use XML::LibXML;
use XML::LibXML::XPathContext;

use Gerty::Netconf::RPCReply;

sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    my $acc = $self->device->{'ACCESS_HANDLER'};

    foreach my $method ('send_netconf_message', 'receive_netconf_message')
    {
        if( not $acc->has($method) )
        {
            $Gerty::log->critical
                ('The access handler for device "' .
                 $self->sysname .
                 '" does not provide "' . $method . '" method');
            return undef;
        }
    }

    # Netconf Client capabilities. Mix-in modules can add their
    # capabilities here upon initialization.
    
    $self->{'netconf_client_capability'} = {
        'urn:ietf:params:xml:ns:netconf:base:1.0' => 1,
    };

    $self->init_mixins('+netconf.handler-mixins');
    
    {
        my $doc = XML::LibXML->createDocument( "1.0", "UTF-8" );
        my $root = $doc->createElement('hello');
        $doc->setDocumentElement($root);
        my $caps_node = $doc->createElement('capabilities');
        $root->appendChild($caps_node);

        foreach my $cap (sort keys %{$self->{'netconf_client_capability'}})
        {
            my $node = $doc->createElement('capability');
            $node->appendText($cap);
            $caps_node->appendChild($node);
        }

        $self->send_xml($root);
    }

    {
        my $hello_result = $self->receive_as_string();
        if( not defined($hello_result) )
        {
            $Gerty::log->error('Failed to receive RPC hello message');
            return undef;
        }

        my $parser = new XML::LibXML;
        my $doc = $parser->parse_string($hello_result);
        if( not defined($doc) )
        {
            $Gerty::log->error('Failed to parse RPC hello XML');
            return undef;
        }
        
        my $xpc = new XML::LibXML::XPathContext($doc);
        
        my @cap_nodes = $xpc->findnodes('hello//capability');
        $self->{'server_capability'} = {};
        foreach my $node (@cap_nodes)
        {
            my $cap = $node->getFirstChild()->nodeValue();
            $self->{'server_capability'}{$cap} = 1;
            
            if( $Gerty::debug_level >= 2 )
            {
                $Gerty::log->debug
                    ($self->sysname . ': NETCONF server capability ' . $cap);
            }
        }
    }

    $self->{'message-id'} = 1;
    
    return $self;
}



sub receive_as_string
{
    my $self = shift;
    my $acc = $self->device->{'ACCESS_HANDLER'};
    
    my $result = $acc->receive_netconf_message();
    return( $result->{'success'} ? $result->{'msg'}:undef );
}
    


sub send_rpc
{
    my $self = shift;
    my $request = shift;
    
    $request->set_message_id( $self->{'message-id'} );
    
    $self->send_xml($request->root);

    my $reply_string = $self->receive_as_string();
    if( not defined($reply_string) )
    {
        $Gerty::log->error('Failed to receive RPC reply');
        return undef;
    }

    my $reply = new Gerty::Netconf::RPCReply( $reply_string );
    if( not defined($reply) )
    {
        $Gerty::log->error('Failed to parse RPC reply XML');
        return undef;
    }

    if( $reply->is_error() )
    {
        $Gerty::log->error('RPC error');
        $self->{'error_details'} = $reply->error_details();
        return undef;
    }

    my $msgid = $reply->xpc->findvalue
        ('/netconf:rpc-reply/@message-id');
    if( $msgid != $self->{'message-id'} )
    {
        $Gerty::log->error('message-id in RPC Reply (' . $msgid . ') ' .
                           'does not match that in Request ' .
                           '(' . $self->{'message-id'} . ')');
        $reply = undef;
    }
    
    $self->{'message-id'}++;

    return $reply;
}



sub send_string
{
    my $self = shift;
    my $msg = shift;
    my $acc = $self->device->{'ACCESS_HANDLER'};
    $acc->send_netconf_message($msg);
}


sub send_xml
{
    my $self = shift;
    my $node = shift;    
    $self->send_string($node->toString());
}




    

        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
