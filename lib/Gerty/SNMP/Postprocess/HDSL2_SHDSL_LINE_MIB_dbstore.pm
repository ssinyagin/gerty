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

# Post-processing module for HDSL2_SHDSL_LINE_MIB data.
# It stores the results in a database.
# See for DB definitions:
#   share/sql/HDSL2_SHDSL_LINE_MIB.mysql.sql 


package Gerty::SNMP::Postprocess::HDSL2_SHDSL_LINE_MIB_dbstore;

use base qw(Gerty::PostprocessDBUpdate);

use strict;
use warnings;

use Date::Parse;

sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    $self->register_action_processors
        ({'hdsl_line_stats' => [ \&process_hdsl_line_stats ]});
    
    $self->register_action_dbcleanup
        ({'hdsl_line_stats' => [
              {
                  'table' => 'HDSL_XTUC_15MIN_COUNTERS',
                  'sysname_column' => 'HOSTNAME',
                  'date_column' => 'MEASURE_TS',
              },
              ]});
    return $self;
}



# Currenrly only 15-minute xtuC counters are stored.
sub process_hdsl_line_stats
{
    my $self = shift;    
    my $action = shift;
    my $result = shift;
    my $dblink = shift;

    my $data = $result->{'rawdata'};

    if( not defined($data->{'hdsl_15min_counters'}) )
    {
        return;
    }
    
    foreach my $intf (keys %{$data->{'hdsl_15min_counters'}})
    {
        my $xtuc_data =
            $data->{'hdsl_15min_counters'}{$intf}{'xtuC'}{'customerSide'};

        next unless defined($xtuc_data);

        foreach my $wirepair (keys %{$xtuc_data})
        {
            my $n_wirepair = $wirepair;
            $n_wirepair =~ s/wirepair//o;
                        
            my $max_stored_ts = 0;
            
            my $r = $dblink->dbh->selectrow_arrayref
                ('SELECT MAX(MEASURE_TS) ' .
                 'FROM HDSL_XTUC_15MIN_COUNTERS ' .
                 'WHERE ' .
                 ' HOSTNAME=\'' . $self->sysname . '\' AND ' .
                 ' INTF_NAME=\'' . $intf . '\' AND ' .
                 ' WIREPAIR=' . $n_wirepair);
            if( defined($r) and defined($r->[0]) )
            {
                $max_stored_ts = str2time($r->[0]);
                if( not defined($max_stored_ts) )
                {
                    $Gerty::log->error
                        ('Cannot interpret SQL date string: "' .
                         $r->[0] . '". Aborting the action postprocessing');
                    return;
                }
            }

            foreach my $timestamp
                (sort {$a<=>$b} keys %{$xtuc_data->{$wirepair}})
            {
                if( $timestamp > $max_stored_ts )
                {
                    my $counters = $xtuc_data->{$wirepair}{$timestamp};
                    my @columns;
                    my @values;
                    
                    foreach my $counter_name
                        ('ES', 'SES', 'CRCA', 'LOSWS', 'UAS')
                    {
                        if( defined($counters->{$counter_name}) )
                        {
                            push(@values, $counters->{$counter_name});
                        }
                        else
                        {
                            push(@values, 'NULL');
                        }
                        push(@columns, $counter_name . '_COUNT');
                    }
                    
                    $dblink->dbh->do
                        ('INSERT INTO HDSL_XTUC_15MIN_COUNTERS ' .
                         ' (HOSTNAME, INTF_NAME, WIREPAIR, MEASURE_TS, ' .
                         join(', ', @columns) . ')' .
                         'VALUES(' .
                         '\'' . $self->sysname . '\', ' .
                         '\'' . $intf . '\', ' .
                         $n_wirepair . ', ' .
                         $dblink->sql_unixtime_string($timestamp) . ', ' .
                         join(',', @values) . ')');
                }
            }
            
            $dblink->dbh->commit();
        }        
    }
}


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
