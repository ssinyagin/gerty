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

# Job results output handler


package Gerty::Output::File;

use base qw(Gerty::HandlerBase);

use strict;
use warnings;
use IO::File;


     
sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    # Fetch mandatory attributes
    
    foreach my $attr
        ( 'output.default-path',
          'output.failure-suffix', 'output.success-suffix' )
    {
        my $val = $self->device_attr($attr);
        if( not defined($val) )
        {
            $Gerty::log->error('Missing mandatory attribute "' . $attr .
                               '" for device: ' .
                               $self->sysname);
            return undef;
        }

        $self->{$attr} = $val;
    }

    if( not -d $self->{'output.default-path'} )
    {
        $Gerty::log->critical
            ('No such directory: "' . $self->{'output.default-path'} .
             '" specified in output.default-path ' .
             ' for device ' . $self->sysname);
        return undef;
    }


    # Fetch optional attributes

    foreach my $attr
        ( 'output.default-status-path', 'output.delete-on-failure',
          'output.suppress-content' )
    {
        $self->{$attr} = $self->device_attr($attr);
    }

    # Where we save the action status
    
    if( defined($self->{'output.default-status-path'}) )
    {
        if( not -d $self->{'output.default-status-path'} )
        {
            $Gerty::log->critical
                ('No such directory: "' .
                 $self->{'output.default-status-path'} .
                 '" specified in output.default-status-path ' .
                 ' for device ' . $self->sysname);
            return undef;
        }
    }
    else
    {
        # falling back to the default output path
        $self->{'output.default-status-path'} =
            $self->{'output.default-path'};
    }
        
    
    return $self;
}





sub check_action_attributes
{
    my $self = shift;
    my $action = shift;

    # check if action has a dedicated output directory and
    # this directory exists
    
    my $path = $self->device_attr($action . '.path');
    if( defined($path) )
    {
        if( not -d $path )
        {
            $Gerty::log->critical
                ('No such directory: "' . $path .
                 '" specified in ' . $action . '.path' .
                 ' for device ' . $self->sysname);
            return undef;
        }
    }
    else
    {
        $path = $self->{'output.default-path'};
    }

    $self->{'action_outpath'}{$action} = $path;

    # check if action has a dedicated status directory and
    # this directory exists

    $path = $self->device_attr($action . '.status-path');
    if( defined($path) )
    {
        if( not -d $path )
        {
            $Gerty::log->critical
                ('No such directory: "' . $path .
                 '" specified in ' . $action . '.status-path' .
                 ' for device ' . $self->sysname);
            return undef;
        }
    }
    else
    {
        $path = $self->{'output.default-status-path'};
    }

    $self->{'action_statuspath'}{$action} = $path;

    return 1;
}



sub prepare_for_action
{
    my $self = shift;
    my $action = shift;

    # unlink previous success or failure status and optionally the
    # previous output

    $self->{'status_fname_prefix'}{$action} =
        $self->{'action_statuspath'}{$action} . '/' .
        $self->sysname . '.' . $action . '.';
    
    my @unlink_files =
        ($self->{'status_fname_prefix'}{$action} .
         $self->{'output.failure-suffix'},
         
         $self->{'status_fname_prefix'}{$action} .
         $self->{'output.success-suffix'} );
    
    foreach my $fname ( @unlink_files )
    {
        if( -f $fname )
        {
            $Gerty::log->debug('Deleting file: ' . $fname);
            if( not unlink($fname) )
            {
                $Gerty::log->critical
                    ('Cannot remove file ' . $fname . ': ' . $!);
                return undef;
            }
        }
    }

    return 1;
}


# Expects result as a hash with
#   success => boolean
#   content => action result or failure message
#
sub action_finished
{
    my $self = shift;
    my $action = shift;
    my $result = shift;

    if( $result->{'success'} )
    {
        my $out_fname = $self->output_filename($action);
        if( defined($out_fname) )
        { 
            my $fh = new IO::File($out_fname, 'w');
            if( not $fh )
            {
                $Gerty::log->critical
                    ('Cannot open file ' . $out_fname . ' for writing: ' . $!);
                return undef;
            }
            
            $fh->print($result->{'content'});
            $fh->print("\n");
            $fh->close();
            $Gerty::log->info('Wrote action result to ' . $out_fname);
            $result->{'filename'} = $out_fname;
        }
        
        # Create an empty success status file
        
        my $status_fname = $self->{'status_fname_prefix'}{$action} .
            $self->{'output.success-suffix'};
        
        my $fh = new IO::File($status_fname, 'w');
        if( not $fh )
        {
            $Gerty::log->critical
                ('Cannot open file ' .
                 $status_fname . ' for writing: ' . $!);
            return undef;
        }
        $fh->close();
        $Gerty::log->debug('Created success status file: ' . $status_fname);
    }
    else
    {
        if( $self->{'output.delete-on-failure'} )
        {
            my $out_fname = $self->output_filename($action);
            if( defined($out_fname) and -f $out_fname )
            {
                if( not unlink($out_fname) )
                {
                    $Gerty::log->critical
                        ('Cannot remove file ' . $out_fname . ': ' . $!);
                    return undef;
                }
            }
        }

        # Write the failure message into the status file
        my $status_fname = $self->{'status_fname_prefix'}{$action} .
            $self->{'output.failure-suffix'};
        
        my $fh = new IO::File($status_fname, 'w');
        if( not $fh )
        {
            $Gerty::log->critical
                ('Cannot open file ' .
                 $status_fname . ' for writing: ' . $!);
            return undef;
        }
        
        $fh->print($result->{'content'});
        $fh->print("\n");
        $fh->close();
        $Gerty::log->debug('Wrote failure status file: ' . $status_fname);
    }

    return 1;
}
        

    
sub output_filename
{
    my $self = shift;
    my $action = shift;

    my $ret;
    
    if( not $self->{'output.suppress-content'} )
    {
        $ret = 
            $self->{'action_outpath'}{$action} . '/' .
            $self->sysname . '.' . $action;
    }
    
    return $ret;
}
    
        
        



        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
