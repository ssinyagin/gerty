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

use base qw(Gerty::HandlerBase);

use strict;
use warnings;

use XML::LibXML;
use XML::LibXML::XPathContext;

use Gerty::Netconf::RPCRequest;
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
    
    foreach my $attr ('+netconf.handler-mixins')
    {
        $self->{$attr} = $self->device_attr($attr);
    }

    
    # initialize mix-in modules
    $self->{'mixin_actions'} = {};
    $self->{'mixin_origin'} = {};
    
    $self->{'client_capability'} = {
        'urn:ietf:params:xml:ns:netconf:base:1.0' => 1,
    };
    
    my $mixins = $self->{'+netconf.handler-mixins'};
    
    if( defined($mixins) )
    {
        foreach my $module (split(/,/o, $mixins))
        {
            eval(sprintf('require %s', $module));
            if( $@ )
            {
                $Gerty::log->error
                    ('Error loading Perl module ' . $module .
                     ' specified in "+netconf.handler-mixins" for device "' .
                     $self->sysname . '": ' . $@);
                next;
            }
            
            my $var = "\$" . $module . '::action_handlers';
            my $handlers = eval($var);
            if( $@ )
            {
                $Gerty::log->error
                    ('Error accessing ' . $var . ' : ' . $@);
                next;
            }

            if( not defined($handlers) )
            {
                $Gerty::log->error
                    ($var . ' is not defined in mix-in module ' . $module);
                next;
            }

            $Gerty::log->debug
                ($self->sysname . ': ' .
                 'loaded Netconf mix-in module "' . $module . '"');
            
            while( my($action, $sub) = each %{$handlers} )
            {
                if( defined( $self->{'mixin_actions'}{$action} ) )
                {
                    $Gerty::log->error
                        ('Action ' . $action . ' is defined in two mix-in ' .
                         'modules: ' . $module . ' and ' .
                         $self->{'mixin_origin'}{$action});
                }
                else
                {
                    $self->{'mixin_actions'}{$action} = $sub;
                    $self->{'mixin_origin'}{$action} = $module;
                    $Gerty::log->debug
                        ($self->sysname . ': ' .
                         'registered Netconf action "' . $action .
                         '" from mix-in "' . $module . '"');
                }                
            }

            $var = "\$" . $module . '::client_capabilities';
            my $client_caps = eval($var);
            if( $@ )
            {
                $Gerty::log->error
                    ('Error accessing ' . $var . ' : ' . $@);
                next;
            }

            if( defined($client_caps) )
            {
                foreach my $cap (@{$client_caps})
                {
                    $self->{'client_capability'}{$cap} = 1;
                    if( $Gerty::debug_level >= 2 )
                    {
                        $Gerty::log->debug
                            ($self->sysname . ': NETCONF client capability ' .
                             $cap);
                    }
                }
            }
        }
    }

    {
        my $doc = XML::LibXML->createDocument( "1.0", "UTF-8" );
        my $root = $doc->createElement('hello');
        $doc->setDocumentElement($root);
        my $caps_node = $doc->createElement('capabilities');
        $root->appendChild($caps_node);

        foreach my $cap (sort keys %{$self->{'client_capability'}})
        {
            my $node = $doc->createElement('capability');
            $node->appendText($cap);
            $caps_node->appendChild($node);
        }

        $self->send_doc($doc);
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



sub supported_actions
{
    my $self = shift;

    my $ret = [];
    push( @{$ret}, keys %{$self->{'mixin_actions'}} );
    return $ret;
}



sub do_action
{
    my $self = shift;    
    my $action = shift;

    if( not defined($self->{'mixin_actions'}{$action}) )
    {
        my $err = 'Unsupported action: ' . $action .
            ' in Gerty::Netconf::ActionHandler';
        $Gerty::log->error($err);
        return {'success' => 0, 'content' => $err};
    }
    
    return &{$self->{'mixin_actions'}{$action}}($self, $action);
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
    
    $self->send_string($request->doc->toString(2));

    my $reply_string = $self->receive_as_string();
    if( not defined($reply_string) )
    {
        $Gerty::log->error('Failed to receive RPC reply');
        return 0;
    }

    my $reply = new Gerty::Netconf::RPCReply( $reply_string );
    if( not defined($reply) )
    {
        $Gerty::log->error('Failed to parse RPC reply XML');
        return 0;
    }

    if( $reply->is_error() )
    {
        $Gerty::log->error('RPC error');
        $self->{'error_details'} = $reply->error_details();
        return 0;
    }

    $self->{'result'} = $reply->doc;

    # TODO: check that message-id in reply matches the one in request
        
    $self->{'message-id'}++;

    return 1;
}



sub send_string
{
    my $self = shift;
    my $msg = shift;
    my $acc = $self->device->{'ACCESS_HANDLER'};
    $acc->send_netconf_message($msg);
}


sub send_doc
{
    my $self = shift;
    my $doc = shift;    
    $self->send_string($doc->toString(2));
}




    

        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
