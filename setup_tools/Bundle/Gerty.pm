#  Perl bundle for Gerty pre-requisites
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
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.



package Bundle::Gerty;

$VERSION = '1.00';

__END__

=head1 NAME

Bundle::Gerty - A bundle to install Gerty pre-requisite modules

=head1 SYNOPSIS

C<perl -I `pwd`/setup_tools -MCPAN -e 'install Bundle::Gerty'>


=head1 CONTENTS

Config::Tiny

Config::Any

Log::Handler

Expect

Date::Format

XML::LibXML 1.61

=head1 AUTHOR

Stanislav Sinyagin E<lt>F<ssinyagin@k-open.com>E<gt>

=cut
