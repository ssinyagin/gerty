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

# Gerty command that installs a plugin

package Gerty::CLI::install_plugin;

our $cli_registry_entry = {
    'opts' => {},
    'arguments' => 1,
    'execute' => \&execute,
    'help' =>
        "Usage: \n" .
        "  gerty install_plugin DIR\n" .
        "The command installs a Gerty plugin (you need write \n" .
        "permissions for Gerty library directories\n",
    };



sub execute
{
    my $plugindir = shift;
    $Gerty::log->critical('This command is not yet impplemented');
}



1;
