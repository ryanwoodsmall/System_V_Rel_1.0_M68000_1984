/* @(#)mailst.c	2.1	 */
#include "uucp.h"



/*
 * fork and execute a mail command sending 
 * string (str) to user (user).
 * If file is non-null, the file is also sent.
 * (this is used for mail returned to sender.)
 *	user	 -> user to send mail to
 *	str	 -> string mailed to user
 *	file 	 -> optional file mailed to user
 */
mailst(user, str, file)
char *user, *str, *file;
{
	register FILE *fp, *fi;
	register int nc;
	extern FILE *popen();
	char cmd[100], buf[BUFSIZ];

	sprintf(cmd, "mail %s", user);
	if ((fp = popen(cmd, "w")) == NULL)
		return;
	fprintf(fp, "%s", str);

	if (*file != '\0' && (fi = fopen(file, "r")) != NULL) {

		/*
		 * read and write should be checked
 		 */
		while ((nc = fread(buf, sizeof (char), BUFSIZ, fi)) > 0)
			fwrite(buf, sizeof (char), nc, fp);
		fclose(fi);
	}

	pclose(fp);
	return;
}
char un[2*NAMESIZE];
setuucp(p)
char	*p;
{
	char **envp;

	envp = Env;
	for(;envp[0];envp++){
		if(strncmp(envp[SAME], "LOGNAME", 7) == 0)
			sprintf(un, "LOGNAME=%s",p);
			envp[0] = &un[0];
	}
}
