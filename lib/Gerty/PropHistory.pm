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
# The module can be used directly as a post-processing handler

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

use Gerty::DBLink;
use Date::Format;
use Digest::MD5 qw(md5_hex);
    
sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);
                    
    return $self;
}


sub set_dblink
{
    my $self = shift;
    my $dblink = shift;
    $self->{'dblink'} = $dblink;
    $self->{'cache'} = {};
}

sub clear_dblink
{
    my $self = shift;
    delete $self->{'dblink'};
    delete $self->{'cache'};
}

sub dbh {return shift->{'dblink'}->dbh()}


# Set a property
# Expected a hashref with the following keys:
# 'category', 'aid', 'property', 'value'

sub set_property
{
    my $self = shift;
    my $args = shift;

    my $dbh = $self->dbh;

    # Chop off leading and trailing space
    my $value = $args->{'value'};
    $value =~ s/^\s+//o;
    $value =~ s/\s+$//o;

    my $category = $args->{'category'};

    # Check and fill the cache if needed    
    if( not defined($self->{'cache'}{$category}) )
    {
        my $sth = $dbh->prepare
            ('SELECT AID_NAME, PROP_NAME, PROP_VALUE ' .
             'FROM PROP_VALUES ' .
             'WHERE DEVICE_SYSNAME=? AND PROP_CATEGORY=?');
        $sth->execute($self->sysname, $category);
        
        while(my $row = $sth->fetchrow_arrayref() )
        {
            $self->{'cache'}{$category}{$row->[0]}{$row->[1]} = $row->[2];
        }
    }
        
    my $oldval =
        $self->{'cache'}{$category}{$args->{'aid'}}{$args->{'property'}};
    
    if( defined($oldval) and ($oldval eq $value) )
    {
        # the value has not changed, do nothing
        $dbh->commit();
        return;
    }

    $self->{'cache'}{$category}{$args->{'aid'}}{$args->{'property'}} = $value;
    
    my $propid = $self->propid($args);        
    my $where_cond = ' PROPIDMD5=\'' . $propid  . '\'';

    # screen the single quotes
    $value =~ s/\'/\\\'/go;
    
    my $now = $self->{'dblink'}->sql_unixtime_string(time());
    my $values =
        '\'' . $propid . '\', ' .
        '\'' . $self->sysname . '\', ' .
        '\'' . $category . '\',' .
        '\'' . $args->{'aid'} . '\',' .
        '\'' . $args->{'property'} . '\',' .
        '\'' . $value . '\',' .
        $now;
    
    if( defined($oldval) )
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
                 'SET ARCHIVED_TS=' . $now . ' ' .
                 'WHERE ' .
                 $where_cond . ' AND ARCHIVED_TS IS NULL');
        }
        
        $dbh->do
            ('UPDATE PROP_VALUES ' .
             'SET ' .
             ' PROP_VALUE=\'' . $value . '\', ' .
             ' MODIFIED_TS=' . $now . ' ' .
             'WHERE ' . $where_cond);
    }
    else
    {
        $dbh->do
            ('INSERT INTO PROP_VALUES ' .
             ' (PROPIDMD5, DEVICE_SYSNAME, PROP_CATEGORY, ' .
             '  AID_NAME, PROP_NAME, ' .
             '  PROP_VALUE, MODIFIED_TS) ' .
             'VALUES(' . $values . ')');
    }

    # start a new entry in the history table
    
    $dbh->do
        ('INSERT INTO PROP_HISTORY ' .
         ' (PROPIDMD5, DEVICE_SYSNAME, PROP_CATEGORY, AID_NAME, PROP_NAME, ' .
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

    my $propid = $self->propid($args);        
    my $where_cond = ' PROPIDMD5=\'' . $propid  . '\'';

    # find the latest history entry and update it
            
    my $rh = $dbh->selectrow_arrayref
        ('SELECT ADDED_TS ' .
         'FROM PROP_HISTORY ' .
         'WHERE ' .
         $where_cond . ' AND ARCHIVED_TS IS NULL');
    
    if( defined($rh) )
    {
        my $now = $self->{'dblink'}->sql_unixtime_string(time());
        $dbh->do
            ('UPDATE PROP_HISTORY ' .
             'SET ARCHIVED_TS=' . $now . ' ' .
             'WHERE ' .
             $where_cond . ' AND ARCHIVED_TS IS NULL');

        # there was an arcbive entry, so likely the
        # values entry exists as well

        $dbh->do
            ('DELETE FROM PROP_VALUES ' .
             'WHERE ' . $where_cond);

        delete
            $self->{'cache'}{$args->{'category'}}{
                $args->{'aid'}}{$args->{'property'}};
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

    my $category = $args->{'category'};
    
    if( defined($self->{'cache'}{$category}) )
    {
        return [keys %{$self->{'cache'}{$category}}];
    }

    my $ret = [];

    my $rows = $self->dbh->selectall_arrayref
        ('SELECT DISTINCT AID_NAME ' .
         'FROM PROP_VALUES ' .
         'WHERE ' .
         ' DEVICE_SYSNAME=\'' . $self->sysname . '\' AND ' .
         ' PROP_CATEGORY=\'' . $category . '\'');
    
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

    my $category = $args->{'category'};
    my $aid = $args->{'aid'};
    
    if( defined($self->{'cache'}{$category}{$aid}) )
    {
        return [keys %{$self->{'cache'}{$category}{$aid}}];
    }
    
    my $ret = [];
            
    my $rows = $self->dbh->selectall_arrayref
        ('SELECT PROP_NAME ' .
         'FROM PROP_VALUES ' .
         'WHERE ' .
         ' DEVICE_SYSNAME=\'' . $self->sysname . '\' AND ' .
         ' PROP_CATEGORY=\'' . $category . '\' AND ' .
         ' AID_NAME=\'' . $aid . '\'');
    
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
    
    delete $self->{'cache'}{$args->{'category'}}{$args->{'aid'}};
}


# Post-processing handler. Take the raw data and interpret it as a
# category->aid->property hash

sub process_result
{
    my $self = shift;    
    my $action = shift;
    my $result = shift;

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

    if( $self->device_attr($action . '.update-props') )
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
            $self->set_dblink($dblink);
            
            my $devgroups =
                $self->device_attr('prophistory.device-groups');
            if( defined($devgroups) )
            {
                # set the device group membership
                my $category = 'device_group';
                my %member;
                foreach my $group (split(/\s*,\s*/, $devgroups))
                {
                    $member{$group} = 1;
                    
                    $self->set_property
                        ({'category' => $category,
                          'aid'      => $group,
                          'property' => 'member',
                          'value'    => 1});
                }

                # clean up the properties if the device is removed from groups
                my $aids =
                    $self->get_all_aid_names({'category' =>  $category});
                foreach my $aid (@{$aids})
                {
                    if( not $member{$aid} )
                    {
                        $self->delete_aid
                            ({'category' => $category,
                              'aid'      => $aid});
                    }
                }
            }

            while( my ($category, $cat_data) = each %{$result->{'rawdata'}} )
            {
                # Update properties from raw data
                foreach my $aid ( keys %{$cat_data} )
                {
                    foreach my $prop ( keys %{$cat_data->{$aid}} )
                    {
                        if( defined($cat_data->{$aid}{$prop}) )
                        {
                            $self->set_property
                                ({'category' => $category,
                                  'aid'      => $aid,
                                  'property' => $prop,
                                  'value'    => $cat_data->{$aid}{$prop}});
                        }
                    }

                    # Delete properties which are no longer in the raw data
                    my $props = $self->get_all_property_names
                        ({'category' => $category,
                          'aid'      => $aid});
                    foreach my $prop (@{$props})
                    {
                        if( not defined($cat_data->{$aid}{$prop}) )
                        {
                            $self->delete_property
                                ({'category' => $category,
                                  'aid'      => $aid,
                                  'property' => $prop});
                        }
                    }
                }

                # Delete AIDs which are no longer in raw data
                my $aids =
                    $self->get_all_aid_names({'category' =>  $category});
                foreach my $aid (@{$aids})
                {
                    if( not defined($cat_data->{$aid}) )
                    {
                        $self->delete_aid
                            ({'category' => $category,
                              'aid'      => $aid});
                    }
                }
            }
            
            $dblink->disconnect();
            $self->clear_dblink();
        }
        else
        {
            $self->clear_dblink();
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
             'handler, but the attribute "' . $action . '.update-props" ' .
             'is not set to a true value');
    }
}


# Return an MD5 hash string
# Expected a hashref with the following keys:
# 'category', 'aid', 'property'

sub propid
{
    my $self = shift;
    my $args = shift;

    return md5_hex($self->sysname . ':' .
                   $args->{'category'} . ':' .
                   $args->{'aid'} . ':' .
                   $args->{'property'});
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
