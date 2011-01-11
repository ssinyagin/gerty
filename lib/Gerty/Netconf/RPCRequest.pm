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

#  NETCONF XML RPC abstraction (RFC4741)


package Gerty::Netconf::RPCRequest;

use strict;
use warnings;

use XML::LibXML;


sub new
{
    my $class = shift;
    my $attrs = shift;
    my $self = {};
    bless $self, $class;

    my $doc = XML::LibXML->createDocument( "1.0", "UTF-8" );
    my $root = $doc->createElement('rpc');
    $doc->setDocumentElement($root);

    $self->{'doc'} = $doc;
    $self->{'root'} = $root;

    # Pass <rpc> element attributes, such as xmlns
    if( ref($attrs) )
    {
        foreach my $attr (sort keys %{$attrs})
        {
            $self->root->setAttribute($attr, $attrs->{$attr});
        }
    }
    return $self;
}


sub doc {return shift->{'doc'}}
sub root {return shift->{'root'}}
sub method {return shift->{'method'}}



sub set_message_id
{
    my $self = shift;
    my $msgid = shift;
    $self->root->setAttribute('message-id', $msgid);
}


sub set_method
{
    my $self = shift;
    my $method = shift;
    my $attrs = shift;

    if( defined($self->method) )
    {
        $Gerty::log->critical('Gerty::Netconf::RPCRequest: method is ' .
                              'set twice (' . $self->method . ', ' . $method .
                              ')');
    }

    my $node = $self->doc->createElement($method);
    if( ref($attrs) )
    {
        foreach my $attr (sort keys %{$attrs})
        {
            $node->setAttribute($attr, $attrs->{$attr});
        }
    }

    $self->{'method'} = $node;    
    $self->root->appendChild($node);
    
    return $node;
}






        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
