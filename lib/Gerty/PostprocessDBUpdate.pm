#  Copyright (C) 2011  Stanislav Sinyagin
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

# Parent class for action postprocessing modules where SQL database update
# is required


package Gerty::PostprocessDBUpdate;

use base qw(Gerty::HandlerBase);

use strict;
use warnings;

use Gerty::DBLink;
use Date::Format;

    
sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    $self->{'action_processors'} = {};
    
    return $self;
}


# Expects a hash reference: {'action name' => [sub, ...]}
sub register_action_processors
{
    my $self = shift;
    my $processors = shift;

    while(my ($action, $handlers) = each %{$processors})
    {
        if( not defined($self->{'action_processors'}{$action}) )
        {
            $self->{'action_processors'}{$action} = [];
        }

        push( @{$self->{'action_processors'}{$action}}, @{$handlers} );
    }
}
    

# Expects a hash reference. If a column is of SQL datetime type, then:
#  {'action name' => [{table=>x, sysname_column=>y, date_column=>z}, ...]}
# If a column is a UNIX timestamp, then additional key is required:
#  unix_timestamp => 1
sub register_action_dbcleanup
{
    my $self = shift;
    my $entries = shift;

    while(my ($action, $tables) = each %{$entries})
    {
        if( not defined($self->{'action_dbcleanup'}{$action}) )
        {
            $self->{'action_dbcleanup'}{$action} = [];
        }

        foreach my $tabledef (@{$tables})
        {
            my $ok = 1;
            foreach my $param ('table', 'sysname_column', 'date_column')
            {
                if( not defined($tabledef->{$param}) )
                {
                    $Gerty::log->critical
                        ($param . ' is not specified in ' .
                         'register_action_dbcleanup() for action ' . $action .
                         ' for device ' . $self->sysname);
                    $ok = 0;
                }
            }

            if( $ok )
            {
                push( @{$self->{'action_dbcleanup'}{$action}}, $tabledef );
            }
        }
    }
}


sub process_result
{
    my $self = shift;    
    my $action = shift;
    my $result = shift;

    if( defined($self->{'action_processors'}{$action}) )
    {
        if( not $result->{'has_rawdata'} )
        {
            $Gerty::log->error
                ('Action result does not contain raw data for the action ' .
                 $action . ' for device: ' .
                 $self->sysname);
            return;
        }
        
        if( not defined($result->{'rawdata'}) )
        {
            $Gerty::log->error
                ('Error in action post-processing' .
                 'Raw data is undefined in results of action "' .
                 $action . '" for device: ' . $self->sysname );
            return;
        }
        
        if( $self->device_attr($action . '.update-db') )
        {
            my $dblink_attr = $action . '.postprocess.dblink';
            my $dblink_name = $self->device_attr($dblink_attr);
            
            if( not defined($dblink_name) )
            {
                $Gerty::log->error
                    ('Missing the attribute "' . $dblink_attr .
                     '" required for postprocessing. Skipping the ' .
                     'prostprocessing step for the action ' .
                     $action . ' for device: ' .
                     $self->sysname);
                return;
            }
            
            $Gerty::log->debug('Initializing DBLink named "' . $dblink_name .
                               '" required for action postprocessing ' .
                               'for the action "' . $action);
            
            my $dblink = new Gerty::DBLink
                ({'job' => $self->job, 'device' => $self->device,
                  'dblink' => $dblink_name});
            if( not defined($dblink) )
            {
                $Gerty::log->error
                    ('Failed to initialize database connection. ' .
                     'Skipping the prostprocessing step for the action ' .
                     $action . ' for device: ' . $self->sysname);
                return;
            }
            
            if( $dblink->connect() )
            {
                foreach my $proc (@{$self->{'action_processors'}{$action}})
                {
                    &{$proc}($self, $action, $result, $dblink);
                }

                if( defined($self->{'action_dbcleanup'}{$action}) )
                {
                    # clean up old data
                    my $keep_days =
                        $self->device_attr($action . '.keep-days');
                    if( not defined($keep_days) )
                    {
                        $keep_days =
                            $self->device_attr($dblink->name . '.keep-days');
                    }

                    if( not defined($keep_days) )
                    {
                        $keep_days = 732;
                        $Gerty::log->warn
                            ('Neither ' . $action . '.keep-days nor ' .
                             $dblink->name . '.keep-days are defined for ' .
                             $self->sysname . '. Falling back to ' .
                             $keep_days . ' days ');
                    }

                    my $upto_date = time() - $keep_days*86400;
                    
                    foreach my $tabledef
                        (@{$self->{'action_dbcleanup'}{$action}})
                    {
                        my $d = $tabledef->{'unix_timestamp'} ?
                            $upto_date :
                            $dblink->sql_unixtime_string($upto_date);
                        
                        my $where =
                            ' WHERE ' . $tabledef->{'date_column'} . '<' .
                            $d . ' AND ' .
                            $tabledef->{'sysname_column'} . '=\'' .
                            $self->sysname . '\'';
                        
                        $Gerty::log->debug
                            ('Deleting old data from ' .
                             $tabledef->{'table'} . $where);
                        
                        $dblink->dbh->do
                            ('DELETE FROM ' . $tabledef->{'table'} . $where);
                        $dblink->dbh->commit();
                    }
                    
                }
                $dblink->disconnect();
            }
            else
            {
                $Gerty::log->error
                    ('Failed to connect to the database. ' .
                     'Skipping the prostprocessing step for the action ' .
                     $action . ' for device: ' . $self->sysname);
                return;
            }
        }
        else
        {
            $Gerty::log->warn
                ('Action "' . $action . '" specifies a postprocessing ' .
                 'handler, but the attribute "' . $action . '.update-db" ' .
                 'is not set to a true value');
        }
    }
    else
    {
        $Gerty::log->warn
            ('Action "' . $action . '" specifies a DBLink postprocessing ' .
             'handler, but no postprocessor matches the action');
    }
}


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
