/*	@(#)d_int.c	2.1 	*/
double d_int(x)
double *x;
{
double floor();

return( (*x>0) ? floor(*x) : -floor(- *x) );
}
