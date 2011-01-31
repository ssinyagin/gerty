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

    foreach my $action (keys %{$processors})
    {
        if( not defined($self->{'action_processors'}{$action}) )
        {
            $self->{'action_processors'}{$action} = [];
        }

        push( @{$self->{'action_processors'}{$action}},
              @{$processors->{$action}} );
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
