# This script requires "pandoc" utility, which is usually available as a
# package for major OSes


HTMLDIR=$1

if [ x$HTMLDIR = x ]; then
    echo Usage: $0 DIR 1>&2
    exit 1
fi

if [ ! -d $HTMLDIR ]; then
    echo No such directory: $HTMLDIR 1>&2
    exit 1
fi

IDX=$HTMLDIR/index.html

echo '<HTML><TITLE>Gerty software documentation</TITLE>' >$IDX
echo '<BODY><OL>' >>$IDX

for f in `dirname $0`/doc/*.markdown; do
    src=`basename $f`
    dst=`echo $src | sed -e 's,\.markdown,.html,'`
    pandoc -s -f markdown -t html -o $HTMLDIR/$dst $f
    echo '<LI><A HREF="'$dst'">'$dst'</A></LI>' >>$IDX
done

echo '</OL></BODY></HTML>' >>$IDX




