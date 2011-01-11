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


package Gerty::Netconf::RPCReply;

use strict;
use warnings;

use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::Hash::LX ':inject';


sub new
{
    my $class = shift;
    my $string = shift;
    my $self = {};
    bless $self, $class;

    my $parser = new XML::LibXML;
    $self->{'doc'} = $parser->parse_string($string);
    $self->{'xpc'} = new XML::LibXML::XPathContext($self->doc);
    
    return $self;
}


sub doc {return shift->{'doc'}}
sub xpc {return shift->{'xpc'}}


sub is_error
{
    my $self = shift;
    
    if( not defined($self->{'is_error'}) )
    {
        my @nodes = $self->xpc->findnodes('//rpc-error');
        if( scalar(@nodes) > 0 )
        {
            $self->{'is_error'} = 1;
            $self->{'error_node'} = $nodes[0];
        }
        else
        {
            $self->{'is_error'} = 0;
        }
    }
    
    return $self->{'is_error'};
}


sub error_details
{
    my $self = shift;

    if( $self->is_error() )
    {
        return $self->{'error_node'}->toHash();
    }
}


        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
