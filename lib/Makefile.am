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

#


install-data-local:
	$(mkinstalldirs) $(DESTDIR)$(perllibdir)
	$(FIND) * -type d -print >list.tmp
	for d in `cat list.tmp`; do \
	  $(mkinstalldirs) $(DESTDIR)$(perllibdir)/$$d; done
	$(FIND) * \( -name '*.pm' \) -type f -print >list.tmp
	for f in `cat list.tmp`; do \
	  $(INSTALL_DATA) $$f $(DESTDIR)$(perllibdir)/$$f; done
	$(RM) -f list.tmp


uninstall-local:
	$(FIND) * -depth -type d -print >list.tmp
	for d in `cat list.tmp`; do \
	  $(RM) -f $(DESTDIR)$(perllibdir)/$$d/*.pm; \
	  $(RMDIR) $(DESTDIR)$(perllibdir)/$$d; \
	done
	$(RM) -f list.tmp


dist-hook:
	$(FIND) * -type d -print >list.tmp
	for d in `cat list.tmp`; do \
	  mkdir $(distdir)/$$d; done
	$(FIND) * \( -name '*.pm' \) -type f -print >list.tmp
	for f in `cat list.tmp`; do \
	  cp $$f $(distdir)/$$f; done
	$(RM) -f list.tmp
