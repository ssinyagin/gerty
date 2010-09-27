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


AC_INIT([gerty],[1.0.0],[ssinyagin@k-open.com])
AC_PREREQ([2.59])
AC_CONFIG_AUX_DIR(conftools)
AC_CANONICAL_HOST
AM_INIT_AUTOMAKE(1.9)

AC_PATH_PROG(PERL, perl, no)
AC_PATH_PROG(SED, sed, no)
AC_PATH_PROG(RM, rm, no)


AC_ARG_ENABLE(pkgonly,
        [AC_HELP_STRING([--enable-pkgonly],
                        [Skip all checking])])
AC_SUBST(enable_pkgonly)

        
perllibdirs="\'\${perllibdir}\'"

PERLOPTS=
AC_ARG_VAR(PERLINC,  [[] Additional space-separated Perl library paths])
if test ! -z "$PERLINC"; then
   for d in $PERLINC; do
       PERLOPTS="${PERLOPTS} -I${d}"
       perllibdirs=${perllibdirs}"\,\'"${d}"\'"
   done
fi

AC_SUBST(perllibdirs, [${perllibdirs}])


# Check the necessary Perl modules

if test "$enable_pkgonly" != yes; then

   for module in 'Config::Any' 'Log::Handler'
   do
     AC_MSG_CHECKING([presence of $module])
     if ${PERL} ${PERLOPTS} -e 'use '$module 2>/dev/null; then
         AC_MSG_RESULT([Ok])
     else
         AC_MSG_ERROR([Perl cannot find $module]);
     fi
   done
fi


AC_ARG_VAR(mansec_usercmd, [[1] User commands man section])
if test -z "$mansec_usercmd"; then
   mansec_usercmd='1'; fi

AC_ARG_VAR(mansec_misc, [[7] Miscellaneous man section])
if test -z "$mansec_misc"; then
   mansec_misc='7'; fi

AC_ARG_VAR(perllibdir,  [[LIBDIR/gerty/perl] Gerty Perl libraries])
if test -z "$perllibdir"; then
   perllibdir='${libdir}/gerty/perl'; fi

AC_ARG_VAR(pkgdatadir, [[DATADIR/gerty] Gerty data directory])
if test -z "$pkgdatadir"; then
   pkgdatadir='${datadir}/gerty'; fi

AC_ARG_VAR(plugindir, [[PKGDATADIR/plugins] Plugin configuration directory])
if test -z "$plugindir"; then
   plugindir='${pkgdatadir}/plugins'; fi

AC_ARG_VAR(devclassdir, [[PKGDATADIR/devclasses] Device classes directory])
if test -z "$devclassdir"; then
   devclassdir='${pkgdatadir}/devclasses'; fi

   
AC_CONFIG_FILES([Makefile bin/Makefile])
AC_CONFIG_FILES([lib/Makefile])
                                    
AC_CONFIG_FILES([setup_tools/substvars.sh],[chmod +x setup_tools/substvars.sh])

AC_SUBST(VERSION)

# save the configuration variables, so that plugin installers re-use them
VARSAVE=setup_tools/install_variables
echo creating $VARSAVE
${RM} -f $VARSAVE
for VAR in ${ac_subst_vars}; do
    case ${VAR} in
      DEFS | PACKAGE* | INSTALL* | VERSION | ACLOCAL | AUTO* | MAKEINFO |\
      install_sh | AM* | am* | ac* | ECHO* | build* | host* | target* |\
      CYG* | PATH_SEPARATOR | AWK | STRIP | mkdir* |\
      perllibdirs )
      ;;
      *)
        eval 'VAL=${'$VAR'}'
        echo ${VAR}=\'${VAL}\' >>$VARSAVE
      ;;
    esac
done

AC_SUBST(VARSAVE)

AC_OUTPUT
