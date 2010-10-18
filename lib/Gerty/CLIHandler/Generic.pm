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

# Parent class for command-line interface handlers


package Gerty::CLIHandler::Generic;

use strict;
use warnings;
use Expect qw(exp_continue);


     
sub new
{
    my $class = shift;
    my $options = shift;
    my $self = {};
    bless $self, $class;
    
    foreach my $opt ('job', 'device')
    {
        if( not defined( $options->{$opt} ) )
        {
            $Gerty::log->critical($class . '::new - missing ' . $opt);
            return undef;
        }
    }

    $self->{'device'} = $options->{'device'};
    $self->{'job'} = $options->{'job'};
    my $acc = $self->{'device'}->{'ACCESS_HANDLER'};
    if( not $acc->has('expect') )
    {
        $Gerty::log->critical
            ('The access handler for device "' .
             $self->{'device'}->{'SYSNAME'} .
             '" does not provide "expect" method');
        return undef;
    }
    
    $self->{'expect'} = $acc->expect();

    foreach my $attribute
        ( 'admin-mode', 'cli.timeout', 'user-prompt', 'admin-prompt',
          'cli.comment-string' )
    {
        $self->{$attribute} = $self->device_attr($attribute);
    }

    $self->{'prompt'} = $self->{'user-prompt'};
    
    return $self;
}



sub device_attr
{
    my $self = shift;
    my $attr = shift;

    return $self->{'job'}->device_attr($self->{'device'}, $attr);
}



sub exec_command
{
    my $self = shift;
    my $cmd = shift;
    
    my $exp = $self->{'expect'};
    my $sysname = $self->{'device'}->{'SYSNAME'};
    my $failure;

    $Gerty::log->debug('Running a command: "' . $cmd . '" on "' .
                       $sysname . '"');
    
    $exp->send($cmd . "\r");    
    my $result = $exp->expect
        ( $self->{'cli.timeout'},
          ['-re', $self->{'prompt'}],
          ['timeout', sub {$failure = 'Connection timeout'}],
          ['eof', sub {$failure = 'Connection closed'}]);
    
    if( not $result )
    {
        $Gerty::log->error
            ('Could not match the output for ' .
             $sysname . ': ' . $exp->before());            
        return undef;
    }
    
    if( defined($failure) )
    {
        $Gerty::log->error
            ('Failed executing "' . $cmd . '" for ' .
             $sysname . ': ' . $failure);
        return undef;
    }

    my $ret = $exp->before();
    $ret =~ s/\r\n/\n/ogm;

    # outcomment the command from the top if it was echoed
    if( index($ret, $cmd) == 0 and defined($self->{'cli.comment-string'}) )
    {
        $ret = $self->{'cli.comment-string'} . ' ' . $ret;
    }
   
    return $ret;
}



sub supported_actions
{
    my $self = shift;    
    return ['exec-command'];
}


sub do_action
{
    my $self = shift;    
    my $action = shift;

    if( $action ne 'exec-command' )
    {
        $Gerty::log->error('Unsupported action: ' . $action .
                           ' in Gerty::CLIHandler::Generic');
        return undef;
    }

    my $commands = $self->device_attr('exec-command');
    if( not defined($commands) )
    {
        $Gerty::log->error('Missing the required attribute "exec-command" ' .
                           'for device ' . $self->{'device'}->{'SYSNAME'});
        return undef;
    }
    
    my $ret = '';
    foreach my $cmd (split(/\s*,\s*/o, $commands ))
    {
        $ret .= $self->exec_command( $cmd );
    }
    
    return $ret;
}



        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
