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

# RDBMS interface for property history database

# Each property is identified by the following set of strings:
#
#  DEVICE_SYSNAME -- the system name
#  PROP_CATEGORY  -- category, such as system, interface, etc.
#  AID_NAME       -- Access Identifier, such as interface name
#  PROP_NAME      -- property name

package Gerty::PropHistory;

use base qw(Gerty::HandlerBase);

use strict;
use warnings;

use DBI;
use Date::Format;

    
sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    # a Gerty::DBLink object is expected
    if( not defined $options->{'dblink'} )
    {
        $Gerty::log->critical
            ('"dblink" is not provided to Gerty::PropHistory->new() ' .
             'for device: ' . $self->sysname);
        return undef;
    }

    $self->{'dblink'} = $options->{'dblink'};
                    
    return $self;
}

sub dbh {return shift->{'dblink'}->{'dbh'}}


# Set a property
# Expected a hashref with the following keys:
# 'category', 'aid', 'property', 'value'

sub set_property
{
    my $self = shift;
    my $args = shift;

    my $dbh = $self->dbh;

    my $where_cond =
        ' DEVICE_SYSNAME=\'' . $self->sysname . '\' AND ' .
        ' PROP_CATEGORY=\'' . $args->{'category'} . '\' AND ' .
        ' AID_NAME=\'' . $args->{'aid'} . '\' AND ' .
        ' PROP_NAME=\'' . $args->{'property'} . '\' ';
    
    # Check if the old value equals the new one
    
    my $rv = $dbh->selectrow_arrayref
        ('SELECT PROP_VALUE ' .
         'FROM PROP_VALUES ' .
         'WHERE ' . $where_cond);

    if( defined($rv) and ($rv->[0] eq $args->{'value'}) )
    {
        # the value has not changed, do nothing
        $dbh->commit();
        return;
    }

    my $now = $self->{'dblink'}->sql_unixtime_string(time());
    my $values =
        '\'' . $self->sysname . '\', ' .
        '\'' . $args->{'category'} . '\',' .
        '\'' . $args->{'aid'} . '\',' .
        '\'' . $args->{'property'} . '\',' .
        '\'' . $args->{'value'} . '\',' .
        $now;
    
    if( defined($rv) )
    {
        # find the latest history entry and update it
            
        my $rh = $dbh->selectrow_arrayref
            ('SELECT ADDED_TS ' .
             'FROM PROP_HISTORY ' .
             'WHERE ' .
             $where_cond . ' AND ARCHIVED_TS IS NULL');
        
        if( defined($rh) )
        {
            $dbh->do
                ('UPDATE PROP_HISTORY ' .
                 'SET ARCHIVED_TS=' . $now .
                 'WHERE ' .
                 $where_cond . ' AND ARCHIVED_TS IS NULL');
        }
        
        $dbh->do
            ('UPDATE PROP_VALUES ' .
             'SET ' .
             ' PROP_VALUE=\'' . $args->{'value'} . '\', ' .
             ' MODIFIED_TS=' . $now . ' ' .
             'WHERE ' . $where_cond);
    }
    else
    {
        $dbh->do
            ('INSERT INTO PROP_VALUES ' .
             ' (DEVICE_SYSNAME, PROP_CATEGORY, AID_NAME, PROP_NAME, ' .
             '  PROP_VALUE, MODIFIED_TS) ' .
             'VALUES(' . $values . ')');
    }

    # start a new entry in the history table
    
    $dbh->do
        ('INSERT INTO PROP_HISTORY ' .
         ' (DEVICE_SYSNAME, PROP_CATEGORY, AID_NAME, PROP_NAME, ' .
         '  PROP_VALUE, ADDED_TS) ' .
         'VALUES(' . $values . ')');

    $dbh->commit();
}



# Delete a property
# Expected a hashref with the following keys:
# 'category', 'aid', 'property'

sub delete_property
{
    my $self = shift;
    my $args = shift;

    my $dbh = $self->dbh;

    my $where_cond =
        ' DEVICE_SYSNAME=\'' . $self->sysname . '\' AND ' .
        ' PROP_CATEGORY=\'' . $args->{'category'} . '\' AND ' .
        ' AID_NAME=\'' . $args->{'aid'} . '\' AND ' .
        ' PROP_NAME=\'' . $args->{'property'} . '\' ';


    # find the latest history entry and update it
            
    my $rh = $dbh->selectrow_arrayref
        ('SELECT ADDED_TS ' .
         'FROM PROP_HISTORY ' .
         'WHERE ' .
         $where_cond . ' AND ARCHIVED_TS IS NULL');
    
    if( defined($rh) )
    {
        $dbh->do
            ('UPDATE PROP_HISTORY ' .
             'SET ARCHIVED_TS=' . $now .
             'WHERE ' .
             $where_cond . ' AND ARCHIVED_TS IS NULL');

        # there was an arcbive entry, so likely the
        # values entry exists as well

        $dbh->do
            ('DELETE FROM PROP_VALUES' .
             'WHERE ' . $where_cond);
    }
    
    $dbh->commit();
}
    
    
# Find all AID names for a given device and category
# Expected a hashref with the following keys:
# 'category'

sub get_all_aid_names
{
    my $self = shift;
    my $args = shift;

    my $ret = [];
    
    my $rows = $self->dbh->selectall_arrayref
        ('SELECT DISTINCT AID_NAME ' .
         'FROM PROP_VALUES ' .
         'WHERE ' .
         ' DEVICE_SYSNAME=\'' . $self->sysname . '\' AND ' .
         ' PROP_CATEGORY=\'' . $args->{'category'} . '\'');

    foreach my $r (@{$rows})
    {
        push(@{$ret}, $r->[0]);
    }

    $self->dbh->commit();    
    return $ret;
}


# Find all property names for a given device, category and AID
# Expected a hashref with the following keys:
# 'category', 'aid'

sub get_all_property_names
{
    my $self = shift;
    my $args = shift;

    my $ret = [];
    
    my $rows = $self->dbh->selectall_arrayref
        ('SELECT PROP_NAME ' .
         'FROM PROP_VALUES ' .
         'WHERE ' .
         ' DEVICE_SYSNAME=\'' . $self->sysname . '\' AND ' .
         ' PROP_CATEGORY=\'' . $args->{'category'} . '\' AND ' .
         ' AID_NAME=\'' . $args->{'aid'} . '\'');
    
    foreach my $r (@{$rows})
    {
        push(@{$ret}, $r->[0]);
    }

    $self->dbh->commit();    
    return $ret;
}



# Delete all properties for a given device, category and AID
# Expected a hashref with the following keys:
# 'category', 'aid'

sub delete_aid
{
    my $self = shift;
    my $args = shift;

    my $props = $self->get_all_property_names($args);
    
    foreach my $prop (@{$props})
    {
        $self->delete_property({%{$args}, 'property' => $prop});
    }
}

             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
