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

# Gerty command that executes a job

package Gerty::Runcmd::run;

$Gerty::cmd_registry{'run'} = {
    'opts' => {},
    'arguments' => 1,
    'execute' => \&execute,
    'help' =>
        "Usage: \n" .
        "  gerty run [options] JOB.ini\n" .
        "The command executes the Gerty job in accordance with the \n" .
        "job definition file.\n",
    };



sub execute
{
    my $jobfile = shift;
    $Gerty::log->info('Starting Gerty job: ' . $jobfile);

    if( not -r $jobfile )
    {
        $Gerty::log->critical('No such file or directory: ' . $jobfile);
        return 0;
    }

    return 1;
}


1;
