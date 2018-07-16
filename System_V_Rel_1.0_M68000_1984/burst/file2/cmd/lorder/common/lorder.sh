#	@(#)lorder.sh	2.1	
#	COMMON LORDER
#
#
trap "rm -f /tmp/$$sym?ef; exit" 0 1 2 13 15
case $# in
0)	echo usage: SGSlorder file ...
	exit ;;
1)	case $1 in
	*.o)	set $1 $1
	esac
esac
#	The following sed script is commented here.
#	The egrep pipe insures that we only have lines
#	that contain file names and the external
#	declarations associated with each file.
#	The first two parts of the sed script put the pattern
#	(in this case the file name) into the hold space
#	and creates the "filename filename" lines and
#	writes them out. The first part is for .o files,
#	the second is for .o's in archives.
#	The next 3 sections of code are exactly alike but
#	they handle different external symbols, namely the
#	symbols that are defined in the text section, data section
#	or symbols that are referenced but not defined in this file.
#	A line containing the symbol (from the pattern space) and 
#	the file it is referenced in (from the hold space) is
#	put into the pattern space.
#	If its text or data it is written out to the symbol definition
#	(symdef) file, otherwise it was referenced but not declared
#	in this file so it is written out to the symbol referenced
#	(symref) file.
#
SGSnm -e $* | egrep "\\.o:|\\.o]:|\\|extern" |
	sed '
	/\.o:$/{
		s/://
		s/^.* //
		h
		s/.*/& &/
		p
		d
	}
	/\.o]:$/{
		s/]://
		s/^.*\[//
		h
		s/.*/& &/
		p
		d
	}
	/|\.text/{
		s/ *|.*//
		G
		s/\n/ /
		w '/tmp/$$symdef'
		d
	}
	/|\.data/{
		s/ *|.*//
		G
		s/\n/ /
		w '/tmp/$$symdef'
		d
	}
	s/ *|.*//
	G
	s/\n/ /
	w '/tmp/$$symref'
	d
'
sort /tmp/$$symdef -o /tmp/$$symdef
sort /tmp/$$symref -o /tmp/$$symref
join /tmp/$$symref /tmp/$$symdef | sed 's/[^ ]* *//'
