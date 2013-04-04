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

# Device list driver: imports devices from an RDBMS


package Gerty::DeviceList::DBI;

use strict;
use warnings;

use DBI;
     
sub new
{
    my $self = {};
    my $class = shift;    
    $self->{'listname'} = shift;
    $self->{'options'} = shift;
    bless $self, $class;

    # check mandatory attributes
    foreach my $attr ('source.dsn', 'source.username', 'source.password',
                      'source.query')
    {
        if( not defined($self->{'options'}{$attr}) )
        {
            $Gerty::log->critical
                ('Missing mandatory attribute "' . $attr .
                 '" in device list "' . $self->{'listname'} . '"');
            return undef;
        }        
    }
       
    return $self;
}


sub retrieve_devices
{
    my $self = shift;

    if( lc($self->{'options'}{'source.dsn'}) =~ /^dbi:oracle:/ )
    {
        my $attr = 'source.oracle-home';
        my $val = $self->{'options'}{$attr};
        if( defined($val) )
        {
            $Gerty::log->debug('Setting environment ORACLE_HOME=' . $val);
            $ENV{'ORACLE_HOME'} = $val;
        }
        else
        {
            $Gerty::log->warn
                ($attr . ' is not defined, hopefully DBD::Oracle ' .
                 'will find the libraries by itself');
        }

        my %ora_variables =
            ('tns-admin' => 'TNS_ADMIN',
             'oracle-sid' => 'ORACLE_SID',
             'two-task' => 'TWO_TASK');
        
        while( my($suffix, $env) = each %ora_variables )
        {
            $attr = 'source.' . $suffix;
            $val = $self->{'options'}{$attr};
            if( defined($val) )
            {
                $Gerty::log->debug('Setting environment ' . $env . '=' . $val);
                $ENV{$env} = $val;
            }
        }
    }

    $Gerty::log->debug('Gerty::DeviceList::DBI - processing SQL query: ' .
                       $self->{'options'}{'source.query'});


    my $dbi_args = {
        'AutoCommit' => 0,
        'RaiseError' => 0,
        'PrintError' => 1,
    };
    
    my $dbh = DBI->connect( $self->{'options'}{'source.dsn'},
                            $self->{'options'}{'source.username'},
                            $self->{'options'}{'source.password'},
                            $dbi_args );
    
    if( not defined($dbh) )
    {
        $Gerty::log->error
            ('Gerty::DeviceList::DBI failed to connect to the database "'.
             $self->{'options'}{'source.dsn'} . 
             '". Error message: ' . $dbh->errstr);
        return undef;
    }

    my $sth = $dbh->prepare($self->{'options'}{'source.query'});
    if( not defined($sth) )
    {
        $Gerty::log->error
            ('Gerty::DeviceList::DBI failed to prepare the SQL statement: "'.
             $self->{'options'}{'source.query'} . 
             '". Error message: ' . $dbh->errstr);
        
        $dbh->disconnect();
        return undef;
    }
    
    if( not $sth->execute() )
    {
        $Gerty::log->error
            ('Gerty::DeviceList::DBI failed to execute the SQL statement: "'.
             $self->{'options'}{'source.query'} . 
             '". Error message: ' . $dbh->errstr);
        
        $dbh->disconnect();
        return undef;
    }

    my $ret = [];
    
    while( my $row = $sth->fetchrow_arrayref() )
    {
        # fetchrow_arrayref re-uses the array, so we explicitly copy it
        my $values = [];
        foreach my $col (@{$row})
        {
            push(@{$values}, $col);
        }
        
        push(@{$ret}, {'values' => $values,
                       'source' => $self->{'options'}{'source.dsn'}});
        
    }

    $dbh->commit();
    $dbh->disconnect();

    $Gerty::log->debug('Gerty::DeviceList::DBI - retrieved  ' .
                       scalar(@{$ret}) . ' devices');
    return $ret;
}
  


    



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
