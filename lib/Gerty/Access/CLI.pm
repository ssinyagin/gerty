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

# Command-line interface wrapper


package Gerty::Access::CLI;

use strict;
use warnings;
use Expect qw(exp_continue);
use Date::Format;


my %has =
    ('expect' => 1);


my %known_access_methods =
    ('ssh' => 1,
     'telnet' => 1);

my %attr_defaults =
    ('cli-ssh-port' => 22,
     'cli-telnet-port' => 23,
     'cli-log-dir' => '',
     'cli-logfile-timeformat' => '%Y%m%H-%H%M%S',
     'cli-timeout' => 15,
     'cli-initial-prompt' => '^.+[\#\>\$]'
     );
    

     
sub new
{
    my $self = {};
    my $class = shift;    
    $self->{'options'} = shift;
    bless $self, $class;

    my $sysname = $self->{'options'}->{'device'}->{'SYSNAME'};
    
    foreach my $opt ('job', 'device')
    {
        if( not defined( $self->{'options'}->{$opt} ) )
        {
            $Gerty::log->critical('Gerty::Access::CLI::new: Missing ' . $opt);
            return undef;
        }
    }

    # Fetch mandatory attributes

    foreach my $attr ('cli-access-method')
    {
        my $val = $self->device_attr($attr);
        if( not defined($val) )
        {
            $Gerty::log->error
                ('Missing mandatory attribute "' . $attr . '" for device: ' .
                 $sysname);
            return undef;
        }
        else
        {
            $self->{'attr'}{$attr} = $val;
        }       
    }

    if( not $known_access_methods{ $self->{'attr'}{'cli-access-method'} } )
    {
        $Gerty::log->error
            ('Unsupported cli-access-method value: "' .
             $self->{'attr'}{'cli-access-method'} . '" for device: ' .
             $sysname);
        return undef;
    }
    
    
    # Fetch mandatory credentials
    
    foreach my $attr ('cli-auth-username', 'cli-auth-password')
    {
        my $val = $self->device_credentials_attr($attr);
        if( not defined($val) )
        {
            $Gerty::log->error
                ('Missing mandatory credentials attribute "' .
                 $attr . '" for device: ' .
                 $sysname);
            return undef;
        }
        else
        {
            $self->{'attr'}{$attr} = $val;
        }       
    }

    # Fetch optional attributes
    
    while( my($attr, $default) = each %attr_defaults )
    {
        my $val = $self->device_attr($attr);
        if( not defined($val) )
        {
            $val = $default;
        }
        $self->{'attr'}{$attr} = $val;        
    }
    return $self;
}


sub has
{
    my $self = shift;
    my $what = shift;
    return $has{$what};
}
    


sub device_attr
{
    my $self = shift;
    my $attr = shift;

    return $self->{'options'}->{'job'}->device_attr
        ( $self->{'options'}->{'device'}, $attr );
}


sub device_credentials_attr
{
    my $self = shift;
    my $attr = shift;

    return $self->{'options'}->{'job'}->device_credentials_attr
        ( $self->{'options'}->{'device'}, $attr );
}



# Returns an Expect object after authentication
sub connect
{
    my $self = shift;

    my $sysname = $self->{'options'}->{'device'}->{'SYSNAME'};
    my $method = $self->{'attr'}{'cli-access-method'};
    my $exp = new Expect();

    my $logdir = $self->{'attr'}{'cli-log-dir'};
    if( length($logdir) > 0 )
    {
        if( not -d $logdir )
        {
            $Gerty::log->warning
                ('The directory ' . $logdir . ' is specified as cli-log-dir ' .
                 ' for ' . $sysname . ' does not exist ');
        }
        else
        {
            $exp->log_file
                (sprintf('%s/%s.%s.log',
                         $logdir, $sysname,
                         time2str($self->{'attr'}{'cli-logfile-timeformat'},
                                  time())));
        }
    }
    else
    {
        $Gerty::log->info
            ('cli-log-dir is not specified for ' . $sysname .
             ', CLI logging is disabled');
    }
            
    my $timeout =  $self->{'attr'}{'cli-timeout'};
    my $prompt = $self->{'attr'}{'cli-initial-prompt'};
    my $ipaddr = $self->{'options'}->{'device'}{'ADDRESS'};
    
    $Gerty::log->debug('Connecting to ' . $ipaddr . ' with ' . $method);

    if( $method eq 'ssh' )
    {
        my @exec_args =
            ($Gerty::external_executables{'ssh'},
             '-o', 'NumberOfPasswordPrompts=1',
             '-p', $self->{'attr'}{'cli-ssh-port'},
             '-l', $self->{'attr'}{'cli-auth-username'},
             $ipaddr);

        if( not $exp->spawn(@exec_args) )
        {
            $Gerty::log->error('Failed spawning command "' .
                               join(' ', @exec_args) . '": ' . $!);
            return undef;
        }
            
        # Handle unknown host and password
        my $password = $self->{'attr'}{'cli-auth-password'};
        my $failure;
        
        if( not defined
            $exp->expect
            ( $timeout,
              ['-re', qr/password:/, sub {$exp->send($password . "\r")}],
              ['-re', $prompt],
              ['timeout', sub {$failure = 'Connection timeout'}] ) or
            defined($failure))
        {
            $Gerty::log->error
                ('Failed logging into ' . $sysname . ': ' . 
                 ($exp->error() ? $exp->error() : $failure));
            $exp->hard_close();
            return undef;
        }
    }
    elsif( $method eq 'telnet' )
    {
        my @exec_args =
            ($Gerty::external_executables{'telnet'},
             $self->{'options'}->{'device'}{'ADDRESS'},
             $self->{'attr'}{'cli-telnet-port'});
        
        if( not $exp->spawn(@exec_args) )
        {
            $Gerty::log->error('Failed spawning command "' .
                               join(' ', @exec_args) . '": ' . $!);
            return undef;
        }
            
        # Log into the remote system
        my $login = $self->{'attr'}{'cli-auth-username'};
        my $password = $self->{'attr'}{'cli-auth-password'};
        my $failure;
        
        if( not defined
            $exp->expect
            ( $timeout,
              ['-re', qr/login:/i, sub {
                  $exp->send($login . "\r"); exp_continue;}],
              ['-re', qr/name:/i, sub {
                  $exp->send($login . "\r"); exp_continue;}],
              ['-re', qr/password:/i, sub {
                  $exp->send($password . "\r"); exp_continue;}],
              ['-re', qr/incorrect/i, sub {$failure = 'Access denied'}],
              ['-re', qr/denied/i, sub {$failure = 'Access denied'}],
              ['-re', qr/fail/i, sub {$failure = 'Access denied'}],
              ['timeout', sub {$failure = 'Connection timeout'}],
              ['-re', $prompt] ) )
        {
            $Gerty::log->error
                ('Failed connecting to ' . $sysname . ': ' . 
                 $exp->error() . ' ' . $exp->before());            
            $exp->hard_close();
            return undef;
        }

        if( $failure )
        {
            $Gerty::log->error
                ('Login failure for ' . $sysname . ': ' .  $failure);
            $exp->hard_close();
            return undef;
        }                
    }

    $Gerty::log->debug('Logged in at ' . $ipaddr);
    $self->{'expect'} = $exp;
    return $exp;
}


sub close
{
    my $self = shift;

    if( defined($self->{'expect'}) )
    {
        $self->{'expect'}->hard_close();
        undef $self->{'expect'};
    }
}


sub expect
{
    my $self = shift;

    return $self->{'expect'};
}


    
        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
