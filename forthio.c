/* Copyright (2000): Albert van der Horst, HCC FIG Holland by GNU Public License */
#include <stdio.h>
#include <signal.h>
#include <setjmp.h>
#include <stdlib.h>
#include <string.h>

/* Entry point of figforth. */

/* The offset into the boot parameters. */
typedef enum { COLD = 0, WARM = 4 } BOOT_OFFSET;
extern void figforth( BOOT_OFFSET offset, int argc, char **argv ); 

/* The maximum size of a Forth command passed to the OS */
#define MAX_COMMAND 2000

/* The size of a Forth block aka screen */
#define KBBUF 1024

/*****************************************************************************/
/*                      SIGNALS                                              */
/*****************************************************************************/


/* To be executed on SIGINT (Normally ^C) */
int break_pressed = 0;
void break_int(int ignore)
{
    signal(SIGINT, break_int);
    break_pressed = 1;
}

/* To be executed on SIGQUIT (Normally ^\) */
/* and on SIGSEGV (Normally invalid address) */
jmp_buf restart_forth;
void break_quit(int signum)
{
    signal(signum, break_quit);
    longjmp(restart_forth, WARM);
}

/* Actions performed in behalf of Forth.                                     */
/*  The Forth names fully specifiy the action, once you know that the stack  */
/*  translates in variables, but reversed. Forth names are got by removing   */
/*  "c_", upercasing and replacing '_' by  '-' from the c-function name      */


/* ?TERMINAL */
/* The "any key" is the break key. */
int c_qterminal(void) 
{
    return 0;   // temporarily
}
 
/* KEY */
int c_key( void )
{
  return getchar();
}

/* TYPE */
void c_type(int count, char buffer[])
{
  fwrite(buffer, 1, count, stdout);
  fflush(stdout);
}

/* EXPECT */
int c_expect(int count, char buffer[])
{
    int ll;
  fgets(buffer, count, stdin);
  // strip the LF off.
  ll = strlen(buffer);
  buffer[ll - 1] = '\0';
  return count;     /* Ignored by fig-Forth, for ANSI ACCEPT you need the actual no of chars read.*/
}


/* Open a file for reading, with the Forth name `filename'  */
/* `filename' is a stored Forth string.                     */
/* Returns fileID or 0 if failed.                           */
FILE* c_file_open( int count, char filename[] )
{
    int rc;
    FILE* fid;

  /* turn into c-string */
  char zname[MAX_COMMAND];
  strncpy_s(zname, MAX_COMMAND, filename, count);
  zname[count] = 0;

  rc = fopen_s(&fid, zname, "r");

  return rc == 0 ? fid : 0;
}       

/* Close file earlier opened with c_file_open */
int c_file_close(FILE* fid)
{
    return fclose(fid);
}

/* Read and write (NOTE: open for writing not yet imp */
int c_file_read(void* pmem, int size, FILE* fid)
{
    if (fid == 0)
        return -1;

    return fread_s(pmem, size, size, 1, fid);
}

int c_file_write(void* pmem, int size, FILE* fid)
{
    if (fid == 0)
        return -1;

    return fwrite(pmem, size, 1, fid);
}

/* EXIT (BYE) */
void c_exit(void)
{
    exit(1);
}


/* Perform ANSI Forth 'SYSTEM' */
/* Interpret the Forth string (`command',`count') as linux                   */
/* command and execute it.                                                   */
int c_system(int count, char command[])
{
  char buffer[MAX_COMMAND];

  if( MAX_COMMAND-1 > count )
      return -1;

  strncpy_s( buffer, count, command, MAX_COMMAND);
  buffer[count]=0;
  buffer[count-1]=0;
  return system(buffer);
}


int main (int argc, char *argv[])
{
  BOOT_OFFSET bootmode = COLD;

/*signal(SIGINT, SIG_IGN);                                                   */
  /* Convenient interrupting of long loops */
  //signal(SIGQUIT, break_quit);                                                 
  /* Restart when inspecting non existing memory */
  signal(SIGSEGV, break_quit);

  for (;;)
  {
      if (!setjmp(restart_forth))
      {
          figforth(bootmode, argc, argv);
          break;
      }
      else
      {
          bootmode = WARM;
      }
  }
}
