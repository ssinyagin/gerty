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

#  Parent class for action handlers which need mix-in loading capability


package Gerty::MixinLoader;

use base qw(Gerty::HandlerBase);

use strict;
use warnings;

sub new
{
    my $class = shift;
    my $options = shift;
    my $self = $class->SUPER::new( $options );    
    return undef unless defined($self);

    return $self;
}


# initialize mix-in modules

sub init_mixins
{
    my $self = shift;
    my $mixins_attr = shift;

    $self->{'mixin_actions'} = {};
    $self->{'mixin_origin'} = {};
    
    my $mixins = $self->device_attr($mixins_attr);
    
    if( defined($mixins) )
    {
        foreach my $module (split(/,/o, $mixins))
        {
            eval(sprintf('require %s', $module));
            if( $@ )
            {
                $Gerty::log->error
                    ('Error loading Perl module ' . $module .
                     ' specified in "' . $mixins_attr . '" for device "' .
                     $self->sysname . '": ' . $@);
                next;
            }
            
            my $var = "\$" . $module . '::retrieve_action_handlers';
            my $retr_handlers = eval($var);
            if( $@ )
            {
                $Gerty::log->error
                    ('Error accessing ' . $var . ' : ' . $@);
                next;
            }

            if( not defined($retr_handlers) )
            {
                $Gerty::log->error
                    ($var . ' is not defined in mix-in module ' . $module);
                next;
            }

            $Gerty::log->debug
                ($self->sysname . ': ' .
                 'loaded mix-in module "' . $module . '"');

            my $handlers = &{$retr_handlers}($self);
            
            while( my($action, $sub) = each %{$handlers} )
            {
                if( defined( $self->{'mixin_actions'}{$action} ) )
                {
                    $Gerty::log->error
                        ('Action ' . $action . ' is defined in two mix-in ' .
                         'modules: ' . $module . ' and ' .
                         $self->{'mixin_origin'}{$action});
                }
                else
                {
                    $self->{'mixin_actions'}{$action} = $sub;
                    $self->{'mixin_origin'}{$action} = $module;
                    $Gerty::log->debug
                        ($self->sysname . ': ' .
                         'registered a handler for action  "' . $action .
                         '" from mix-in "' . $module . '"');
                }                
            }
        }
    }
}



sub supported_actions
{
    my $self = shift;

    my $ret = [];
    push( @{$ret}, keys %{$self->{'mixin_actions'}} );
    return $ret;
}


sub is_mixin_action
{
    my $self = shift;    
    my $action = shift;

    return defined($self->{'mixin_actions'}{$action});
}



sub mixin_origin
{
    my $self = shift;    
    my $action = shift;
    
    return $self->{'mixin_origin'}{$action};
}


sub do_action
{
    my $self = shift;    
    my $action = shift;

    if( not defined($self->{'mixin_actions'}{$action}) )
    {
        my $err = 'Unsupported action: ' . $action; 
        $Gerty::log->error($err);
        return {'success' => 0, 'content' => $err};
    }
    
    return &{$self->{'mixin_actions'}{$action}}($self, $action);
}





    

        
             
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
