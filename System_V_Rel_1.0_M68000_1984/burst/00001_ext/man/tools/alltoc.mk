TOOLS=/m1/packer/work/man/tools
ATMPDIR=/m1/packer/work/man/a_tmp
AMANDIR=/m1/packer/work/man/a_man
TMPDIR=/m1/packer/work/man/u_tmp
MANDIR=/m1/packer/work/man/u_man

if [ "$1" != "-p" ]; then
	P=65	# Small (6" X 9") format typeset
else
	P=108	# Large (8-1/2" X 11") format typeset
fi

# The following ``if'' sequence is dependant upon the directory
# /usr/man/altmp existing and being the parent directory of the
# location of the Administrator's Manual's TOC build.

if [ ! -s $TMPDIR/cattoc ]; then
	echo "User's Manual TOC not present; run: tocrc [-p] all"
	exit 1
elif [ ! -s $ATMPDIR/cattoc ]; then
	echo "Administrator's Manual TOC not present; run: tocrc [-p] all"
	exit 1
fi

cat $TMPDIR/cattoc $ATMPDIR/cattoc > $ATMPDIR/alltoc

ptx -r -t -b $TOOLS/break -f -w $P -i $TOOLS/ignore $ATMPDIR/alltoc $AMANDIR/man0/ptxx
#	@(#)alltoc.mk	1.1	UNIX System V/68
