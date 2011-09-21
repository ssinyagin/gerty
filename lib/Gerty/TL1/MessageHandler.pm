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

# Expect logic for TL1 communication
# This object class is supposed to be inherited by a relevant transport module.

package Gerty::TL1::MessageHandler;

use base qw(Gerty::HandlerBase);

use strict;
use warnings;
use Expect qw(exp_continue);
use Date::Format;




sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    # Fetch mandatory attributes
    
    foreach my $attr
        ('tl1.timeout',
         'tl1.log-dir', 'tl1.log-enabled',
         'tl1.logfile-timeformat')
    {
        my $val = $self->device_attr($attr);
        if( not defined($val) )           
        {
            $Gerty::log->error
                ('Missing mandatory attribute "' .
                 $attr . '" for device: ' . $self->sysname);
            return undef;
        }
        $self->{'attr'}{$attr} = $val;        
    }

    # Fetch mandatory credentials
    
    foreach my $attr ('tl1.auth-username', 'tl1.auth-password')
    {
        my $val = $self->device_credentials_attr($attr);
        if( not defined($val) )
        {
            $Gerty::log->error
                ('Missing mandatory credentials attribute "' .
                 $attr . '" for device: ' .
                 $self->sysname);
            return undef;
        }
        else
        {
            $self->{'attr'}{$attr} = $val;
        }       
    }

    
    $self->{'ctag'} = 100;
    
    return $self;
}



sub close
{
    my $self = shift;

    if( defined($self->expect) )
    {
        $self->logout();
        $self->expect()->hard_close();
        undef $self->{'expect'};
    }
}


sub login
{
    my $self = shift;

    my $result = $self->tl1_command
        ({'cmd' => 'ACT-USER',
          'aid' => $self->{'attr'}{'tl1.auth-username'},
          'params' => $self->{'attr'}{'tl1.auth-password'}});

    return $result->{'success'};
}


sub logout
{
    my $self = shift;

    my $result = $self->tl1_command
        ({'cmd' => 'CANC-USER',
          'aid' => $self->{'attr'}{'tl1.auth-username'}});

    return $result->{'success'};
}



              


# Creates an Expect object and initializes logging
sub _open_expect
{
    my $self = shift;
    my $fh = shift;
    
    my $exp;

    if( defined($fh) )
    {
        $exp = Expect->exp_init($fh);
    }
    else
    {
        $exp = new Expect();
    }
    
    $exp->raw_pty(1);
    
    if( not $Gerty::expect_debug )
    {
        $exp->log_stdout(0);
    }
    
    if( $self->{'attr'}{'tl1.log-enabled'} )
    {
        my $logdir = $self->{'attr'}{'tl1.log-dir'};
        if( length($logdir) > 0 )
        {
            if( not -d $logdir )
            {
                $Gerty::log->warning
                    ('The directory ' . $logdir .
                     ' is specified as tl1.log-dir ' .
                     ' for ' . $self->sysname . ' does not exist ');
            }
            else
            {
                $exp->log_file
                    (sprintf
                     ('%s/%s.%s.log',
                      $logdir, $self->sysname,
                      time2str($self->{'attr'}{'tl1.logfile-timeformat'},
                               time())));
            }
        }
        else
        {
            $Gerty::log->info
                ('tl1.log-dir is not specified for ' . $self->sysname .
                 ', logging is disabled');
        }
    }

    $self->{'expect'} = $exp;
    return $exp;
}


sub expect
{
    my $self = shift;
    return $self->{'expect'};
}


sub timeout
{
    my $self = shift;
    return $self->{'attr'}{'tl1.timeout'};
}




sub tl1_command
{
    my $self = shift;
    my $args = shift;

    my $ret = {'success' => 1, 'response' => []};
    
    my $command = $args->{'cmd'};
    if( not defined($command) )
    {
        my $errmsg = 'Missing TL1 command in send_tl1_command()';
        $Gerty::log->error($errmsg);
        return {'success' => 0, 'error' => $errmsg};
    }

    my $tid = $args->{'tid'};
    $tid = '' unless defined($tid);

    my $aid = $args->{'aid'};
    $aid = '' unless defined($aid);

    my $ctag = $args->{'ctag'};
    if( not defined($ctag) )
    {
        $ctag = $self->{'ctag'};
        $self->{'ctag'}++;
    }

    my $params = $args->{'params'};
    $params = '' unless defined($params);
    
    my $msg = sprintf("%s:%s:%s:%d::%s;",
                      $command,
                      $tid,
                      $aid,
                      $ctag,
                      $params);
    
    if( $Gerty::debug_level >= 2 )
    {
        $Gerty::log->debug
            ($self->sysname . ': sending TL1 command: ' . $msg . "\n");
    }

    my $exp = $self->expect;

    $exp->send($msg . "\n");
    $exp->print_log_file($msg . "\n");

    my $reply_received = 0;
    my $start_time = time();
    while( not $reply_received and time() < $start_time + $self->timeout )
    {
        if( $exp->expect( $self->timeout, ';' ) )
        {
            my $reply = $exp->exp_before();
            my @reply_lines = split(/\r\n/, $reply);
            foreach my $line (@reply_lines)
            {
                if( $line =~ /^[A-Z]/ )
                {
                    if( $line !~ /^M\s+(\d+)\s+([A-Z]+)/ )
                    {
                        # this is not a command response
                        last;
                    }

                    if( $1 != $ctag )
                    {
                        # this is a response to an unknown CTAG
                        last;
                    }

                    $reply_received = 1;
                    my $response_code = $2;
                    
                    if( $response_code ne 'COMPLD' )
                    {
                        $ret->{'success'} = 0;
                        $ret->{'error'} =
                            sprintf('Command %s received response code %s',
                                    $command, $response_code);
                        last;
                    }
                }
                elsif( $reply_received )
                {
                    if( $line =~ /^\s+\"(.+)\"/ )
                    {
                        push( @{$ret->{'response'}}, $1 )
                    }
                }
            }
        }
    }

    if( not $reply_received )
    {
        $ret->{'success'} = 0;
        $ret->{'error'} =
            sprintf('Command %s timed out',  $command);
    }
    
    if( $ret->{'success'} )
    {
        if( $Gerty::debug_level >= 2 )
        {
            $Gerty::log->debug
                ($self->sysname . ": received TL1 response: \n" .
                 join("\n", @{$ret->{'response'}}));
        }
    }
    else
    {
        $Gerty::log->error
                ($self->sysname . ': error executing Tl1 command ' . $command .
                 ': ' . $ret->{'error'});
    }
    
    return $ret;          
}




    

             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
