	/*	@(#)opset.c	2.1		*/

/*
 *	UNIX debugger
 *
 *		Instruction printing routines.
 *		MACHINE DEPENDENT.
 *		3B: dis_dot() in "dis" subdirectory;
 *			routines take form 3B disassembler
 */

#include "head.h"

#define SYSTAB struct systab
SYSTAB {
	int	argc;
	char	*sname;
};
extern struct systab systab[];
extern STRING	regname[];
extern STRING	fltimm[];
#ifdef vax
extern int argument [];	/* arguments in case statement - argument[1] is lowest
			 * value case, argument[2] is number of cases
			 * (add one for default).
			 * This array is set by dis_dot.
			 */
extern int caseflg;	/* Flags case statement for disassembly -
			 * set by dis_dot
			 */
#endif

/* printins() all new to disassemble for 3B-20
 *	use code from 3B disassembler -- see "dis" sub-directory
 *	New arguments; change calls in prvar.c also
 *	calls dis_dot(adr,space,fmt)
 */

printins(fmt,idsp)
char fmt;
{
	struct proct *procp;
	long value;
	unsigned short ins;
	union word word;
	long dis_dot();

#if DEBUG > 1
	if(mjmdflag)
		fprintf(FPRT2, "printins(fmt=%c, idsp=%d);\n", fmt,idsp);
#endif
	procp = adrtoprocp(dot);
#if DEBUG > 1
#ifdef FLEXNAMES
	if(mjmdflag > 0)
		fprintf(FPRT2, "dot=%#lx; pname=%s; paddr=%#lx;\n",
					dot, procp->pname, procp->paddr);
#else
	if(mjmdflag > 0)
		fprintf(FPRT2, "dot=%#lx; pname=%.8s; paddr=%#lx;\n",
					dot, procp->pname, procp->paddr);
#endif
#endif
/* On VAX, the first two bytes of a proc are reserved for use with return */
#ifdef  vax
	if (procp->paddr == dot) {
		value = chkget(dot,idsp);
		printf("0x%4.4x", value & 0xffff);
		oincr = 2;
		return;
	}
#endif

	/* dot (the location counter) used (but not changed) by dis_dot() */
	value = dis_dot(dot,idsp,fmt);		/* disassemble instr at dot */
	oincr = value - dot;
	printline();			/* print it out */
	/* when not too difficult, print symbolic info (separately) */
	if(fmt == 'i')
		prassym();
#if DEBUG > 1
	if(mjmdflag)
		fprintf(FPRT2, "dis_dot: dot=%#lx; [oincr=%#x];\n", dot,oincr);
#endif
}

/* prassym(): symbolic printing of disassembled instruction */
static
prassym()
{
	int cnt, regno, jj;
	long value;
	char rnam[9];
	register char *os;
	extern	char	mneu[];		/* in dis/extn.c */

#ifndef u3b
	char *regidx;
	int idxsize = 0;
	int starflg = 0;
	int sign = 0;
	int os_bkup;
#else
#define	os_bkup	0
#endif

	/* depends heavily on format output by disassembler */
	printf("\t[");
	cnt = 0;
	os = mneu;	/* instruction disassembled by dis_dot() */
	while(*os != '\t' && *os != ' ' && *os != '\0')
		os++;		/* skip over instr mneumonic */
	while (*os) {
		while(*os == '\t' || *os == ',' || *os == ' ')
			os++;
#if DEBUG > 1
		if(mjmdflag)
			fprintf(FPRT2, "os=%s;\n", os);
#endif
		value = 0;
		regno = -1;
		rnam[0] = '\0';
#ifdef u3b
		switch (*os) {
		    case '$':
			jj = sscanf(os, "$0x%lx", &value);
			break;
		    case '%':
			jj = sscanf(os, "%%%[^), \t]", rnam);
			break;
		    case '0':
			jj = sscanf(os, "0x%lx(%%%[^)]",
					&value, rnam);
			break;
		    case '&':
			jj = sscanf(os, "&0x%lx", &value);
			break;
		    case '+':
		    case '-':
			while(*os != '\t' && *os != ' ' && *os != '\0')
				os++;
			jj = sscanf(os, " <%x>", &value);
			break;
		    default:
			jj = 0;
			break;
#endif
#ifndef u3b

		os_bkup = 0;
	top:
		switch (*os) {
#endif
#ifdef vax 
		    case '$':
			jj = sscanf(os, "$0x%x", &value);
			break;
#endif
#ifdef m68k
		    case '#':
			jj = sscanf(os, "#$%x", &value);
			break;
#endif
#ifndef u3b

		    case '[':	/* mode 4 (indexed) */
			regidx = os;
			idxsize = 1;
			while (*os++ != ']') idxsize++;
			goto top;

		    case '(':	/* modes 6 and 8 - (Rn) and (Rn)+ */
			jj = sscanf(os, "(%[^)])", rnam);
			break;

		    case '*':	/* deferred addressing */
			starflg = 1;
			os++;
			goto top;

		    case '-':	/* -(Rn) or -number(Rn) */
			os_bkup = 1;
			if (*++os == '(') {
				jj = sscanf(os, "(%[^)])", rnam);
				break;
			}
			sign = 1;
			/* fall through to default case */

		    default:	/* Rn or number(Rn) */
			if (*os <= '9' && *os >= '0') {
				jj = sscanf(os, "%ld", &value);
				if (sign) {
					sign = 0;
					value = -value;
				}
				os_bkup++;
				while (*++os != '(') os_bkup++;
				/* jj > 0 only if number and register read */
				jj *= sscanf(os, "(%[^)]", rnam);
#endif
#ifdef m68k
			} else if ( *os == '$' ) {
				os++;
				os_bkup++;
				jj = sscanf(os, "%x", &value);
				if (sign) {
					sign = 0;
					value = -value;
				}
				os_bkup++;
				while (*++os != '(') os_bkup++;
				/* jj > 0 only if number and register read */
				jj *= sscanf(os, "(%[^)]", rnam);
#endif
#ifndef u3b
			} else if (*os <= 'z' && *os >= 'a') {
				if ((jj = sscanf(os, "%[^, \t]", rnam)) == EOF)
					jj = sscanf(os, "%s", rnam);
			} else
				jj = 0;
			break;
#endif
		}
		if (*rnam)
			for(jj = 0; regname[jj]; jj++)
				if (eqstr(rnam,regname[jj]))
					regno = jj;
		if(jj > 0) {
			if(cnt++ > 0)
				printf(",");
#ifndef u3b

			if (idxsize) {
				while (idxsize--) {
					printf("%c", *regidx++);
				}
			}
			if (starflg) {
				printf("*");
				starflg = 0;
			}
#endif
			jj = psymoff(value, regno, 'i');
		}
		if (jj == (-1)) os -= os_bkup;
		while(*os != '\t' && *os != ',' && *os != ' ' && *os != '\0') {
			if(jj == (-1))
				printf("%c", *os);   /* just as is */
			os++;
		}
	}
	printf("]");

#ifdef vax
	/* Disassemble cases of case instruction (not in mneu because
	 * size of output may be very large).  argument[1] has lower limit
	 * of cases, argument[2]+1 contains the number of cases, both set
	 * by dis_dot().  dot + oincr - 2*(argument[2] + 1) is where the
	 * list of case branch displacements begins.
	 */
	if (caseflg) {
		int numargs = argument[2] + 1;
		int firstcase = dot + oincr - numargs - numargs;
		int argno;
		for (argno = 0; argno < numargs; argno++) {
			/* branch displacement for case "argno"
			 * (address = PC [i.e. dot] + displacement)
			 * is at firstcase + 2*argno (2 bytes per case)
			 */
			value = (long)(short)get(firstcase+argno+argno,ISP);

			printf("\n    ");
			if (argno + argument[1] < 0) printf("-%#x:    ",
				-(argno + argument[1]));
			else printf("%#x:    ", argno + argument[1]);
			if (value < 0) printf("-%#x ", -value);
			else		printf("%#x ", value);
			printf("<%#x>\t[", firstcase + value);

			psymoff(firstcase+value, -1, 'i');
			printf("]");
		}

	}
#endif
}

/* changed 2nd arg in psymoff():  char **r --> int regno */
static
psymoff(val, regno, fmt)
L_INT val; char fmt; int regno; {
	struct proct *procp;
	register long diff = -1;

#if DEBUG
	if(debug)
		fprintf(FPRT2, "psymoff(val=%#x, regno=%#x, fmt='%c');\n",
				val, regno, fmt);
#endif
	if (fmt == 'i') {
		if (regno == APNO) {   /* parameter ("ap" in regname) */
#ifndef m68k
			diff = adrtoparam((ADDR)val, adrtoprocp(dot));
#else  
			diff = adrtolocal((ADDR)val, adrtoprocp(dot));
#endif
		}
		else if (regno == FPNO) {	/* local ("fp" in regname) */
#ifndef m68k
			diff = adrtolocal((ADDR)val, adrtoprocp(dot));
#else
			diff = adrtoparam((ADDR)val, adrtoprocp(dot));
#endif
		}
		else if (ISREGVAR(regno)) {
			diff = adrtoregvar((ADDR)regno, adrtoprocp(dot));
		}
		if (regno != -1 && diff < 0)
			return(-1);
		if(diff != -1) {
#ifdef vax
			/* VAX symbols have _ prepended */
			if (*sl_name == '_')
				printf("%.7s", sl_name+1);
			else	printf("%.8s", sl_name);
#else
#ifdef FLEXNAMES
				printf("%s", sl_name);
#else
				printf("%.8s", sl_name);
#endif
#endif
			prdiff(diff);
			return(0);
		}

		if (val < firstdata) {
			if ((procp = adrtoprocp((ADDR) val)) != badproc) {
				prlnoff(procp, val);
				return(0);
			}
		} else {
			if ((diff = adrtoext((ADDR) val)) != -1) {
#ifdef vax
				if (*sl_name == '_')
					printf("%.7s", sl_name+1);
				else	printf("%.8s", sl_name);
#else
#ifdef FLEXNAMES
				printf("%s", sl_name);
#else
				printf("%.8s", sl_name);
#endif
#endif
				prdiff(diff);
				return(0);
			}
		}
	}
	prhex(val);
	return(1);
}


prdiff(diff) {
	if (diff) {
		printf("+");
		prhex(diff);
	}
}