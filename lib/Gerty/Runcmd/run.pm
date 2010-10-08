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

use strict;
use warnings;
use Expect ();
use Gerty::Job;


my $nofork;
my $expect_debug;
my $limit_expr;

$Gerty::cmd_registry{'run'} = {
    'opts' => {
        'nofork'         => \$nofork,
        'expect_debug=i' => \$expect_debug,
        'limit=s'        => \$limit_expr,
    },
    'arguments' => 1,
    'execute' => \&execute,
    'help' =>
        "Usage: \n" .
        "  gerty run [options] JOB.ini\n" .
        "The command executes the Gerty job in accordance with the \n" .
        "job definition file.\n" .
        "Options: \n" .
        "  --nofork                  disables parallel execution\n" .
        "  --expect_debug=0|1|2|3    [0] Expect debug level\n" .
        "  --limit=RE                regexp to limit device names\n",
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

    my $jobattr = {};
    if( $nofork )
    {
        $jobattr->{'parallel'} = 1;
    }

    if( $expect_debug )
    {
        $Expect::Debug = $expect_debug;
    }
    
    my $job = new Gerty::Job({'file' => $jobfile,
                              'attrs' => $jobattr});
    if( not $job )
    {
        $Gerty::log->critical('Failed to initialize job: ' . $jobfile);
        return 0;
    }

    my $devices = $job->retrieve_devices();
    if( not $devices )
    {
        $Gerty::log->critical('Failed to retrieve devices. Aborting');
        return 0;
    }

    if( defined($limit_expr) )
    {
        study $limit_expr;
        my $newlist = [];
        foreach my $dev (@{$devices})
        {
            if( $dev->{'SYSNAME'} =~ $limit_expr )
            {
                push( @{$newlist}, $dev );
            }
        }

        $devices = $newlist;
    }

    my $devices_initialized = [];
    
    foreach my $dev (@{$devices})
    {
        if( $job->init_access( $dev ) )
        {
            push(@{$devices_initialized}, $dev);
        }
    }
            
    $devices = $devices_initialized;
    my $dev_count = scalar(@{$devices});
    if( $dev_count == 0 )
    {
        $Gerty::log->warning('The list of devices is empty. Exiting');
        return 1;
    }
    else
    {
        $Gerty::log->info('Starting ' . $dev_count . ' device jobs');
    }

    my $nprocesses = $job->attr('parallel');
    if( $nprocesses > $dev_count )
    {
        $nprocesses = $dev_count;
    }

    if( $nprocesses < 2 or $nofork )
    {
        $job->execute( $devices );
    }
    else
    {        
        # Initialize child processes and distribute the devices evenly
        my @proc_dev;
        foreach my $proc (0 .. ($nprocesses-1))
        {
            $proc_dev[$proc] = [];
        }

        my $i = 0;        
        foreach my $dev
            (sort {$a->{'SYSNAME'} cmp $b->{'SYSNAME'}} @{$devices})
        {
            my $proc = $i % $nprocesses;
            push( @{$proc_dev[$proc]}, $dev );
            $i++;
        }

        my %child_pids;
        foreach my $proc (0 .. ($nprocesses-1))
        {
            my $pid = fork();
            if( not defined( $pid ) )
            {
                $Gerty::log->critical('Cannot fork: ' . $!);
                return 0;
            }
            
            if( $pid == 0 )
            {
                # I am the child process. I do my job and exit.
                $Gerty::log->debug
                    ('Forked child process ' . $proc . ' with ' .
                     scalar(@{$proc_dev[$proc]}) . ' devices to process');
                
                $job->execute( $proc_dev[$proc] );
                
                $Gerty::log->debug
                    ('Child process ' . $proc . ' finished');
                exit 0;
            }
            else
            {
                # I am the parent process. I register the child and continue
                $child_pids{$pid} = 1;
            }
        }
    
        # Wait for all child processes to finish
        while( scalar(keys %child_pids) > 0 )
        {
            my $pid = wait();
            if( $pid > 0 )
            {
                delete $child_pids{$pid};
            }
            else
            {
                last;
            }
        }
    }

    $Gerty::log->info('Finished');
    return 1;
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
