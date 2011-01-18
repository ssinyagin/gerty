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

# RDBMS interface for Gerty handlers


package Gerty::DBLink;

use base qw(Gerty::HandlerBase);

use strict;
use warnings;

use DBI;

    
sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    if( not defined $options->{'dblink'} )
    {
        $Gerty::log->critical
            ('"dblink" is not provided to Gerty::DBLink->new() ' .
             'for device: ' . $self->sysname);
        return undef;
    }

    $self->{'dblink'} = $options->{'dblink'};
                
    foreach my $param ('dsn', 'username', 'password')
    {
        my $attr = $self->{'dblink'} . '.' . $param;        
        my $val = $self->device_attr($attr);
        if( not defined($val) )
        {
            $Gerty::log->critical
                ('Cannot initialize DBLink: attribute "' . $attr  .
                 '" is undefined for device: ' . $self->sysname);
            return undef;            
        }
        $self->{$param} = $val;
    }
    
    return $self;
}


sub dbh {return shift->{'dbh'}}


sub connect
{
    my $self = shift;    

    if( defined($self->dbh) )
    {
        $self->dbh->disconnect();
    }

    my $dbi_args = {
        'AutoCommit' => 0,
        'RaiseError' => 0,
        'PrintError' => 1,
    };
    
    my $dbh = DBI->connect( $self->{'dsn'},
                            $self->{'username'},
                            $self->{'password'},
                            $dbi_args );

    if( not defined( $dbh ) )
    {
        $Gerty::log->error
            ('DBLink failed to connect to the database "'.
             $self->{'dsn'} . '" for device "' . $self->sysname .
             '". Error message: ' . $dbh->errstr);
        return undef;
    }

    $self->{'dbh'} = $dbh;
    return $dbh;
}



sub disconnect
{
    my $self = shift;
    
    if( defined($self->{'dbh'}) )
    {
        $self->{'dbh'}->disconnect();
        $self->{'dbh'} = undef;
    }
}


             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
