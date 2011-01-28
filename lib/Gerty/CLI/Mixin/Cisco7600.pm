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

# Command-line actions for Cisco 7600 series routers


package Gerty::CLI::Mixin::Cisco7600;

use strict;
use warnings;
use Expect qw(exp_continue);


# at the moment only a stupid placeholder for testing purpose.
# need to add some more flesh later

our $action_handlers_registry = {
    'get7600something' => \&get7600something,    
};


our $retrieve_action_handlers = \&retrieve_action_handlers;


sub retrieve_action_handlers
{
    my $ahandler = shift;

    return $action_handlers_registry;
}



sub get7600something
{
    my $ahandler = shift;
    my $action = shift;

    $Gerty::log->info('get7600something executed for ' .
                      $ahandler->{'device'}->{'SYSNAME'});
    
    return {'success' => 1, 'content' => 'blah blah'};
}


        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
