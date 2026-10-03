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

FILE *block_fid = NULL;

/* Open out block file with the Forth name `filename' */
/* `filename' is a stored Forth string.               */
int c_block_init( int count, char filename[] )
{
    int rc;

  /* turn into c-string */
  char zname[MAX_COMMAND];
  strncpy_s(zname, MAX_COMMAND, filename, 10);
  zname[count] = 0;

  if (block_fid != NULL)
    fclose(block_fid);    
  rc = fopen_s(&block_fid, zname, "r+");

  return block_fid > 0 ? 0 : rc;
}       

/* Close block file earlier opened with c_block_init */
int c_block_exit( void )
{
  int rc = fclose( block_fid );
  block_fid = NULL;
  return rc;
}

/* RSLW */
int c_rslw(int control, int block, void *pmem )
{

    if (block_fid == 0)
        return -1;

    fseek(block_fid, block * KBBUF, SEEK_SET);
    if (control)    // Reading
    {
        return fread_s(pmem, KBBUF, KBBUF, 1, block_fid);
    }
    else
    {               // Writing
        return fwrite(pmem, KBBUF, 1, block_fid);
    }
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
