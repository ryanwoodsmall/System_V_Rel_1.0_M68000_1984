/*	@(#)getchar.c	2.1 	*/
/*	3.0 SID #	1.2	*/
/*LINTLIBRARY*/
/*
 * A subroutine version of the macro getchar.
 */
#include <stdio.h>
#undef getchar

int
getchar()
{
	return(getc(stdin));
}
