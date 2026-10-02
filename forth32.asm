


;               HCC FIG generic 8086 FORTH
; $Id: fig86.gnr,v 2.148 2000/12/02 14:58:07 albert Exp $
; Copyright (2000): Albert van der Horst, HCC FIG Holland by GNU Public License
;
        ;  66,106
 ;   GENERIC FORTH FOR 8086 $Revision: 2.148 $
 ;
; NASM version of FIG FORTH created by M4 from generic listing.
;
%if 0
        A generic version of FIG-FORTH for IBM type standard PC's
                Albert van der Horst
                HCC Forth user group
                The Netherlands
                www.forth.hccnet.nl

              based on
              FIG-FORTH
   implemented by:  Charlie Krajewski
                    205 ( BIG ) Blue Rd.
                    Middletown, CT  06457

  This implementation supports only one 64k segment

  The listing has been made possible by the
  prior work of:
               Thomas Newman, Hayward, Ca.

 : other_acknowledgements
         John_Cassidy
         Kim_Harris
         George_Flammer
         Robert_D._Villwock ;
 To upgrade, modify, and understand Fig Forth, the
 value of the following book cannot be overstated:
         Systems Guide to FIG Forth
         C. H. Ting, PhD
 It is available through MVP.  See any recent issue
 of FORTH Dimensions for their ad. (DIXIT AD MDCCCCLXXX)

No one who programs with FORTH can afford to be without:
  Starting Forth
  Leo Brodie
Get it.  Available through FORTH Interest Group.
Can also be found in many book stores.
Chapter 3 serves as a guide for the EDITOR that you
will probably type in from the FIG-Forth installation
manual.

Although there is much to be said for typing in your own
listing and getting it running, there is much to be said
not typing in your own listing.  If you feel that 100+
pages of plinking is nutty, contact me for availability
of a disc with source & executable files.  Obtainable at
a bargain basement price, prepare yourself for bargain
basement support.

All publications of the FORTH Interest Group are public domain.
They may be further distributed by the inclusion of this
credit notice:
               This publication has been made available by:

               FORTH Interest Group
               P.O. Box 1105
               San Carlos, Ca.  94070
%endif
        ;
; ########################################################################################
;                       PREPARATION (no code)
; ########################################################################################
FIGREL  EQU     2       ; FIG RELEASE #
FIGREV  EQU     0       ; FIG REVISION #
USRVER  EQU     34      ; USER VERSION NUMBER, a digit now
;
;       PROTECTION
CW      EQU     4       ; I.e. for the mode used in Forth, not in the bootcode.
PMASK   EQU     0FFH    ; Allow to access only 256 blocks from OFFSET
;
;      ASCII CHARACTER EQUIVALENTS
;
ABL     EQU     20H     ; SPACE
ACR     EQU     0DH     ; CR
ADOT    EQU     2EH     ; PERIOD
BELL    EQU     07H     ; ^G
BSIN    EQU     08H     ; INPUT DELETE CHARACTER
BSOUT   EQU     08H     ; OUTPUT BACKSPACE ( ^H )
LF      EQU     0AH     ; LINE FEED, USED INTERNALLY AS
                        ; LINE ENDER
FF      EQU     0CH     ; FORM FEED
;
;      MEMORY + I/O CONSTANTS
;
NBUF    EQU     2       ; NO. OF BUFFERS AKA SCREENS 
KBBUF   EQU     1024    ;DATA BYTES PER DISK BUFFER
US      EQU     100H     ; USER VARIABLE SPACE

 RTS     EQU  10000H    ; RETURN STACK & TERM BUFFER 
;
 ;

;

BPS     EQU     512             ;Bytes/sector, common to all of MSDOS
SPB     EQU     KBBUF/BPS
;
; PHYSICAL DISK PARAMETERS
; (not needed for MODERN)
; (not needed for BOOTHD)
;
; Disk parameters: 
; HD drive 3" 
TRKS    EQU     80    ;Number of tracks
SPT     EQU     18    ;Sectors/track
HEADS   EQU     2     ;Number of heads 
NFAT    EQU     2     ; Number of FATS
SECROOT EQU     0EH   ; Sectors for root directory entry.
SECFAT  EQU     9     ; Sectors per FAT
MEDIA   EQU    0F0H   ; Descriptor byte. Anachronism.

%if 0
; HD drive 5" 
TRKS    EQU     80      ;Number of tracks
SPT     EQU     15      ;Sectors/track
HEADS   EQU     2       ;Number of heads 
NFAT    EQU     2       ; Number of FATS
SECROOT EQU     ?       ; Sectors for root directory entry.
SECFAT  EQU     ?       ; Sectors per FAT
MEDIA   EQU    F0H      ; Descriptor byte. Anachronism.
%endif

; Bios specific equates.
BOOTADDRESS     EQU     07C00H ; PC jumps to 0:7C00 to boot
SPDRV   EQU     HEADS*TRKS*SPT    ; sectors/drive
        ; Skip boot sector,fats and root dir and first sector of file.
SECSTRT EQU     1+NFAT*SECFAT + SECROOT + 1
%if 0
; Alternative if the disk need not be recognized by MSDOS
; Usable for generating a bootable floppy simple.
SECSTRT EQU     1
%endif
; END  OF PHYSICAL DISK PARAMETERS

;
BMASK   EQU     80000000H

; ########################################################################################
; ENTRY macros to define dictionary headers. There is one for code immediately
; following, and another for DOCOL etc. Forth routines.
; NOTE WELL the C_Label - MASM silently (!) fails on the original code:
;   label DD $+4
;
; with a value of 4 instead of currentlocation + 4. These things, along with bizarre behaviour
; of colon/no-colon on labels, are sent to try us.

; Initial value of link
Link    =     0

; Code entry (where code follows directly after entry)
CODE_ENTRY    MACRO   Label, Count, Ref, Last

N_&Label& DB  Count
        DB  Ref
        DB  Last
        DD  Link
Link    = N_&Label&
Label   DD  C_&Label&
C_&Label&:
ENDM

; Code entry as above, but with only a 1 character name (there is no Ref).
; This saves the IFNB test which causes problems with escaping special chars.
CODE_ENTRY_1  MACRO   Label, Count, Last

N_&Label& DB  Count
        DB  Last
        DD  Link
Link    = N_&Label&
Label   DD  C_&Label&
C_&Label&:
ENDM

; Forth word entry (Docode and other Forth words follow)
ENTRY    MACRO   Label, Count, Ref, Last, DoCode

N_&Label& DB  Count
        DB  Ref
        DB  Last
        DD  Link
Link    = N_&Label&
Label   DD  DoCode
ENDM

; Forth word entry (1 char version as above)
ENTRY_1    MACRO   Label, Count, Last, DoCode

N_&Label& DB  Count
        DB  Last
        DD  Link
Link    = N_&Label&
Label   DD  DoCode
ENDM


; ########################################################################################

.386
.model flat, c


; I/O routines.
        extern  c_type:PROC
        extern  c_expec:PROC
        extern  c_key:PROC
        extern  c_qterm:PROC
        extern  c_rslw:PROC
        extern  c_block_exit:PROC
        extern  c_block_init:PROC
 ;



        ;
; ########################################################################################
;                      BOOTCODE    (optional, always real mode)
; ########################################################################################

; All bootcode must be relocatable and its memory references absolute.
; Not for the sake of booting, but to allow MSDOS to start the program too. 

        ;    SEGMENT PARA PUBLIC 'CODE'
        ; CS:;,DS:;,SS:;,ES:;
    

; ########################################################################################
;                       ADJUST CODE SEGMENT REGISTER (still real mode)
; ########################################################################################
; Required start of .COM program.
    

; ########################################################################################
;                       MOVE CODE TO ITS PLACE (still real mode)
; ########################################################################################

;

; ########################################################################################
;                       FILL GDT AND SWITCH TO PROTECTED MODE/32 BITS (optional)
; ########################################################################################
;

;

;

.stack 4096
.code
PUBLIC figforth
figforth proc

        LEA     ECX,[ESP+(CW*1)]
        XOR     EAX,EAX
        CMP     EAX, DWORD PTR[ECX]
        JZ     ENDIF1
        JMP     BOOTUP+(CW*2)         ; Warm start
ENDIF1:
        JMP     BOOTUP                  ; Cold start

; ########################################################################################
;                       FORTH ITSELF (entry point : BOOTUP)
; ########################################################################################
;
%if 0
   FORTH REGISTERS

   FORTH   8088     FORTH PRESERVATION RULES
   -----   ----     ----- ------------ -----
    IP      ESI      Interpreter pointer.  Must be preserved
                    across FORTH words.

     W      EBX      Working register.  When entering a word
                    via its code field the CFA is passed in EBX.

    SP      SP      Parameter stack pointer.  Must be preserved
                    across FORTH words.

    RP      EBP      Return stack.  Must be preserved across
                    FORTH words.

            EAX      General register.  Used to pass data from
                    FORTH words, see label APUSH.

            EDX      General register.  Used to pass more data from
                    FORTH words, see label DPUSH.

            EBX      General purpose register.

            ECX      General purpose register.

            CS      Segment register.  Must be preserved
                    across FORTH words.

            DS      ditto

            SS      ibid

            ES      Temporary segment register only used by
                    a few words. However it MUST remain equal to
                    DS, such that string primitives can be used
                    with impunity.

----------------------------------------------------------
%endif
        ;
%if 0
---------------------------------------------

   COMMENT CONVENTIONS
   ------- -----------

   =       IS EQUAL TO
   <-      ASSIGNMENT

  NAME        =  Address of name
  (NAME)      =  Contents of name
  ((NAME))    =  Indirect contents

  CFA         =  Address of CODE FIELD
  LFA         =  Address of LINK FIELD
  NFA         =  Address of NAME FIELD
  PFA         =  Address of PARAMETER FIELD

  S1          =  Parameter stack - 1st word
  S2          =  Parameter stack - 2nd word
  R1          =  Return stack    - 1st word
  R2          =  Return stack    - 2nd word

  LSB         =  Least significant bit
  MSB         =  Most  significant bit
  LB          =  Low byte
  HB          =  High byte
  LW          =  Low  word

------------------------------------------------------------
%endif
;
        ;
;

DPUSH:  PUSH    EDX
APUSH:  PUSH    EAX

;

; In 32 bit versions there may be no jumps to NEXT at all 
; The label NEXT1 is rarely relevant (for _OLDDEBUG_) 
NEXT:   LODSD           ;AX <- (IP)
NEXT1:  MOV     EBX,EAX   ; (W) <- (IP)

        JMP      DWORD PTR[EBX]    ; TO `CFA'
        ;
;
;       Dictionary starts here.

DP0:
;  *********** 
;  *   LIT   *
;  *********** 
;  
%if 1
        CODE_ENTRY LIT, 80H+3, "LI", "T"+80H
%else
N_LIT      DB   80H+3
         DB      "LI"
         DB     "T"+80H
         DD    0
LIT      DD     $+CW
%endif                           
        LODSD           ; AX <- LITERAL
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]             ; TO TOP OF STACK
;

;  *************** 
;  *   EXECUTE   *
;  *************** 
;  
%if 1
        CODE_ENTRY EXEC, 80H+7, "EXECUT", "E"+80H
%else
N_EXEC      DB   80H+7
         DB      "EXECUT"
         DB     "E"+80H
         DD    N_LIT
EXEC      DD     $+CW
%endif                           
        POP     EBX      ; GET CFA
        JMP      DWORD PTR[EBX]
;

;  ************** 
;  *   BRANCH   *
;  ************** 
;  
%if 1
        CODE_ENTRY BRAN, 80H+6, "BRANC", "H"+80H
%else
N_BRAN      DB   80H+6
         DB      "BRANC"
         DB     "H"+80H
         DD    N_EXEC
BRAN      DD     $+CW
%endif                           
BRAN1:  ADD     ESI,[ESI]
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]       ; JUMP TO OFFSET
;

;  *************** 
;  *   0BRANCH   *
;  *************** 
;  
%if 1
        CODE_ENTRY ZBRAN, 80H+7, "0BRANC", "H"+80H
%else
N_ZBRAN      DB   80H+7
         DB      "0BRANC"
         DB     "H"+80H
         DD    N_BRAN
ZBRAN      DD     $+CW
%endif                           
        POP     EAX      ; GET STACK VALUE
        OR      EAX,EAX   ; ZERO?
        JZ      BRAN1   ; YES, BRANCH
        LEA     ESI,[ESI+(CW*1)]
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************ 
;  *   NOOP   *
;  ************ 
;  
%if 1
        CODE_ENTRY NOOP, 80H+4, "NOO", "P"+80H
%else
N_NOOP      DB   80H+4
         DB      "NOO"
         DB     "P"+80H
         DD    N_ZBRAN
NOOP      DD     $+4
%endif
%if 0   ;  Clean out the rubbish.
;      DEBUG STUFF
NOP0      DD      $+(CW*1)
        JMP SHORT     NEXT
NOP1      DD      $+(CW*1)
        JMP SHORT     NEXT
NOP2      DD      $+(CW*1)
%endif
        JMP SHORT     NEXT
;

;  ************** 
;  *   (LOOP)   *
;  ************** 
;  
%if 1
        CODE_ENTRY XLOOP, 80H+6, "(LOOP", ")"+80H
%else
N_XLOOP      DB   80H+6
         DB      "(LOOP"
         DB     ")"+80H
         DD    N_NOOP
XLOOP      DD     $+CW
%endif                           
        MOV     EBX,1    ; INCREMENT
XLOO1:  ADD     [EBP],EBX ; INDEX = INDEX + INCR
        MOV     EAX,[EBP] ; GET NEW INDEX
        SUB     EAX,[EBP+(CW*1)]        ; COMPARE WITH LIMIT
        XOR     EAX,EBX   ; TEST SIGN
        JS      BRAN1   ; KEEP LOOPING
;
;  END OF `DO' LOOP
        ADD     EBP,BYTE (CW*2)  ; ADJ RETURN STACK
        LEA     ESI,[ESI+(CW*1)]       ; BYPASS BRANCH OFFSET
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *************** 
;  *   (+LOOP)   *
;  *************** 
;  
%if 1
        CODE_ENTRY XPLOO, 80H+7, "(+LOOP", ")"+80H
%else
N_XPLOO      DB   80H+7
         DB      "(+LOOP"
         DB     ")"+80H
         DD    N_XLOOP
XPLOO      DD     $+CW
%endif                           
        POP     EBX      ; GET LOOP VALUE
        JMP SHORT     XLOO1
;

;  ************ 
;  *   (DO)   *
;  ************ 
;  
%if 1
        CODE_ENTRY XDO, 80H+4, "(DO", ")"+80H
%else
N_XDO      DB   80H+4
         DB      "(DO"
         DB     ")"+80H
         DD    N_XPLOO
XDO      DD     $+CW
%endif                           
        POP     EDX      ; INITIAL INDEX VALUE
        POP     EAX      ; LIMIT VALUE
        XCHG    EBP,ESP   ; GET RETURN STACK
        PUSH    EAX
        PUSH    EDX
        XCHG    EBP,ESP   ; GET PARAMETER STACK
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   I   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1 IDO, 80H+1, "I"+80H
%else
N_IDO      DB   80H+1
         DB     "I"+80H
         DD    N_XDO
IDO      DD     $+CW
%endif                           
        MOV     EAX,[EBP] ; GET INDEX VALUE
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]             ; TO PARAMETER STACK
;

;  *************** 
;  *   +ORIGIN   *
;  *************** 
;  
%if 1
        ENTRY PORIG, 80H+7, "+ORIGI", "N"+80H, DOCOL
%else
N_PORIG      DB   80H+7
         DB      "+ORIGI"
         DB     "N"+80H
         DD    N_IDO
PORIG      DD     DOCOL
%endif                           
        DD      LIT
        DD      USINI
        DD      PLUS
        DD      SEMIS
;
;
;      Initialisation block for user variables through VOC-LINK
;       <<<<< must be in same order as user variables >>>>>
;
BOOTUP:
        NOP                    ; Fills jump to 4 bytes (for 16 bits code)
        NOP         ; or to 8 bytes for 32 bits code  
        NOP 
        JMP     LCLD     ;VECTOR TO COLD START
        NOP                    ; Fills jump to 4 bytes (for 16 bits code)
        NOP         ; or to 8 bytes for 32 bits code  
        NOP 
        JMP     WRM     ; VECTOR TO WARM START
        DB      FIGREL  ; FIG RELEASE #
        DB      FIGREV  ; FIG REVISION #
        DB      USRVER  ; USER REVISION #
        DB      0EH     ; VERSION ATTRIBUTES
        DD 0   ; Fill version info up to two cells. 
USINI:
        DD      N_TASK ; FIRST DEFINITION 0 
        DD      STRUSA  ; INIT (U0) USER AREA POINTER 1
        DD      BSIN    ; RUBOUT: get rid of latest char 2
        DD      INITS0  ; INIT (S0)         3
        DD      INITR0  ; INIT (R0)         4
        DD      STRTIB  ; INIT (TIB)        5
        DD      32      ; INIT (WIDTH)      6
        DD      0       ; INIT (WARNING)      7
        DD      INITDP  ;      INIT (FENCE)  8
        DD      INITDP  ;      INIT (DP)     9
        DD      FORTH+2+(CW*2)+(CW*1) ;       INIT (VOC-LINK) 10

        DD      0       ; INIT (OFFSET) 
 ;
;
;
;
;
;
;
;
;      The following is the CPU's name, printed
;       during cold start.
;       The name is 32 bits in base 36.
;
;

CPUNM      DD      0CDH,1856H       ; '80386'     12 13 
;
;
;
;      <<<<< end of data used by cold start >>>>>
; Pad out to US (100H) bytes for the CMOVE
        BYTE    US-($ - USINI) DUP(0)        ; All user can be initialised.
;

;  ************* 
;  *   DIGIT   *
;  ************* 
;  
%if 1
        CODE_ENTRY DIGIT, 80H+5, "DIGI", "T"+80H
%else
N_DIGIT      DB   80H+5
         DB      "DIGI"
         DB     "T"+80H
         DD    N_PORIG
DIGIT  DD     $+CW
%endif                           
        POP     EDX      ;NUMBER BASE
        POP     EAX      ;ASCII DIGIT
        SUB     AL,'0'
        JB      DIGI2   ;NUMBER ERROR
        CMP     AL,9
        JBE     DIGI1   ;NUMBER = 0 THRU 9
        SUB     AL,7
        CMP     AL,10   ;NUMBER 'A' THRU 'Z'?
        JB      DIGI2   ;NO
DIGI1:  CMP     AL,DL   ; COMPARE NUMBER TO BASE
        JAE     DIGI2   ;NUMBER ERROR
        SUB     EDX,EDX   ;ZERO
        MOV     DL,AL   ;NEW BINARY NUMBER
        MOV     AL,1    ;TRUE FLAG
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]             ;ADD TO STACK
;   NUMBER ERROR
DIGI2:  SUB     EAX,EAX   ;FALSE FLAG
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
        ;

;  ************** 
;  *   (FIND)   *
;  ************** 
;  
%if 1
        CODE_ENTRY PFIND, 80H+6, "(FIND", ")"+80H
%else
N_PFIND      DB   80H+6
         DB      "(FIND"
         DB     ")"+80H
         DD    N_DIGIT
PFIND  DD     $+CW
%endif                           
;       MOV     AX,DS
;       MOV    ES,AX   ;ES = DS
        POP     EBX      ;NFA
        POP     ECX      ;STRING ADDR
;
;  SEARCH LOOP
PFIN1:  MOV     EDI,ECX   ;GET ADDR
        MOV     AL,[EBX] ;GET WORD LENGTH
        MOV     DL,AL   ;SAVE WORD LENGTH
        XOR     AL,[EDI]
        AND     AL,3FH  ;CHECK LENGTHS
        JNZ     PFIN5   ;LENGTHS DIFFER

;
;   LENGTHS MATCH - CHECK EACH CHARACTER IN NAME
PFIN2:  INC     EBX
        INC     EDI      ; NEXT CHAR OF NAME
        MOV     AL,[EBX]
        XOR     AL,[EDI] ;COMPARE NAMES
        ADD     AL,AL   ;THIS WILL BE TEST BIT 8
        JNZ     PFIN5A  ;NO MATCH
        TEST    BYTE PTR[EBX], 80H  ;Test for Last char of NFA
        JZ      PFIN2   
;
;   FOUND END OF NAME (BIT 8 SET) - A MATCH
        ADD     EBX, 1+(CW*2); BX = PFA
        PUSH    EBX      ; (S3) <- PFA
        MOV     EAX,1    ;TRUE VALUE
        SUB     DH,DH
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
;   NO NAME MATCH - TRY ANOTHER
;
; GET NEXT LINK FIELD ADDR (LFA)
; ( ZERO = FIRST WORD OF DICTIONARY )
;
PFIN5:  INC     EBX      ;NEXT ADDR
        JB      PFIN6   ;END OF NAME
PFIN5A: MOV     AL,[EBX] ;GET NEXT CHAR
        ADD     AL,AL   ;SET/RESET CARRY
        JMP SHORT     PFIN5   ;LOOP UNTIL FOUND
;
PFIN6:  MOV     EBX,[EBX] ; GET LINK FIELD ADDR
        OR      EBX,EBX   ; START OF DICT ( 0 )
        JNZ     PFIN1   ; NO , LOOK MORE
        MOV     EAX,0    ; FALSE FLAG
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]             ; DONE ( NO MATCH FOUND )
;

;  *************** 
;  *   ENCLOSE   *
;  *************** 
;  
%if 1
        CODE_ENTRY ENCL, 80H+7, "ENCLOS", "E"+80H
%else
N_ENCL      DB   80H+7
         DB      "ENCLOS"
         DB     "E"+80H
         DD    N_PFIND
ENCL  DD     $+CW
%endif                           
        POP     EAX      ;S1 - TERMINATOR CHAR
        POP     EBX      ;S2 - TEXT ADDR
        PUSH    EBX      ;ADDR - BACK TO STACK ( IT RHYMES )
        MOV     AH,0    ;ZERO
        MOV     EDX,-1   ;CHAR OFFSET COUNTER
        DEC     EBX      ;ADDR -1
;
;   SCAN TO FIRST NON-TERMINATOR CHARACTER
ENCL1:  INC     EBX      ;ADDR+1
        INC     EDX      ;COUNT+1
        CMP     AL,[EBX]
        JZ      ENCL1   ;WAIT FOR NON-TERMINATOR
        PUSH    EDX      ;OFFSET TO 1ST TEXT CHAR
        CMP     AH,[EBX] ;NULL CHAR?
        JNZ     ENCL2   ;NO
;
;  FOUND NULL BEFORE 1ST NON-TERM CHAR
        MOV     EAX,EDX   ;COPY COUNTER
        INC     EDX      ; +1
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
;   FOUND FIRST TEXT CHAR - COUNT THE CHARS
ENCL2:  INC     EBX      ; ADDR+1
        INC     EDX      ;COUNT+1
        CMP     AL,[EBX] ;TERMINATOR CHAR?
        JZ      ENCL4   ;YES
        CMP     AH,[EBX] ;NULL CHAR?
        JNZ     ENCL2   ;NO, LOOP AGAIN
;
;   FOUND NULL AT END OF TEXT
ENCL3:  MOV     EAX,EDX   ;COUNTERS ARE EQUAL
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
;   FOUND TERMINATOR CHARACTER
ENCL4:  MOV     EAX,EDX
        INC     EAX      ;COUNT+1
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   CR   *
;  ********** 
;  
%if 1
        ENTRY CR, 80H+2, "C", "R"+80H, DOCOL
%else
N_CR      DB   80H+2
         DB      "C"
         DB     "R"+80H
         DD    N_ENCL
CR  DD     DOCOL
%endif                           
        DD      LIT,LF
        DD      EMIT
        DD      SEMIS
;

;  ************* 
;  *   CMOVE   *
;  ************* 
;  
%if 1
        CODE_ENTRY LCMOVE, 80H+5, "CMOV", "E"+80H
%else
N_LCMOVE      DB   80H+5
         DB      "CMOV"
         DB     "E"+80H
         DD    N_CR
LCMOVE      DD     $+CW
%endif                           
        CLD             ;INC DIRECTION
        MOV     EBX,ESI   ;SAVE IF
        POP     ECX      ;COUNT
        POP     EDI      ;DEST
        POP     ESI      ;SOURCE
;       MOV    AX,DS
;       MOV    ES,AX   ;ES <- DS
        REP     MOVSB   ;THAT'S THE MOVE
        MOV     ESI,EBX   ;GET BACK IP
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   U*   *
;  ********** 
;  
%if 1
        CODE_ENTRY USTAR, 80H+2, "U", "*"+80H
%else
N_USTAR      DB   80H+2
         DB      "U"
         DB     "*"+80H
         DD    N_LCMOVE
USTAR      DD     $+CW
%endif                           
        POP     EAX
        POP     EBX
        MUL     EBX      ;UNSIGNED
        XCHG    EAX,EDX   ;AX NOW = MSW
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]             ;STORE DOUBLE CELL
;

;  ********** 
;  *   U/   *
;  ********** 
;  
%if 1
        CODE_ENTRY USLAS, 80H+2, "U", "/"+80H
%else
N_USLAS      DB   80H+2
         DB      "U"
         DB     "/"+80H
         DD    N_USTAR
USLAS      DD     $+CW
%endif                           
        POP     EBX      ;DIVISOR
        POP     EDX      ;MSW OF DIVIDEND
        POP     EAX      ;LSW OF DIVIDEND
        CMP     EDX,EBX   ;DICIDE BY 0?
        JNB     DZERO   ; ERROR - ZERO DIVIDE
        DIV     EBX      ;16 BIT DIVIDE
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]             ;STORE QUOT/REM
;
;      DIVIDE BY ZERO ERROR - SHOW MAX NUMBERS
DZERO:  MOV     EAX,-1
        MOV     EDX,EAX
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]             ;STORE QUOT/REM
;

;  *********** 
;  *   AND   *
;  *********** 
;  
%if 1
        CODE_ENTRY LAND, 80H+3, "AN", "D"+80H
%else
N_LAND      DB   80H+3
         DB      "AN"
         DB     "D"+80H
         DD    N_USLAS
LAND      DD     $+CW
%endif                           
        POP     EAX
        POP     EBX
        AND     EAX,EBX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   OR   *
;  ********** 
;  
%if 1
        CODE_ENTRY LOR, 80H+2, "O", "R"+80H
%else
N_LOR      DB   80H+2
         DB      "O"
         DB     "R"+80H
         DD    N_LAND
LOR      DD     $+CW
%endif                           
        POP     EAX      ; (S1) <- (S1) OR (S2)
        POP     EBX
        OR      EAX,EBX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *********** 
;  *   XOR   *
;  *********** 
;  
%if 1
        CODE_ENTRY LXOR, 80H+3, "XO", "R"+80H
%else
N_LXOR      DB   80H+3
         DB      "XO"
         DB     "R"+80H
         DD    N_LOR
LXOR      DD     $+CW
%endif                           
        POP     EAX      ; (S1) <- (S1) XOR (S2)
        POP     EBX
        XOR     EAX,EBX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *********** 
;  *   SP@   *
;  *********** 
;  
%if 1
        CODE_ENTRY SPFET, 80H+3, "SP", "@"+80H
%else
N_SPFET      DB   80H+3
         DB      "SP"
         DB     "@"+80H
         DD    N_LXOR
SPFET      DD     $+CW
%endif                           
        MOV     EAX,ESP   ; (S1) <- (SP)
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *********** 
;  *   SP!   *
;  *********** 
;  
%if 1
        CODE_ENTRY SPSTO, 80H+3, "SP", "!"+80H
%else
N_SPSTO      DB   80H+3
         DB      "SP"
         DB     "!"+80H
         DD    N_SPFET
SPSTO      DD     $+CW
%endif                           
        MOV     EBX, DWORD PTR[USINI+(CW*1)]   ;USER VAR BASE ADDR
        MOV     ESP,[EBX+(CW*3)]        ;RESET PARAM STACK POINTER
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *********** 
;  *   RP@   *
;  *********** 
;  
%if 1
        CODE_ENTRY RPFET, 80H+3, "RP", "@"+80H
%else
N_RPFET      DB   80H+3
         DB      "RP"
         DB     "@"+80H
         DD    N_SPSTO
RPFET      DD     $+CW
%endif
                           ;(S1) <- (RP)
        MOV     EAX,EBP   ;RETURN STACK ADDR
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *********** 
;  *   RP!   *
;  *********** 
;  
%if 1
        CODE_ENTRY RPSTO, 80H+3, "RP", "!"+80H
%else
N_RPSTO      DB   80H+3
         DB      "RP"
         DB     "!"+80H
         DD    N_RPFET
RPSTO      DD     $+CW
%endif                           
        MOV     EBX, DWORD PTR[USINI+(CW*1)]   ;(AX) <- USR VAR BASE
        MOV     EBP,[EBX+(CW*4)]        ;RESET RETURN STACK PTR
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   ;S   *
;  ********** 
;  
%if 1
        CODE_ENTRY SEMIS, 80H+2, ";", "S"+80H
%else
N_SEMIS      DB   80H+2
         DB      ";"
         DB     "S"+80H
         DD    N_RPSTO
SEMIS      DD     $+CW
%endif                           
        MOV     ESI,[EBP] ;(IP) <- (R1)
        LEA     EBP,[EBP+(CW*1)]
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************* 
;  *   LEAVE   *
;  ************* 
;  
%if 1
        CODE_ENTRY LLEAV, 80H+5, "LEAV", "E"+80H
%else
N_LLEAV      DB   80H+5
         DB      "LEAV"
         DB     "E"+80H
         DD    N_SEMIS
LLEAV      DD     $+CW
%endif
                           ;LIMIT <- INDEX
        MOV     EAX,[EBP] ;GET INDEX
        MOV     [EBP+(CW*1)],EAX        ;STORE IT AT LIMIT
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
        ;
;

;  ********** 
;  *   >R   *
;  ********** 
;  TODO: the ">" confuses MASM. IFNB <">">
%if 1
        CODE_ENTRY TOR, 80H+2, ">", "R"+80H
%else
N_TOR      DB   80H+2
         DB      ">"
         DB     "R"+80H
         DD    N_LLEAV
TOR      DD     $+CW
%endif
                        ; (R1) <- (S1)
        POP     EBX      ;GET STACK PARAMETER
        LEA     EBP,[EBP-(CW*1)]    ;MOVE RETURN STACK DOWN
        MOV     [EBP],EBX ;ADD TO RETURN STACK
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   R>   *
;  ********** 
;  
%if 1
        CODE_ENTRY FROMR, 80H+2, "R", ">"+80H
%else
N_FROMR      DB   80H+2
         DB      "R"
         DB     ">"+80H
         DD    N_TOR
FROMR      DD     $+CW
%endif
                          ;(S1) <- (R1)
        MOV     EAX,[EBP] ; GET RETURN STACK VALUE
        LEA     EBP,[EBP+(CW*1)]
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   R   *
;  ********* 
;  TODO: Is this OK or do I need to copy code?

%if 1
        ENTRY_1 RR, 80H+1, "R"+80H, IDO+(CW*1)
%else
N_RR      DB   80H+1
         DB     "R"+80H
         DD    N_FROMR
RR      DD     IDO+(CW*1)
%endif                           
;

;  ********** 
;  *   0=   *
;  ********** 
;  
%if 1
        CODE_ENTRY ZEQU, 80H+2, "0", "="+80H
%else
N_ZEQU      DB   80H+2
         DB      "0"
         DB     "="+80H
         DD    N_RR
ZEQU      DD     $+CW
%endif                           
        POP     EAX
        OR      EAX,EAX   ;DO TEST
        MOV     EAX,1    ;TRUE
        JZ      ZEQU1   ;IT'S 0
        DEC     EAX      ;FALSE
ZEQU1:  PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   0<   *
;  ********** 
;  
%if 1
        CODE_ENTRY ZLESS, 80H+2, "0", "<"+80H
%else
N_ZLESS      DB   80H+2
         DB      "0"
         DB     "<"+80H
         DD    N_ZEQU
ZLESS      DD     $+CW
%endif                           
        POP     EAX
        OR      EAX,EAX   ;SET FLAGS
        MOV     EAX,1    ;TRUE
        JS      ZLESS1
        DEC     EAX      ;FALSE
ZLESS1: PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   +   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1 PLUS, 80H+1, "+"+80H
%else
N_PLUS      DB   80H+1
         DB     "+"+80H
         DD    N_ZLESS
PLUS      DD     $+CW
%endif                           
        POP     EAX      ;(S1) <- (S1) + (S2)
        POP     EBX
        ADD     EAX,EBX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   D+   *
;  ********** 
;  
%if 1
        CODE_ENTRY DPLUS, 80H+2, "D", "+"+80H
%else
N_DPLUS      DB   80H+2
         DB      "D"
         DB     "+"+80H
         DD    N_PLUS
DPLUS      DD     $+CW
%endif                           
        POP     EAX      ; YHW
        POP     EDX      ; YLW
        POP     EBX      ; XHW
        POP     ECX      ; XLW
        ADD     EDX,ECX   ; SLW
        ADC     EAX,EBX   ; SHW
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************* 
;  *   MINUS   *
;  ************* 
;  TODO: Why is this spelling "MINUS" out?
%if 1
        CODE_ENTRY MINUS, 80H+5, "MINU", "S"+80H
%else
N_MINUS      DB   80H+5
         DB      "MINU"
         DB     "S"+80H
         DD    N_DPLUS
MINUS      DD     $+CW
%endif                           
        POP     EAX
        NEG     EAX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************** 
;  *   DMINUS   *
;  ************** 
;  
%if 1
        CODE_ENTRY DMINU, 80H+6, "DMINU", "S"+80H
%else
N_DMINU      DB   80H+6
         DB      "DMINU"
         DB     "S"+80H
         DD    N_MINUS
DMINU      DD     $+CW
%endif                           
        POP     EBX
        POP     ECX
        SUB     EAX,EAX
        MOV     EDX,EAX
        SUB     EDX,ECX   ; MAKE 2'S COMPLEMENT
        SBB     EAX,EBX   ; HIGH CELL
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
        ;
;

;  ************ 
;  *   OVER   *
;  ************ 
;  
%if 1
        CODE_ENTRY    OVER, 80H+4, "OVE", "R"+80H
%else
				; Original code:
 0000052C 84			N_OVER      DB   80H+4
 0000052D  4F 56 45		         DB      "OVE"
 00000530  D2			         DB     "R"+80H
 00000531  0000050C R		         DD    N_DMINU
 00000535 00000539 R		OVER      DD     C_OVER
 00000539			C_OVER:                           
%endif

        POP     EDX
        POP     EAX
        PUSH    EAX
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************ 
;  *   DROP   *
;  ************ 
;  
%if 1
        CODE_ENTRY    DROP, 80H+4, "DRO", "P"+80H
%else
N_DROP      DB   80H+4
         DB      "DRO"
         DB     "P"+80H
         DD    N_OVER
DROP      DD     $+CW
%endif                           
        POP     EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************ 
;  *   SWAP   *
;  ************ 
;  
%if 1
        CODE_ENTRY    SWAP, 80H+4, "SWA", "P"+80H
%else
N_SWAP      DB   80H+4
         DB      "SWA"
         DB     "P"+80H
         DD    N_DROP
SWAP      DD     $+CW
%endif                           
        POP     EDX
        POP     EAX
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *********** 
;  *   DUP   *
;  *********** 
;  
%if 1
        CODE_ENTRY    LDUP, 80H+4, "DU", "P"+80H
%else
N_LDUP      DB   80H+3
         DB      "DU"
         DB     "P"+80H
         DD    N_SWAP
LDUP      DD     $+CW
%endif                           
        POP     EAX
        PUSH    EAX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************ 
;  *   2DUP   *
;  ************ 
;  
%if 1
        CODE_ENTRY    TDUP, 80H+4, "2DU", "P"+80H
%else
N_TDUP      DB   80H+4
         DB      "2DU"
         DB     "P"+80H
         DD    N_LDUP
TDUP      DD     $+CW
%endif                           
        POP     EAX
        POP     EDX
        PUSH    EDX
        PUSH    EAX
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   +!   *
;  ********** 
;  
%if 1
        CODE_ENTRY    PSTOR, 80H+2, "+", "!"+80H
%else
N_PSTOR      DB   80H+2
         DB      "+"
         DB     "!"+80H
         DD    N_TDUP
PSTOR      DD     $+CW
%endif                           
        POP     EBX      ;ADDRESS
        POP     EAX      ;INCREMENT
        ADD     [EBX],EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************** 
;  *   TOGGLE   *
;  ************** 
;  
%if 1
        CODE_ENTRY    TOGGL, 80H+6, "TOGGL", "E"+80H
%else
N_TOGGL      DB   80H+6
         DB      "TOGGL"
         DB     "E"+80H
         DD    N_PSTOR
TOGGL      DD     $+CW
%endif                           
        POP     EAX      ;BIT PATTERN
        POP     EBX      ;ADDR
        XOR     [EBX],EAX ;
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   @   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1    FETCH, 80H+1, "@"+80H
%else
N_FETCH      DB   80H+1
         DB     "@"+80H
         DD    N_TOGGL
FETCH      DD     $+CW
%endif                           
        POP     EBX
        MOV     EAX,[EBX]
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   C@   *
;  ********** 
;  
%if 1
        CODE_ENTRY    CFET, 80H+2, "C", "@"+80H
%else
N_CFET      DB   80H+2
         DB      "C"
         DB     "@"+80H
         DD    N_FETCH
CFET      DD     $+CW
%endif                           
        POP     EBX
        XOR     EAX,EAX
        MOV     AL,[EBX]
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   2@   *
;  ********** 
;  
%if 1
        CODE_ENTRY    TFET, 80H+2, "2", "@"+80H
%else
N_TFET      DB   80H+2
         DB      "2"
         DB     "@"+80H
         DD    N_CFET
TFET      DD     $+CW
%endif                           
        POP     EBX      ;ADDR
        MOV     EAX,[EBX] ;MSW
        MOV     EDX,[EBX+(CW*1)]        ;LSW
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   !   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1    STORE, 80H+1, "!"+80H
%else
N_STORE      DB   80H+1
         DB     "!"+80H
         DD    N_TFET
STORE      DD     $+CW
%endif                           
        POP     EBX      ;ADDR
        POP     EAX      ;DATA
        MOV     [EBX],EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   C!   *
;  ********** 
;  
%if 1
        CODE_ENTRY    CSTOR, 80H+2, "C", "!"+80H
%else
N_CSTOR      DB   80H+2
         DB      "C"
         DB     "!"+80H
         DD    N_STORE
CSTOR      DD     $+CW
%endif                           
        POP     EBX      ;ADDR
        POP     EAX      ;DATA
        MOV     [EBX],AL
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   2!   *
;  ********** 
;  
%if 1
        CODE_ENTRY    TSTOR, 80H+2, "2", "!"+80H
%else
N_TSTOR      DB   80H+2
         DB      "2"
         DB     "!"+80H
         DD    N_CSTOR
TSTOR      DD     $+CW
%endif                           
        POP     EBX      ;ADDR
        POP     EAX      ;MSW
        MOV     [EBX],EAX
        POP     EAX      ;LSW
        MOV     [EBX+(CW*1)],EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
;  ********** 
;  *   L@   *
;  ********** 
;  
%if 1
        CODE_ENTRY    LFET, 80H+2, "L", "@"+80H
%else
N_LFET      DB   80H+2
         DB      "L"
         DB     "@"+80H
         DD    N_TSTOR
LFET      DD     $+CW
%endif                           
        POP     EBX      ;MEM LOC
        POP     EAX      ;SEG REG VAL
        MOV     EDX,10H
        MUL     EDX
        ADD     EAX,EBX
        MOV     EAX,[EAX]
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
;
;
;  ********** 
;  *   L!   *
;  ********** 
;  
%if 1
        CODE_ENTRY    LSTORE, 80H+2, "L", "!"+80H
%else
N_LSTORE      DB   80H+2
         DB      "L"
         DB     "!"+80H
         DD    N_LFET
LSTORE      DD     $+CW
%endif
        POP     EBX      ;MEM LOC
        POP     EAX      ;SEG REG VAL
        MOV     EDX,10H
        MUL     EDX
        ADD     EAX,EBX
        POP     EBX
        MOV     [EAX],EBX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
;
;

;  ********* 
;  *   :   *
;  ********* 
;  
%if 1
        ENTRY_1    COLON, 80H+1+40H, ":"+80H, DOCOL
%else
N_COLON      DB   80H+1+40H
         DB     ":"+80H
         DD    N_LSTORE
COLON      DD     DOCOL
%endif                           
        DD      QEXEC
        DD      SCSP
        DD      CURR
        DD      FETCH
        DD      CONT
        DD      STORE
        DD      CREAT
        DD      RBRAC
        DD      PSCOD
DOCOL:  LEA     EBP,[EBP-(CW*1)]
        MOV     [EBP],ESI ;R1 <- (IP)
        LEA     ESI,[EBX+(CW*1)]  ;(IP) <- (PFA)
;        CALL    DISPLAYSI
;
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   ;   *
;  ********* 
;  
%if 1
        ENTRY_1    SEMI, 80H+1+40H, ";"+80H, DOCOL
%else
N_SEMI      DB   80H+1+40H
         DB     ";"+80H
         DD    N_COLON
SEMI      DD     DOCOL
%endif                           
        DD      QCSP
        DD      COMP
        DD      SEMIS
        DD      SMUDG
        DD      LBRAC
        DD      SEMIS
;

;  **************** 
;  *   CONSTANT   *
;  **************** 
;  
%if 1
        ENTRY    CON, 80H+8, "CONSTAN", "T"+80H, DOCOL
%else
N_CON      DB   80H+8
         DB      "CONSTAN"
         DB     "T"+80H
         DD    N_SEMI
CON      DD     DOCOL
%endif                           
        DD      CREAT
        DD      SMUDG
        DD      COMMA
        DD      PSCOD
DOCON:  MOV     EAX,[EBX+(CW*1)] ;GET DATA FROM PFA
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  **************** 
;  *   VARIABLE   *
;  **************** 
;  
%if 1
        ENTRY    VAR, 80H+8, "VARIABL", "E"+80H, DOCOL
%else
N_VAR      DB   80H+8
         DB      "VARIABL"
         DB     "E"+80H
         DD    N_CON
VAR      DD     DOCOL
%endif                           
        DD      CON
        DD      PSCOD
DOVAR:  LEA     EAX,[EBX+(CW*1)] ;(AX) <- PFA
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************ 
;  *   USER   *
;  ************ 
;  
%if 1
        ENTRY    USER, 80H+4, "USE", "R"+80H, DOCOL
%else
N_USER      DB   80H+4
         DB      "USE"
         DB     "R"+80H
         DD    N_VAR
USER      DD     DOCOL
%endif                           
        DD      CON
        DD      PSCOD
DOUSE:  MOV     EBX,[EBX+(CW*1)] ;PFA  
        MOV     EDI, DWORD PTR[USINI+(CW*1)]   ;USER VAR ADDRESS
        LEA     EAX,[EBX+EDI]      ;ADDR OF VARIABLE
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   0   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1    ZERO, 80H+1, "0"+80H
%else
N_ZERO      DB   80H+1
         DB     "0"+80H
         DD    N_USER
ZERO      DD     $+CW
%endif                           
        XOR     EAX,EAX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   1   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1    ONE, 80H+1, "1"+80H
%else
N_ONE      DB   80H+1
         DB     "1"+80H
         DD    N_ZERO
ONE      DD     $+CW
%endif                           
        MOV     EAX,1
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   2   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1    TWO, 80H+1, "2"+80H
%else
N_TWO      DB   80H+1
         DB     "2"+80H
         DD    N_ONE
TWO      DD     $+CW
%endif                           
        MOV     EAX,2
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********* 
;  *   3   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1    THREE, 80H+1, "3"+80H
%else
N_THREE      DB   80H+1
         DB     "3"+80H
         DD    N_TWO
THREE      DD     $+CW
%endif                           
        MOV     EAX,3
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
 ;  ********** 
;  *   BL   *
;  ********** 
;  
%if 1
        ENTRY    BLS, 80H+2, "B", "L"+80H, DOCON
%else
N_BLS      DB   80H+2
         DB      "B"
         DB     "L"+80H
         DD    N_THREE
BLS      DD     DOCON
%endif                           
; THIS IS ONLY A SPACE CHAR
    DD 20H
;

;  *********** 
;  *   C/L   *
;  *********** 
;  
%if 1
        ENTRY    CSLL, 80H+3, "C/", "L"+80H, DOCON
%else
N_CSLL      DB   80H+3
         DB      "C/"
         DB     "L"+80H
         DD    N_BLS
CSLL      DD     DOCON
%endif                           
        DD      64
;


;  ************* 
;  *   FIRST   *
;  ************* 
;  
%if 1
        ENTRY    FIRST, 80H+5, "FIRS", "T"+80H, DOCON
%else
N_FIRST      DB   80H+5
         DB      "FIRS"
         DB     "T"+80H
         DD    N_CSLL
FIRST      DD     DOCON
%endif                           
        DD      BUF1
 ;
;
;
;

;  ************* 
;  *   LIMIT   *
;  ************* 
;  
%if 1
        ENTRY    LIMIT, 80H+5, "LIMI", "T"+80H, DOCON
%else
N_LIMIT      DB   80H+5
         DB      "LIMI"
         DB     "T"+80H
         DD    N_FIRST
LIMIT      DD     DOCON
%endif                           
        DD      BUF1+(KBBUF+2*CW)*NBUF
; THE END  OF THE MEMORY 

;  ********** 
;  *   EM   *
;  ********** 
;  
%if 1
        ENTRY    LEM, 80H+2, "E", "M"+80H, DOCON
%else
N_LEM      DB   80H+2
         DB      "E"
         DB     "M"+80H
         DD    N_LIMIT
LEM      DD     DOCON
%endif                           
        DD      EM
;

;  ************* 
;  *   B/BUF   *
;  ************* 
;  
%if 1
        ENTRY    BBUF, 80H+5, "B/BU", "F"+80H, DOCON
%else
N_BBUF      DB   80H+5
         DB      "B/BU"
         DB     "F"+80H
         DD    N_LEM
BBUF      DD     DOCON
%endif                           
        DD      KBBUF
;

;  ************* 
;  *   B/SCR   *
;  ************* 
;  
%if 1
        ENTRY    BSCR, 80H+5, "B/SC", "R"+80H, DOCON
%else
N_BSCR      DB   80H+5
         DB      "B/SC"
         DB     "R"+80H
         DD    N_BBUF
BSCR      DD     DOCON
%endif                           
        DD      400H/KBBUF
;
        ;
;
; All user variables are initialised 
; with the values from USINI.
; The implementation relies on the initialisation of 
; those with numbers (1..11), so change in concord with USINI.

;  ********** 
;  *   U0   *
;  ********** 
;  
%if 1
        ENTRY    UZERO, 80H+2, "U", "0"+80H, DOUSE
%else
N_UZERO      DB   80H+2
         DB      "U"
         DB     "0"+80H
         DD    N_BSCR
UZERO      DD     DOUSE
%endif                           
        DD      (CW*1)
;

;  ************** 
;  *   RUBOUT   *
;  ************** 
;  
%if 1
        ENTRY    RUBOUT, 80H+6, "RUBOU", "T"+80H, DOUSE
%else
N_RUBOUT      DB   80H+6
         DB      "RUBOU"
         DB     "T"+80H
         DD    N_UZERO
RUBOUT      DD     DOUSE
%endif                           
        DD      (CW*2)
;

;  ********** 
;  *   S0   *
;  ********** 
;  
%if 1
        ENTRY    SZERO, 80H+2, "S", "0"+80H, DOUSE
%else
N_SZERO      DB   80H+2
         DB      "S"
         DB     "0"+80H
         DD    N_RUBOUT
SZERO      DD     DOUSE
%endif                           
        DD      (CW*3)
;

;  ********** 
;  *   R0   *
;  ********** 
;  
%if 1
        ENTRY    RZERO, 80H+2, "R", "0"+80H, DOUSE
%else
N_RZERO      DB   80H+2
         DB      "R"
         DB     "0"+80H
         DD    N_SZERO
RZERO      DD     DOUSE
%endif                           
        DD      (CW*4)
;

;  *********** 
;  *   TIB   *
;  *********** 
;  
%if 1
        ENTRY    TIB, 80H+3, "TI", "B"+80H, DOUSE
%else
N_TIB      DB   80H+3
         DB      "TI"
         DB     "B"+80H
         DD    N_RZERO
TIB      DD     DOUSE
%endif                           
        DD      (CW*5)
;

;  ************* 
;  *   WIDTH   *
;  ************* 
;  
%if 1
        ENTRY    WIDTHE, 80H+5, "WIDT", "H"+80H, DOUSE
%else
N_WIDTHE      DB   80H+5
         DB      "WIDT"
         DB     "H"+80H
         DD    N_TIB
WIDTHE      DD     DOUSE
%endif                           
        DD      (CW*6)
;

;  *************** 
;  *   WARNING   *
;  *************** 
;  
%if 1
        ENTRY    WARN, 80H+7, "WARNIN", "G"+80H, DOUSE
%else
N_WARN      DB   80H+7
         DB      "WARNIN"
         DB     "G"+80H
         DD    N_WIDTHE
WARN      DD     DOUSE
%endif                           
        DD      (CW*7)
;

;  ************* 
;  *   FENCE   *
;  ************* 
;  
%if 1
        ENTRY    FENCE, 80H+5, "FENC", "E"+80H, DOUSE
%else
N_FENCE      DB   80H+5
         DB      "FENC"
         DB     "E"+80H
         DD    N_WARN
FENCE      DD     DOUSE
%endif                           
        DD      (CW*8)
;

;  ********** 
;  *   DP   *
;  ********** 
;  
%if 1
        ENTRY    LDP, 80H+2, "D", "P"+80H, DOUSE
%else
N_LDP      DB   80H+2
         DB      "D"
         DB     "P"+80H
         DD    N_FENCE
LDP      DD     DOUSE
%endif                           
        DD      (CW*9)
;

;  **************** 
;  *   VOC-LINK   *
;  **************** 
;  
%if 1
        ENTRY    VOCL, 80H+8, "VOC-LIN", "K"+80H, DOUSE
%else
N_VOCL      DB   80H+8
         DB      "VOC-LIN"
         DB     "K"+80H
         DD    N_LDP
VOCL      DD     DOUSE
%endif                           
        DD      (CW*10)
;

;  ************** 
;  *   OFFSET   *
;  ************** 
;  
%if 1
        ENTRY    OFSET, 80H+6, "OFFSE", "T"+80H, DOUSE
%else
N_OFSET      DB   80H+6
         DB      "OFFSE"
         DB     "T"+80H
         DD    N_VOCL
OFSET      DD     DOUSE
%endif                           
        DD      (CW*11)
;
; End of user variables with fixed place.
;

;  *********** 
;  *   SCR   *
;  *********** 
;  
%if 1
        ENTRY    SCR, 80H+3, "SC", "R"+80H, DOUSE
%else
N_SCR      DB   80H+3
         DB      "SC"
         DB     "R"+80H
         DD    N_OFSET
SCR      DD     DOUSE
%endif                           
        DD      (CW*14)
;

;  *************** 
;  *   CONTEXT   *
;  *************** 
;  
%if 1
        ENTRY    CONT, 80H+7, "CONTEX", "T"+80H, DOUSE
%else
N_CONT      DB   80H+7
         DB      "CONTEX"
         DB     "T"+80H
         DD    N_SCR
CONT      DD     DOUSE
%endif                           
        DD      (CW*16)
;

;  *************** 
;  *   CURRENT   *
;  *************** 
;  
%if 1
        ENTRY    CURR, 80H+7, "CURREN", "T"+80H, DOUSE
%else
N_CURR      DB   80H+7
         DB      "CURREN"
         DB     "T"+80H
         DD    N_CONT
CURR      DD     DOUSE
%endif                           
        DD      (CW*17)
;

;  ************* 
;  *   STATE   *
;  ************* 
;  
%if 1
        ENTRY    STATE, 80H+5, "STAT", "E"+80H, DOUSE
%else
N_STATE      DB   80H+5
         DB      "STAT"
         DB     "E"+80H
         DD    N_CURR
STATE      DD     DOUSE
%endif                           
        DD      (CW*18)
;

;  ************ 
;  *   BASE   *
;  ************ 
;  
%if 1
        ENTRY    BASE, 80H+4, "BAS", "E"+80H, DOUSE
%else
N_BASE      DB   80H+4
         DB      "BAS"
         DB     "E"+80H
         DD    N_STATE
BASE      DD     DOUSE
%endif                           
        DD      (CW*19)
;

;  *********** 
;  *   DPL   *
;  *********** 
;  
%if 1
        ENTRY    DPL, 80H+3, "DP", "L"+80H, DOUSE
%else
N_DPL      DB   80H+3
         DB      "DP"
         DB     "L"+80H
         DD    N_BASE
DPL      DD     DOUSE
%endif                           
        DD      (CW*20)
;

;  *********** 
;  *   FLD   *
;  *********** 
;  
%if 1
        ENTRY    LFLD, 80H+3, "FL", "D"+80H, DOUSE
%else
N_LFLD      DB   80H+3
         DB      "FL"
         DB     "D"+80H
         DD    N_DPL
LFLD      DD     DOUSE
%endif                           
        DD      (CW*21)
;

;  *********** 
;  *   CSP   *
;  *********** 
;  
%if 1
        ENTRY    LCSP, 80H+3, "CS", "P"+80H, DOUSE
%else
N_LCSP      DB   80H+3
         DB      "CS"
         DB     "P"+80H
         DD    N_LFLD
LCSP      DD     DOUSE
%endif                           
        DD      (CW*22)
;

;  ********** 
;  *   R#   *
;  ********** 
;  
%if 1
        ENTRY    RNUM, 80H+2, "R", "#"+80H, DOUSE
%else
N_RNUM      DB   80H+2
         DB      "R"
         DB     "#"+80H
         DD    N_LCSP
RNUM      DD     DOUSE
%endif                           
        DD      (CW*23)
;

;  *********** 
;  *   HLD   *
;  *********** 
;  
%if 1
        ENTRY    HLD, 80H+3, "HL", "D"+80H, DOUSE
%else
N_HLD      DB   80H+3
         DB      "HL"
         DB     "D"+80H
         DD    N_RNUM
HLD      DD     DOUSE
%endif                           
        DD      (CW*24)
;

;  ********** 
;  *   IN   *
;  ********** 
;  
%if 1
        ENTRY    LIN, 80H+2, "I", "N"+80H, DOUSE
%else
N_LIN      DB   80H+2
         DB      "I"
         DB     "N"+80H
         DD    N_HLD
LIN      DD     DOUSE
%endif                           
        DD      (CW*25)
;

;  *********** 
;  *   OUT   *
;  *********** 
;  
%if 1
        ENTRY    LOUT, 80H+3, "OU", "T"+80H, DOUSE
%else
N_LOUT      DB   80H+3
         DB      "OU"
         DB     "T"+80H
         DD    N_LIN
LOUT      DD     DOUSE
%endif                           
        DD      (CW*26)
;

;  *********** 
;  *   BLK   *
;  *********** 
;  
%if 1
        ENTRY    BLK, 80H+3, "BL", "K"+80H, DOUSE
%else
N_BLK      DB   80H+3
         DB      "BL"
         DB     "K"+80H
         DD    N_LOUT
BLK      DD     DOUSE
%endif                           
        DD      (CW*27)
;
;========== END USER VARIABLES =============;
;

;  ********** 
;  *   1+   *
;  ********** 
;  
%if 1
        CODE_ENTRY    ONEP, 80H+2, "1", "+"+80H
%else
N_ONEP      DB   80H+2
         DB      "1"
         DB     "+"+80H
         DD    N_BLK
ONEP      DD     $+CW
%endif                           
        POP     EAX
        INC     EAX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   2+   *
;  ********** 
;  
%if 1
        CODE_ENTRY    TWOP, 80H+2, "2", "+"+80H
%else
N_TWOP      DB   80H+2
         DB      "2"
         DB     "+"+80H
         DD    N_ONEP
TWOP      DD     $+CW
%endif                           
        POP     EAX
        ADD     EAX,2
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************* 
;  *   CELL+   *
;  ************* 
;  
%if 1
        CODE_ENTRY    CELLP, 80H+5, "CELL", "+"+80H
%else
N_CELLP      DB   80H+5
         DB      "CELL"
         DB     "+"+80H
         DD    N_TWOP
CELLP      DD     $+CW
%endif                           
        POP     EAX
        ADD     EAX,CW
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************ 
;  *   HERE   *
;  ************ 
;  
%if 1
        ENTRY    HERE, 80H+4, "HER", "E"+80H, DOCOL
%else
N_HERE      DB   80H+4
         DB      "HER"
         DB     "E"+80H
         DD    N_CELLP
HERE      DD     DOCOL
%endif                           
        DD      LDP
        DD      FETCH
        DD      SEMIS
;

;  ************* 
;  *   ALLOT   *
;  ************* 
;  
%if 1
        ENTRY    ALLOT, 80H+5, "ALLO", "T"+80H, DOCOL
%else
N_ALLOT      DB   80H+5
         DB      "ALLO"
         DB     "T"+80H
         DD    N_HERE
ALLOT      DD     DOCOL
%endif                           
        DD      LDP
        DD      PSTOR
        DD      SEMIS
;

;  ********* 
;  *   ,   *
;  ********* 
;  
%if 1
        ENTRY_1    COMMA, 80H+1, ","+80H, DOCOL
%else
N_COMMA      DB   80H+1
         DB     ","+80H
         DD    N_ALLOT
COMMA      DD     DOCOL
%endif                           
        DD      HERE
        DD      STORE
        DD      LIT, CW
        DD      ALLOT
        DD      SEMIS
;

;  ********** 
;  *   C,   *
;  ********** 
;  
%if 1
        ENTRY    CCOMM, 80H+2, "C", ","+80H, DOCOL
%else
N_CCOMM      DB   80H+2
         DB      "C"
         DB     ","+80H
         DD    N_COMMA
CCOMM      DD     DOCOL
%endif                           
        DD      HERE
        DD      CSTOR
        DD      ONE
        DD      ALLOT
        DD      SEMIS
;

;  ********* 
;  *   -   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1    LSUB, 80H+1, "-"+80H
%else
N_LSUB      DB   80H+1
         DB     "-"+80H
         DD    N_CCOMM
LSUB      DD     $+CW
%endif                           
        POP     EDX      ;S1
        POP     EAX
        SUB     EAX,EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]      ;S1 = S2 - S1
;

;  ********* 
;  *   =   *
;  ********* 
;  
%if 1
        ENTRY_1    EQUAL, 80H+1, "="+80H, DOCOL
%else
N_EQUAL      DB   80H+1
         DB     "="+80H
         DD    N_LSUB
EQUAL      DD     DOCOL
%endif                           
        DD      LSUB
        DD      ZEQU
        DD      SEMIS
;

;  ********* 
;  *   <   *
;  ********* 
;  
%if 1
        CODE_ENTRY_1    LESS, 80H+1, "<"+80H
%else
N_LESS      DB   80H+1
         DB     "<"+80H
         DD    N_EQUAL
LESS      DD     $+CW
%endif                           
        POP     EDX      ;S1
        POP     EAX      ;S2
        MOV     EBX,EDX
        XOR     EBX,EAX   ;TEST FOR EQUAL SIGNS
        JS      LES1    ;SIGNS ARE NOT THE SAME
        SUB     EAX,EDX
LES1:   OR      EAX,EAX   ;TEST SIGN BIT
        MOV     EAX,0    ;ASSUME FALSE
        JNS     LES2    ;NOT LESS THAN
        INC     EAX      ;TRUE (1)
LES2:   PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   U<   *
;  ********** 
;  
%if 1
        ENTRY    ULESS, 80H+2, "U", "<"+80H, DOCOL
%else
N_ULESS      DB   80H+2
         DB      "U"
         DB     "<"+80H
         DD    N_LESS
ULESS      DD     DOCOL
%endif                           
        DD      TDUP
        DD      LXOR,ZLESS
        DD      ZBRAN
        DD      ULES1-$ ;IF
        DD      DROP,ZLESS
        DD      ZEQU
        DD      BRAN
        DD      ULES2-$
ULES1      DD      LSUB,ZLESS      ;ELSE
ULES2      DD      SEMIS           ;ENDIF
;

;  ********* 
;  *   >   *
;  ********* 
;  
%if 1
        ENTRY_1    GREAT, 80H+1, ">"+80H, DOCOL
%else
N_GREAT      DB   80H+1
         DB     ">"+80H
         DD    N_ULESS
GREAT      DD     DOCOL
%endif                           
        DD      SWAP
        DD      LESS
        DD      SEMIS
;

;  *********** 
;  *   ROT   *
;  *********** 
;  
%if 1
        CODE_ENTRY    ROT, 80H+3, "RO", "T"+80H
%else
N_ROT      DB   80H+3
         DB      "RO"
         DB     "T"+80H
         DD    N_GREAT
ROT      DD     $+CW
%endif                           
        POP     EDX      ;S1
        POP     EBX      ;S2
        POP     EAX      ;S3
        PUSH    EBX
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************* 
;  *   SPACE   *
;  ************* 
;  
%if 1
        ENTRY    SPACE, 80H+5, "SPAC", "E"+80H, DOCOL
%else
N_SPACE      DB   80H+5
         DB      "SPAC"
         DB     "E"+80H
         DD    N_ROT
SPACE      DD     DOCOL
%endif                           
        DD      BLS
        DD      EMIT
        DD      SEMIS
;

;  ************ 
;  *   -DUP   *
;  ************ 
;  
%if 1
        ENTRY    DDUP, 80H+4, "-DU", "P"+80H, DOCOL
%else
N_DDUP      DB   80H+4
         DB      "-DU"
         DB     "P"+80H
         DD    N_SPACE
DDUP      DD     DOCOL
%endif                           
        DD      LDUP
        DD      ZBRAN
        DD      DDUP1-$ ; IF
        DD      LDUP    ;ENDIF
DDUP1      DD      SEMIS
;

;  **************** 
;  *   TRAVERSE   *
;  **************** 
;  
%if 1
        ENTRY    TRAV, 80H+8, "TRAVERS", "E"+80H, DOCOL
%else
N_TRAV      DB   80H+8
         DB      "TRAVERS"
         DB     "E"+80H
         DD    N_DDUP
TRAV      DD     DOCOL
%endif                           
        DD      SWAP
TRAV1      DD      OVER    ;BEGIN
        DD      PLUS
        DD      LIT,7FH
        DD      OVER
        DD      CFET
        DD      LESS
        DD      ZBRAN
        DD      TRAV1-$ ;UNTIL
        DD      SWAP
        DD      DROP
        DD      SEMIS
;

;  ************** 
;  *   LATEST   *
;  ************** 
;  
%if 1
        ENTRY    LATES, 80H+6, "LATES", "T"+80H, DOCOL
%else
N_LATES      DB   80H+6
         DB      "LATES"
         DB     "T"+80H
         DD    N_TRAV
LATES      DD     DOCOL
%endif                           
        DD      CURR
        DD      FETCH
        DD      FETCH
        DD      SEMIS
;

;  *********** 
;  *   LFA   *
;  *********** 
;  
%if 1
        ENTRY    LFA, 80H+3, "LF", "A"+80H, DOCOL
%else
N_LFA      DB   80H+3
         DB      "LF"
         DB     "A"+80H
         DD    N_LATES
LFA      DD     DOCOL
%endif                           
        DD      LIT,(CW*2)
        DD      LSUB
        DD      SEMIS
;

;  *********** 
;  *   CFA   *
;  *********** 
;  
%if 1
        ENTRY    CFA, 80H+3, "CF", "A"+80H, DOCOL
%else
N_CFA      DB   80H+3
         DB      "CF"
         DB     "A"+80H
         DD    N_LFA
CFA      DD     DOCOL
%endif                           
        DD      LIT, CW
        DD      LSUB
        DD      SEMIS
;

;  *********** 
;  *   NFA   *
;  *********** 
;  
%if 1
        ENTRY    NFA, 80H+3, "NF", "A"+80H, DOCOL
%else
N_NFA      DB   80H+3
         DB      "NF"
         DB     "A"+80H
         DD    N_CFA
NFA      DD     DOCOL
%endif                           
        DD      LIT,1+(CW*2)
        DD      LSUB
        DD      LIT,-1
        DD      TRAV
        DD      SEMIS
;

;  *********** 
;  *   PFA   *
;  *********** 
;  
%if 1
        ENTRY    PFA, 80H+3, "PF", "A"+80H, DOCOL
%else
N_PFA      DB   80H+3
         DB      "PF"
         DB     "A"+80H
         DD    N_NFA
PFA      DD     DOCOL
%endif                           
        DD      ONE
        DD      TRAV
        DD      LIT,1+(CW*2)
        DD      PLUS
        DD      SEMIS
        ;
        ; At line     LINE ~1500


;  ************ 
;  *   !CSP   *
;  ************ 
;  
%if 1
        ENTRY    SCSP, 80H+4, "!CS", "P"+80H, DOCOL
%else
N_SCSP      DB   80H+4
         DB      "!CS"
         DB     "P"+80H
         DD    N_PFA
SCSP      DD     DOCOL
%endif                           
        DD      SPFET
        DD      LCSP
        DD      STORE
        DD      SEMIS
;

;  ************** 
;  *   ?ERROR   *
;  ************** 
;  
%if 1
        ENTRY    QERR, 80H+6, "?ERRO", "R"+80H, DOCOL
%else
N_QERR      DB   80H+6
         DB      "?ERRO"
         DB     "R"+80H
         DD    N_SCSP
QERR      DD     DOCOL
%endif                           
        DD      SWAP
        DD      ZBRAN
        DD      QERR1-$ ;IF
        DD      ERROR
        DD      BRAN
        DD      QERR2-$  ;ELSE
QERR1      DD      DROP    ;ENDIF
QERR2      DD      SEMIS
;

;  ************* 
;  *   ?COMP   *
;  ************* 
;  
%if 1
        ENTRY    QCOMP, 80H+5, "?COM", "P"+80H, DOCOL
%else
N_QCOMP      DB   80H+5
         DB      "?COM"
         DB     "P"+80H
         DD    N_QERR
QCOMP      DD     DOCOL
%endif                           
        DD      STATE
        DD      FETCH
        DD      ZEQU
        DD      LIT,11H
        DD      QERR
        DD      SEMIS
;

;  ************* 
;  *   ?EXEC   *
;  ************* 
;  
%if 1
        ENTRY    QEXEC, 80H+5, "?EXE", "C"+80H, DOCOL
%else
N_QEXEC      DB   80H+5
         DB      "?EXE"
         DB     "C"+80H
         DD    N_QCOMP
QEXEC      DD     DOCOL
%endif                           
        DD      STATE
        DD      FETCH
        DD      LIT,12H
        DD      QERR
        DD      SEMIS
;

;  ************** 
;  *   ?PAIRS   *
;  ************** 
;  
%if 1
        ENTRY    QPAIR, 80H+6, "?PAIR", "S"+80H, DOCOL
%else
N_QPAIR      DB   80H+6
         DB      "?PAIR"
         DB     "S"+80H
         DD    N_QEXEC
QPAIR      DD     DOCOL
%endif                           
        DD      LSUB
        DD      LIT,13H
        DD      QERR
        DD      SEMIS
;

;  ************ 
;  *   ?CSP   *
;  ************ 
;  
%if 1
        ENTRY    QCSP, 80H+4, "?CS", "P"+80H, DOCOL
%else
N_QCSP      DB   80H+4
         DB      "?CS"
         DB     "P"+80H
         DD    N_QPAIR
QCSP      DD     DOCOL
%endif                           
        DD      SPFET
        DD      LCSP
        DD      FETCH
        DD      LSUB
        DD      LIT,14H
        DD      QERR
        DD      SEMIS
;

;  **************** 
;  *   ?LOADING   *
;  **************** 
;  
%if 1
        ENTRY    QLOAD, 80H+8, "?LOADIN", "G"+80H, DOCOL
%else
N_QLOAD      DB   80H+8
         DB      "?LOADIN"
         DB     "G"+80H
         DD    N_QCSP
QLOAD      DD     DOCOL
%endif                           
        DD      BLK
        DD      FETCH
        DD      ZEQU
        DD      LIT,16H
        DD      QERR
        DD      SEMIS
;

;  *************** 
;  *   COMPILE   *
;  *************** 
;  
%if 1
        ENTRY    COMP, 80H+7, "COMPIL", "E"+80H, DOCOL
%else
N_COMP      DB   80H+7
         DB      "COMPIL"
         DB     "E"+80H
         DD    N_QLOAD
COMP      DD     DOCOL
%endif                           
        DD      QCOMP
        DD      FROMR
        DD      LDUP
        DD      CELLP
        DD      TOR
        DD      FETCH
        DD      COMMA
        DD      SEMIS
;

;  ********* 
;  *   [   *
;  ********* 
;  
%if 1
        ENTRY_1    LBRAC, 80H+1+40H, "["+80H, DOCOL
%else
N_LBRAC      DB   80H+1+40H
         DB     "["+80H
         DD    N_COMP
LBRAC      DD     DOCOL
%endif                           
        DD      ZERO
        DD      STATE
        DD      STORE
        DD      SEMIS
;

;  ********* 
;  *   ]   *
;  ********* 
;  
%if 1
        ENTRY_1    RBRAC, 80H+1, "]"+80H, DOCOL
%else
N_RBRAC      DB   80H+1
         DB     "]"+80H
         DD    N_LBRAC
RBRAC      DD     DOCOL
%endif                           
        DD      LIT,0C0H
        DD      STATE
        DD      STORE
        DD      SEMIS
;

;  ************** 
;  *   SMUDGE   *
;  ************** 
;  
%if 1
        ENTRY    SMUDG, 80H+6, "SMUDG", "E"+80H, DOCOL
%else
N_SMUDG      DB   80H+6
         DB      "SMUDG"
         DB     "E"+80H
         DD    N_RBRAC
SMUDG      DD     DOCOL
%endif                           
        DD      LATES
        DD      LIT,20H
        DD      TOGGL
        DD      SEMIS
;

;  *********** 
;  *   HEX   *
;  *********** 
;  
%if 1
        ENTRY    HEX, 80H+3, "HE", "X"+80H, DOCOL
%else
N_HEX      DB   80H+3
         DB      "HE"
         DB     "X"+80H
         DD    N_SMUDG
HEX      DD     DOCOL
%endif                           
        DD      LIT,16
        DD      BASE
        DD      STORE
        DD      SEMIS
;

;  *************** 
;  *   DECIMAL   *
;  *************** 
;  
%if 1
        ENTRY    DECA, 80H+7, "DECIMA", "L"+80H, DOCOL
%else
N_DECA      DB   80H+7
         DB      "DECIMA"
         DB     "L"+80H
         DD    N_HEX
DECA      DD     DOCOL
%endif                           
        DD      LIT,10
        DD      BASE
        DD      STORE
        DD      SEMIS
;

;  *************** 
;  *   (;CODE)   *
;  *************** 
;  
%if 1
        ENTRY    PSCOD, 80H+7, "(;CODE", ")"+80H, DOCOL
%else
N_PSCOD      DB   80H+7
         DB      "(;CODE"
         DB     ")"+80H
         DD    N_DECA
PSCOD      DD     DOCOL
%endif                           
        DD      FROMR
        DD      LATES
        DD      PFA
        DD      CFA
        DD      STORE
        DD      SEMIS
;

;  ************* 
;  *   ;CODE   *
;  ************* 
;  
%if 1
        ENTRY    SEMIC, 80H+5+40H, ";COD", "E"+80H, DOCOL
%else
N_SEMIC      DB   80H+5+40H
         DB      ";COD"
         DB     "E"+80H
         DD    N_PSCOD
SEMIC      DD     DOCOL
%endif                           
        DD      QCSP
        DD      COMP
        DD      PSCOD
        DD      LBRAC
SEMI1      DD      NOOP    ; The code field of ASSEMBLER must be patched here. 
        DD      SEMIS
;

;  *************** 
;  *   <BUILDS   *
;  *************** 
;  
%if 1
        ENTRY    BUILD, 80H+7, "<BUILD", "S"+80H, DOCOL
%else
N_BUILD      DB   80H+7
         DB      "<BUILD"
         DB     "S"+80H
         DD    N_SEMIC
BUILD      DD     DOCOL
%endif                           
        DD      ZERO
        DD      CON
        DD      SEMIS
;

;  ************* 
;  *   DOES>   *
;  ************* 
;  
%if 1
        ENTRY    DOES, 80H+5, "DOES", ">"+80H, DOCOL
%else
N_DOES      DB   80H+5
         DB      "DOES"
         DB     ">"+80H
         DD    N_BUILD
DOES      DD     DOCOL
%endif                           
        DD      FROMR
        DD      LATES
        DD      PFA
        DD      STORE
        DD      PSCOD
DODOE:  LEA     EBP,[EBP-(CW*1)]
        MOV     [EBP],ESI ;R1 <- (IP)
        MOV     ESI,[EBX+(CW*1)] ;NEW IP 
        LEA     EAX,[EBX+2*(CW*1)]
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************* 
;  *   COUNT   *
;  ************* 
;  
%if 1
        ENTRY    COUNT, 80H+5, "COUN", "T"+80H, DOCOL
%else
N_COUNT      DB   80H+5
         DB      "COUN"
         DB     "T"+80H
         DD    N_DOES
COUNT      DD     DOCOL
%endif                           
        DD      LDUP
        DD      ONEP
        DD      SWAP
        DD      CFET
        DD      SEMIS
;

;  ***************** 
;  *   -TRAILING   *
;  ***************** 
;  
%if 1
        ENTRY    DTRAI, 80H+9, "-TRAILIN", "G"+80H, DOCOL
%else
N_DTRAI      DB   80H+9
         DB      "-TRAILIN"
         DB     "G"+80H
         DD    N_COUNT
DTRAI      DD     DOCOL
%endif                           
        DD      LDUP
        DD      ZERO
        DD      XDO     ;DO
DTRA1      DD      OVER
        DD      OVER
        DD      PLUS
        DD      ONE
        DD      LSUB
        DD      CFET
        DD      BLS
        DD      LSUB
        DD      ZBRAN
        DD      DTRA2-$ ;IF
        DD      LLEAV
        DD      BRAN
        DD      DTRA3-$  ; ELSE
DTRA2      DD      ONE
        DD      LSUB    ; ENDIF
DTRA3      DD      XLOOP
        DD      DTRA1-$    ; LOOP
        DD      SEMIS
        ;
        ; At line     LINE ~2000


;  ************ 
;  *   (.")   *
;  ************ 
;  TODO: Checkthat this string works with a diuble-quote in it.
%if 1
        ENTRY    PDOTQ, 80H+4, '(."', ")"+80H, DOCOL
%else
N_PDOTQ      DB   80H+4
         DB      '(."'
         DB     ')'+80H
        DD    N_DTRAI
PDOTQ      DD     DOCOL
%endif                        
        DD      RR
        DD      COUNT
        DD      LDUP
        DD      ONEP
        DD      FROMR
        DD      PLUS
        DD      TOR
        DD      LTYPE
        DD      SEMIS
;


;  ********** 
;  *   ."   *
;  ********** 
;  
%if 1
        ENTRY    DOTQ, 80H+2+40H, '.', '"'+80H, DOCOL
%else
N_DOTQ      DB   80H+2+40H
         DB      '.'
         DB     '"'+80H
        DD    N_PDOTQ
DOTQ      DD     DOCOL
%endif                        
        DD      LIT,22H
        DD      STATE
        DD      FETCH
        DD      ZBRAN
        DD      DOTQ1-$ ; IF
        DD      COMP
        DD      PDOTQ
        DD      LWORD
        DD      HERE
        DD      CFET
        DD      ONEP
        DD      ALLOT
        DD      BRAN
        DD      DOTQ2-$  ; ELSE
DOTQ1      DD      LWORD
        DD      HERE
        DD      COUNT
        DD      LTYPE   ; ENDIF
DOTQ2      DD      SEMIS
;

;  ************* 
;  *   QUERY   *
;  ************* 
;  
%if 1
        ENTRY    QUERY, 80H+5, "QUER", "Y"+80H, DOCOL
%else
N_QUERY      DB   80H+5
         DB      "QUER"
         DB     "Y"+80H
         DD    N_DOTQ
QUERY      DD     DOCOL
%endif                           
        DD      TIB
        DD      FETCH
        DD      LIT,RTS/2
        DD      EXPEC
        DD      ZERO
        DD      LIN
        DD      STORE
        DD      SEMIS
;

; The macro might struggle with this one...
%if 1
        ENTRY_1    NULL, 80H+1+40H, 80H, DOCOL
%else

N_NULL      DB      0C1H,80H
                DD      N_QUERY
NULL      DD      DOCOL
%endif
;       Special header putting an ASCII NULL in the dictionary.
        DD      BLK
        DD      FETCH
        DD      ZBRAN
        DD      NULL1-$ ; IF
        DD      ONE
        DD      BLK
        DD      PSTOR
        DD      ZERO
        DD      LIN
        DD      STORE
        DD      BLK
        DD      FETCH
        DD      BSCR
        DD      ONE
        DD      LSUB
        DD      LAND
        DD      ZEQU
        DD      ZBRAN
        DD      NULL2-$ ; IF
        DD      QEXEC
        DD      FROMR
        DD      DROP    ; ENDIF
NULL2      DD      BRAN
        DD      NULL3-$  ; ELSE
NULL1      DD      FROMR
        DD      DROP    ; ENDIF
NULL3      DD      SEMIS
;

;  ************ 
;  *   FILL   *
;  ************ 
;  
%if 1
        CODE_ENTRY    FILL, 80H+4, "FIL", "L"+80H
%else
N_FILL      DB   80H+4
         DB      "FIL"
         DB     "L"+80H
         DD    N_NULL
FILL      DD     $+CW
%endif                           
        POP     EAX      ; FILL CHAR
        POP     ECX      ; FILL COUNT
        POP     EDI      ; BEGIN ADDR
;       MOV    BX,DS
;       MOV    ES,BX   ; ES <- DS
        CLD             ; INC DIRECTION
        REP     STOSB   ;STORE BYTE
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ************* 
;  *   ERASE   *
;  ************* 
;  
N_LERASE      DB   80H+5
         DB      "ERAS"
         DB     "E"+80H
         DD    N_FILL
LERASE      DD     DOCOL
                           
        DD      ZERO
        DD      FILL
        DD      SEMIS
;

;  ************** 
;  *   BLANKS   *
;  ************** 
;  
N_BLANK      DB   80H+6
         DB      "BLANK"
         DB     "S"+80H
         DD    N_LERASE
BLANK      DD     DOCOL
                           
        DD      BLS
        DD      FILL
        DD      SEMIS
;

;  ************ 
;  *   HOLD   *
;  ************ 
;  
N_HOLD      DB   80H+4
         DB      "HOL"
         DB     "D"+80H
         DD    N_BLANK
HOLD      DD     DOCOL
                           
        DD      LIT,-1
        DD      HLD
        DD      PSTOR
        DD      HLD
        DD      FETCH
        DD      CSTOR
        DD      SEMIS
;

;  *********** 
;  *   PAD   *
;  *********** 
;  
N_PAD      DB   80H+3
         DB      "PA"
         DB     "D"+80H
         DD    N_HOLD
PAD      DD     DOCOL
                           
        DD      HERE
        DD      LIT,84
        DD      PLUS
        DD      SEMIS
;

;  ************ 
;  *   WORD   *
;  ************ 
;  
N_LWORD      DB   80H+4
         DB      "WOR"
         DB     "D"+80H
         DD    N_PAD
LWORD      DD     DOCOL
                           
        DD      BLK
        DD      FETCH
        DD      ZBRAN
        DD      WORD1-$ ; IF
        DD      BLK
        DD      FETCH
        DD      BLOCK
        DD      BRAN
        DD      WORD2-$  ; ELSE
WORD1      DD      TIB
        DD      FETCH      ; ENDIF
WORD2      DD      LIN
        DD      FETCH
        DD      PLUS
        DD      SWAP
        DD      ENCL
        DD      HERE
        DD      LIT,22H
        DD      BLANK
        DD      LIN
        DD      PSTOR
        DD      OVER
        DD      LSUB
        DD      TOR
        DD      RR
        DD      HERE
        DD      CSTOR
        DD      PLUS
        DD      HERE
        DD      ONEP
        DD      FROMR
        DD      LCMOVE
        DD      SEMIS
;

;  **************** 
;  *   (NUMBER)   *
;  **************** 
;  
N_PNUMB      DB   80H+8
         DB      "(NUMBER"
         DB     ")"+80H
         DD    N_LWORD
PNUMB      DD     DOCOL
                           
PNUM1      DD      ONEP    ; BEGIN
        DD      LDUP
        DD      TOR
        DD      CFET
        DD      BASE
        DD      FETCH
        DD      DIGIT
        DD      ZBRAN
        DD      PNUM2-$ ; WHILE
        DD      SWAP
        DD      BASE
        DD      FETCH
        DD      USTAR
        DD      DROP
        DD      ROT
        DD      BASE
        DD      FETCH
        DD      USTAR
        DD      DPLUS
        DD      DPL
        DD      FETCH
        DD      ONEP
        DD      ZBRAN
        DD      PNUM3-$ ; IF
        DD      ONE
        DD      DPL
        DD      PSTOR   ; ENDIF
PNUM3      DD      FROMR
        DD      BRAN
        DD      PNUM1-$  ; REPEAT
PNUM2      DD      FROMR
        DD      SEMIS
;

;  ************** 
;  *   NUMBER   *
;  ************** 
;  
N_NUMB      DB   80H+6
         DB      "NUMBE"
         DB     "R"+80H
         DD    N_PNUMB
NUMB      DD     DOCOL
                           
        DD      ZERO
        DD      ZERO
        DD      ROT
        DD      LDUP
        DD      ONEP
        DD      CFET
        DD      LIT,2DH
        DD      EQUAL
        DD      LDUP
        DD      TOR
        DD      PLUS
        DD      LIT,-1
NUMB1      DD      DPL     ; BEGIN
        DD      STORE
        DD      PNUMB
        DD      LDUP
        DD      CFET
        DD      BLS
        DD      LSUB
        DD      ZBRAN
        DD      NUMB2-$ ; WHILE
        DD      LDUP
        DD      CFET
        DD      LIT,2EH
        DD      LSUB
        DD      ZERO
        DD      QERR
        DD      ZERO
        DD      BRAN
        DD      NUMB1-$  ; REPEAT
NUMB2      DD      DROP
        DD      FROMR
        DD      ZBRAN
        DD      NUMB3-$ ; IF
        DD      DMINU   ; ENDIF
NUMB3      DD      SEMIS
;

;  ************* 
;  *   -FIND   *
;  ************* 
;  
N_DFIND      DB   80H+5
         DB      "-FIN"
         DB     "D"+80H
         DD    N_NUMB
DFIND      DD     DOCOL
                           
        DD      BLS
        DD      LWORD
        DD      HERE
        DD      CONT
        DD      FETCH
        DD      FETCH
        DD      PFIND
        DD      LDUP
        DD      ZEQU
        DD      ZBRAN
        DD      DFIN1-$ ;IF
        DD      DROP
        DD      HERE
        DD      LATES
        DD      PFIND   ;ENDIF
DFIN1      DD      SEMIS
;

;  *************** 
;  *   (ABORT)   *
;  *************** 
;  
N_PABOR      DB   80H+7
         DB      "(ABORT"
         DB     ")"+80H
         DD    N_DFIND
PABOR      DD     DOCOL
                           
        DD      ABORT
        DD      SEMIS
;

;  ************* 
;  *   ERROR   *
;  ************* 
;  
N_ERROR      DB   80H+5
         DB      "ERRO"
         DB     "R"+80H
         DD    N_PABOR
ERROR      DD     DOCOL
                           
        DD      WARN
        DD      FETCH
        DD      ZLESS
        DD      ZBRAN
        DD      ERRO1-$ ;IF
        DD      PABOR   ;ENDIF
ERRO1      DD      HERE
        DD      COUNT
        DD      LTYPE
        DD      PDOTQ
        
        DB      2
        DB      "? "
        DD      MESS
        DD      SPSTO
;
;      CHANGE FROM FIG MODEL
;      DC LIN,FETCH,BLK,FETCH
;
        DD      BLK,FETCH
        DD      DDUP
        DD      ZBRAN
        DD      ERRO2-$ ; IF
        DD      LIN,FETCH
        DD      SWAP    ;ENDIF
ERRO2      DD      QUIT
;

;  *********** 
;  *   ID.   *
;  *********** 
;  
N_IDDOT      DB   80H+3
         DB      "ID"
         DB     "."+80H
         DD    N_ERROR
IDDOT      DD     DOCOL
                           
        DD      COUNT
        DD      LIT,1FH
        DD      LAND
        DD      ONE
        DD      LSUB
        DD      TDUP
        DD      LTYPE
        DD      PLUS
        DD      CFET
        DD      LIT,07FH
        DD      LAND
        DD      EMIT
        DD      SPACE
        DD      SPACE
        DD      SPACE
        DD      SEMIS
;

;  ************** 
;  *   CREATE   *
;  ************** 
;  
N_CREAT      DB   80H+6
         DB      "CREAT"
         DB     "E"+80H
         DD    N_IDDOT
CREAT      DD     DOCOL
                           
        DD      DFIND
        DD      HERE
        DD      ONEP
        DD      CFET
        DD      ZEQU
        DD      LIT,5
        DD      QERR
        DD      ZBRAN
        DD      CREA1-$ ;IF
        DD      DROP
        DD      NFA
        DD      IDDOT
        DD      LIT,4
        DD      MESS
        DD      SPACE   ;ENDIF
CREA1      DD      HERE
        DD      LDUP
        DD      CFET
        DD      WIDTHE
        DD      FETCH
        DD      MIN
        DD      ONEP
        DD      ALLOT
        DD      LDUP
        DD      LIT,0A0H
        DD      TOGGL
        DD      HERE
        DD      ONE
        DD      LSUB
        DD      LIT,80H
        DD      TOGGL
        DD      LATES
        DD      COMMA
        DD      CURR
        DD      FETCH
        DD      STORE
        DD      HERE
        DD      CELLP
        DD      COMMA
        DD      SEMIS
        ;

;  ***************** 
;  *   [COMPILE]   *
;  ***************** 
;  
N_BCOMP      DB   80H+9+40H
         DB      "[COMPILE"
         DB     "]"+80H
         DD    N_CREAT
BCOMP      DD     DOCOL
                           
        DD      DFIND
        DD      ZEQU
        DD      ZERO
        DD      QERR
        DD      DROP
        DD      CFA
        DD      COMMA
        DD      SEMIS
;

;  *************** 
;  *   LITERAL   *
;  *************** 
;  
N_LITER      DB   80H+7+40H
         DB      "LITERA"
         DB     "L"+80H
         DD    N_BCOMP
LITER      DD     DOCOL
                           
        DD      STATE
        DD      FETCH
        DD      ZBRAN
        DD      LITE1-$ ;IF
        DD      COMP
        DD      LIT
        DD      COMMA   ;ENDIF
LITE1      DD      SEMIS
        ;
;

;  **************** 
;  *   DLITERAL   *
;  **************** 
;  
N_DLITE      DB   80H+8+40H
         DB      "DLITERA"
         DB     "L"+80H
         DD    N_LITER
DLITE      DD     DOCOL
                           
        DD      STATE
        DD      FETCH
        DD      ZBRAN
        DD      DLIT1-$ ; IF
        DD      SWAP
        DD      LITER
        DD      LITER   ; ENDIF
DLIT1      DD      SEMIS
;

;  ************** 
;  *   ?STACK   *
;  ************** 
;  
N_QSTAC      DB   80H+6
         DB      "?STAC"
         DB     "K"+80H
         DD    N_DLITE
QSTAC      DD     DOCOL
                           
        DD      SPFET
        DD      SZERO
        DD      FETCH
        DD      SWAP
        DD      ULESS
        DD      ONE
        DD      QERR
        DD      SPFET
        DD      HERE
        DD      LIT,80H
        DD      PLUS
        DD      ULESS
        DD      LIT,7
        DD      QERR
        DD      SEMIS
        ;
;

;  ***************** 
;  *   INTERPRET   *
;  ***************** 
;  
N_INTER      DB   80H+9
         DB      "INTERPRE"
         DB     "T"+80H
         DD    N_QSTAC
INTER      DD     DOCOL
                           
INTE1      DD      DFIND   ;BEGIN
        DD      ZBRAN
        DD      INTE2-$ ;IF
        DD      STATE
        DD      FETCH
        DD      LESS
        DD      ZBRAN
        DD      INTE3-$ ;IF
        DD      CFA
        DD      COMMA
        DD      BRAN
        DD      INTE4-$  ;ELSE
INTE3      DD      CFA
        DD      EXEC    ;ENDIF
INTE4      DD      QSTAC
        DD      BRAN
        DD      INTE5-$  ;ELSE
INTE2      DD      HERE
        DD      NUMB
        DD      DPL
        DD      FETCH
        DD      ONEP
        DD      ZBRAN
        DD      INTE6-$ ;IF
        DD      DLITE
        DD      BRAN
        DD      INTE7-$  ;ELSE
INTE6      DD      DROP
        DD      LITER   ;ENDIF
INTE7      DD      QSTAC   ;ENDIF
INTE5      DD      BRAN
        DD      INTE1-$  ;AGAIN
;

;  ***************** 
;  *   IMMEDIATE   *
;  ***************** 
;  
N_IMMED      DB   80H+9
         DB      "IMMEDIAT"
         DB     "E"+80H
         DD    N_INTER
IMMED      DD     DOCOL
                           
        DD      LATES
        DD      LIT,40H
        DD      TOGGL
        DD      SEMIS
;

;  ****************** 
;  *   VOCABULARY   *
;  ****************** 
;  
N_VOCAB      DB   80H+10
         DB      "VOCABULAR"
         DB     "Y"+80H
         DD    N_IMMED
VOCAB      DD     DOCOL
                           
        DD      BUILD
        DD      LIT, 80H+1, CCOMM    ; Dummy name field
        DD      LIT, " "+80H, CCOMM
        DD      CURR
        DD      FETCH
        DD      LIT, 2, LSUB ; Skip backwards over dummy name field.
        DD      COMMA    ; DLFA points to NFA of CURRENT
        DD      HERE
        DD      VOCL
        DD      FETCH
        DD      COMMA    ; VLFA points to VLFA of previous VOC-LINK
        DD      VOCL
        DD      STORE
        DD      DOES
DOVOC      DD      TWOP    ; i.e. Skip ' ' name.
        DD      CONT
        DD      STORE
        DD      SEMIS
        ;
;
;   The link to task is a cold start value only.
;   It is updated each time a definition is
;   appended to the 'FORTH' vocabulary.
;

;  ************* 
;  *   FORTH   *
;  ************* 
;  
N_FORTH      DB   80H+5+40H
         DB      "FORT"
         DB     "H"+80H
         DD    N_VOCAB
FORTH      DD     DODOE
                           
        DD      DOVOC
        DB      80H+1, " "+80H  ; Dummy name field
        DD      N_TASK
        DD      0       ; END OF VOCABULARY LIST
;

;  ******************* 
;  *   DEFINITIONS   *
;  ******************* 
;  
N_DEFIN      DB   80H+11
         DB      "DEFINITION"
         DB     "S"+80H
         DD    N_FORTH
DEFIN      DD     DOCOL
                           
        DD      CONT
        DD      FETCH
        DD      CURR
        DD      STORE
        DD      SEMIS
;

;  ********* 
;  *   (   *
;  ********* 
;  
N_PAREN      DB   80H+1+40H
         DB     "("+80H
         DD    N_DEFIN
PAREN      DD     DOCOL
                           
        DD      LIT,')'
        DD      LWORD
        DD      SEMIS
;

;  ************ 
;  *   QUIT   *
;  ************ 
;  
N_QUIT      DB   80H+4
         DB      "QUI"
         DB     "T"+80H
         DD    N_PAREN
QUIT      DD     DOCOL
                           
        DD      ZERO
        DD      BLK
        DD      STORE
        DD      LBRAC
QUIT1      DD      RPSTO   ;BEGIN
        DD      CR
        DD      QUERY
        DD      INTER
        DD      STATE
        DD      FETCH
        DD      ZEQU
        DD      ZBRAN
        DD      QUIT2-$ ;IF
        DD      PDOTQ
        
        DB      2
        DB      "OK"   ;ENDIF
QUIT2      DD      BRAN
        DD      QUIT1-$  ;AGAIN
;

;  ************* 
;  *   ABORT   *
;  ************* 
;  
N_ABORT      DB   80H+5
         DB      "ABOR"
         DB     "T"+80H
         DD    N_QUIT
ABORT      DD     DOCOL
                           
        DD      SPSTO
        DD      DECA
        DD      QSTAC   ; IT DID TO & INCL THIS
        DD      CR
        DD      DOTCPU
        DD      PDOTQ

%if 0
;       If this is there it is an official release
        DB      22
        DB      'IBM-PC Fig-Forth'
        DB      FIGREL+30H,ADOT,FIGREV+30H,ADOT,USRVER+30H
%endif
;       If this is there it is a beta release
        
        DB      50
        DB      "IBM-PC $RCSfile: fig86.gnr,v $ $Revision: 2.148 $ "
        DD      FORTH
        DD      DEFIN
        DD      QUIT
        ;
;      WARM START VECTOR COMES HERE
;
WRM:    MOV     ESI, WRM1
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
WRM1      DD      WARM
;

;  ************ 
;  *   WARM   *
;  ************ 
;  
N_WARM      DB   80H+4
         DB      "WAR"
         DB     "M"+80H
         DD    N_ABORT
WARM      DD     DOCOL
                           
        DD      MTBUF
        DD      ABORT
;
;      COLD START VECTOR COMES HERE
;
LCLD:    MOV     ESI, CLD1  ; (IP) <-
%if 0
;
%endif
        CLD                     ; DIR = INC
        MOV     ESP, DWORD PTR[USINI+(CW*3)]    ;PARAM. STACK
        MOV     EBP, DWORD PTR[USINI+(CW*4)]    ;RETURN STACK
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
CLD1:
        DD      COLD
;

;  ************ 
;  *   COLD   *
;  ************ 
;  
N_COLD      DB   80H+4
         DB      "COL"
         DB     "D"+80H
         DD    N_WARM
COLD      DD     DOCOL
                           
        DD      MTBUF
        DD      FIRST
        DD      USE,STORE
        DD      FIRST
        DD      PREV,STORE
        DD      LIT, USINI
        DD      LIT,USINI+(CW*1)
        DD      FETCH
        DD      LIT,US
        DD      LCMOVE
        DD      LIT,USINI + (CW*0)    ; I.e. lfa of TASK
        DD      FETCH
        DD      LIT,FORTH+2+(CW*2)
        DD      STORE
;

        DD      BLINI
;
        DD      ABORT
;
        ;

;  ************ 
;  *   S->D   *
;  ************ 
;  
N_STOD      DB   80H+4
         DB      "S->"
         DB     "D"+80H
         DD    N_COLD
STOD      DD     $+CW
                           
        POP     EDX      ;S1
        SUB     EAX,EAX
        OR      EDX,EDX
        JNS     STOD1   ;POS
        DEC     EAX      ;NEG
STOD1:  PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   +-   *
;  ********** 
;  
N_PM      DB   80H+2
         DB      "+"
         DB     "-"+80H
         DD    N_STOD
PM      DD     DOCOL
                           
        DD      ZLESS
        DD      ZBRAN
        DD      PM1-$   ;IF
        DD      MINUS   ;ENDIF
PM1      DD      SEMIS
;

;  *********** 
;  *   D+-   *
;  *********** 
;  
N_DPM      DB   80H+3
         DB      "D+"
         DB     "-"+80H
         DD    N_PM
DPM      DD     DOCOL
                           
        DD      ZLESS
        DD      ZBRAN
        DD      DPM1-$  ;IF
        DD      DMINU   ;ENDIF
DPM1      DD      SEMIS
;

;  *********** 
;  *   ABS   *
;  *********** 
;  
N_LABS      DB   80H+3
         DB      "AB"
         DB     "S"+80H
         DD    N_DPM
LABS      DD     DOCOL
                           
        DD      LDUP
        DD      PM
        DD      SEMIS
;

;  ************ 
;  *   DABS   *
;  ************ 
;  
N_DABS      DB   80H+4
         DB      "DAB"
         DB     "S"+80H
         DD    N_LABS
DABS      DD     DOCOL
                           
        DD      LDUP
        DD      DPM
        DD      SEMIS
;

;  *********** 
;  *   MIN   *
;  *********** 
;  
N_MIN      DB   80H+3
         DB      "MI"
         DB     "N"+80H
         DD    N_DABS
MIN      DD     DOCOL
                           
        DD      TDUP
        DD      GREAT
        DD      ZBRAN
        DD      MIN1-$  ;IF
        DD      SWAP    ;ENDIF
MIN1      DD      DROP
        DD      SEMIS
;

;  *********** 
;  *   MAX   *
;  *********** 
;  
N_MAX      DB   80H+3
         DB      "MA"
         DB     "X"+80H
         DD    N_MIN
MAX      DD     DOCOL
                           
        DD      TDUP
        DD      LESS
        DD      ZBRAN
        DD      MAX1-$  ;IF
        DD      SWAP    ;ENDIF
MAX1      DD      DROP
        DD      SEMIS
;

;  ********** 
;  *   M*   *
;  ********** 
;  
N_MSTAR      DB   80H+2
         DB      "M"
         DB     "*"+80H
         DD    N_MAX
MSTAR      DD     DOCOL
                           
        DD      TDUP
        DD      LXOR
        DD      TOR
        DD      LABS
        DD      SWAP
        DD      LABS
        DD      USTAR
        DD      FROMR
        DD      DPM
        DD      SEMIS
;

;  ********** 
;  *   M/   *
;  ********** 
;  
N_MSLAS      DB   80H+2
         DB      "M"
         DB     "/"+80H
         DD    N_MSTAR
MSLAS      DD     DOCOL
                           
        DD      OVER
        DD      TOR
        DD      TOR
        DD      DABS
        DD      RR
        DD      LABS
        DD      USLAS
        DD      FROMR
        DD      RR
        DD      LXOR
        DD      PM
        DD      SWAP
        DD      FROMR
        DD      PM
        DD      SWAP
        DD      SEMIS
;

;  ********* 
;  *   *   *
;  ********* 
;  
N_STAR      DB   80H+1
         DB     "*"+80H
         DD    N_MSLAS
STAR      DD     DOCOL
                           
        DD      MSTAR
        DD      DROP
        DD      SEMIS
;

;  ************ 
;  *   /MOD   *
;  ************ 
;  
N_SLMOD      DB   80H+4
         DB      "/MO"
         DB     "D"+80H
         DD    N_STAR
SLMOD      DD     DOCOL
                           
        DD      TOR
        DD      STOD
        DD      FROMR
        DD      MSLAS
        DD      SEMIS
;

;  ********* 
;  *   /   *
;  ********* 
;  
N_SLASH      DB   80H+1
         DB     "/"+80H
         DD    N_SLMOD
SLASH      DD     DOCOL
                           
        DD      SLMOD
        DD      SWAP
        DD      DROP
        DD      SEMIS
;

;  *********** 
;  *   MOD   *
;  *********** 
;  
N_LMOD      DB   80H+3
         DB      "MO"
         DB     "D"+80H
         DD    N_SLASH
LMOD      DD     DOCOL
                           
        DD      SLMOD
        DD      DROP
        DD      SEMIS
;

;  ************* 
;  *   */MOD   *
;  ************* 
;  
N_SSMOD      DB   80H+5
         DB      "*/MO"
         DB     "D"+80H
         DD    N_LMOD
SSMOD      DD     DOCOL
                           
        DD      TOR
        DD      MSTAR
        DD      FROMR
        DD      MSLAS
        DD      SEMIS
;

;  ********** 
;  *   */   *
;  ********** 
;  
N_SSLA      DB   80H+2
         DB      "*"
         DB     "/"+80H
         DD    N_SSMOD
SSLA      DD     DOCOL
                           
        DD      SSMOD
        DD      SWAP
        DD      DROP
        DD      SEMIS
;

;  ************* 
;  *   M/MOD   *
;  ************* 
;  
N_MSMOD      DB   80H+5
         DB      "M/MO"
         DB     "D"+80H
         DD    N_SSLA
MSMOD      DD     DOCOL
                           
        DD      TOR
        DD      ZERO
        DD      RR
        DD      USLAS
        DD      FROMR
        DD      SWAP
        DD      TOR
        DD      USLAS
        DD      FROMR
        DD      SEMIS
;

;  ************** 
;  *   (LINE)   *
;  ************** 
;  
N_PLINE      DB   80H+6
         DB      "(LINE"
         DB     ")"+80H
         DD    N_MSMOD
PLINE      DD     DOCOL
                           
        DD      TOR
        DD      LIT,64
        DD      BBUF
        DD      SSMOD
        DD      FROMR
        DD      BSCR
        DD      STAR
        DD      PLUS
        DD      BLOCK
        DD      PLUS
        DD      LIT,64
        DD      SEMIS
;

;  ************* 
;  *   .LINE   *
;  ************* 
;  
N_DLINE      DB   80H+5
         DB      ".LIN"
         DB     "E"+80H
         DD    N_PLINE
DLINE      DD     DOCOL
                           
        DD      PLINE
        DD      DTRAI
        DD      LTYPE
        DD      SEMIS
;

;  *************** 
;  *   MESSAGE   *
;  *************** 
;  
N_MESS      DB   80H+7
         DB      "MESSAG"
         DB     "E"+80H
         DD    N_DLINE
MESS      DD     DOCOL
                           
        DD      WARN
        DD      FETCH
        DD      ZBRAN
        DD      MESS1-$ ;IF
        DD      DDUP
        DD      ZBRAN
        DD      MESS2-$ ;IF
        DD      LIT,4
        DD      DLINE
        DD      SPACE   ;ENDIF
MESS2      DD      BRAN
        DD      MESS3-$  ;ELSE
MESS1      DD      PDOTQ
        
        DB      6
        DB      "MSG # "
        DD      DOT     ;ENDIF
MESS3      DD      SEMIS
;

;  *********** 
;  *   PC@   *
;  *********** 
;  
N_PCFET      DB   80H+3
         DB      "PC"
         DB     "@"+80H
         DD    N_MESS
PCFET      DD     $+CW
                           
; FETCH CHARACTER (BYTE) FROM PORT
        POP     EDX      ; PORT ADDR
        XOR     EAX,EAX
        IN      AL,DX   ; BYTE INPUT
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *********** 
;  *   PC!   *
;  *********** 
;  
N_PCSTO      DB   80H+3
         DB      "PC"
         DB     "!"+80H
         DD    N_PCFET
PCSTO      DD     $+CW
                           
        POP     EDX      ;PORT ADDR
        POP     EAX      ;DATA
        OUT     DX,AL   ; BYTE OUTPUT
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   P@   *
;  ********** 
;  
N_PFET      DB   80H+2
         DB      "P"
         DB     "@"+80H
         DD    N_PCSTO
PFET      DD     $+CW
                           
        POP     EDX      ;PORT ADDR
        IN      EAX,DX   ;WORD INPUT
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ********** 
;  *   P!   *
;  ********** 
;  
N_PSTO      DB   80H+2
         DB      "P"
         DB     "!"+80H
         DD    N_PFET
PSTO      DD     $+CW
                           
        POP     EDX      ;PORT ADDR
        POP     EAX      ;DATA
        OUT     DX,EAX   ;WORD OUTPUT
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *********** 
;  *   USE   *
;  *********** 
;  
N_USE      DB   80H+3
         DB      "US"
         DB     "E"+80H
         DD    N_PSTO
USE      DD     DOVAR
                           
        DD BUF1
;

;  ************ 
;  *   PREV   *
;  ************ 
;  
N_PREV      DB   80H+4
         DB      "PRE"
         DB     "V"+80H
         DD    N_USE
PREV      DD     DOVAR
                           
        DD      BUF1
;

;  ************* 
;  *   #BUFF   *
;  ************* 
;  
N_NOBUF      DB   80H+5
         DB      "#BUF"
         DB     "F"+80H
         DD    N_PREV
NOBUF      DD     DOCON
                           
        ;NO. OF BUFFERS
        DD      NBUF
;

;  ************ 
;  *   +BUF   *
;  ************ 
;  
N_PBUF      DB   80H+4
         DB      "+BU"
         DB     "F"+80H
         DD    N_NOBUF
PBUF      DD     DOCOL
                           
        DD      LIT,(KBBUF+2*CW)
        DD      PLUS,LDUP
        DD      LIMIT,EQUAL
        DD      ZBRAN
        DD      PBUF1-$
        DD      DROP,FIRST
PBUF1      DD      LDUP,PREV
        DD      FETCH,LSUB
        DD      SEMIS
;

;  ************** 
;  *   UPDATE   *
;  ************** 
;  
N_UPDAT      DB   80H+6
         DB      "UPDAT"
         DB     "E"+80H
         DD    N_PBUF
UPDAT      DD     DOCOL
                           
        DD      PREV
        DD      FETCH,FETCH
        DD      LIT,BMASK
        DD      LOR
        DD      PREV,FETCH
        DD      STORE,SEMIS
;

;  ********************* 
;  *   EMPTY-BUFFERS   *
;  ********************* 
;  
N_MTBUF      DB   80H+13
         DB      "EMPTY-BUFFER"
         DB     "S"+80H
         DD    N_UPDAT
MTBUF      DD     DOCOL
                           
        DD      FIRST
        DD      LIMIT,OVER
        DD      LSUB,LERASE
        DD      SEMIS
        ;
;

;  ************** 
;  *   BUFFER   *
;  ************** 
;  
N_BUFFE      DB   80H+6
         DB      "BUFFE"
         DB     "R"+80H
         DD    N_MTBUF
BUFFE      DD     DOCOL
                           
; NOTE: THIS WORD WON'T WORK IF ONLY USING SINGLE BUFFER
        DD      USE
        DD      FETCH,LDUP
        DD      TOR
BUFF1      DD      PBUF
        DD      ZBRAN
        DD      BUFF1-$
        DD      USE,STORE
        DD      RR,FETCH
        DD      ZLESS
        DD      ZBRAN
        DD      BUFF2-$
        DD      RR,CELLP
        DD      RR,FETCH
        DD      LIT,7FFFH
        DD      LAND,ZERO
        DD      RSLW
BUFF2      DD      RR,STORE
        DD      RR,PREV
        DD      STORE,FROMR
        DD      CELLP,SEMIS
;

;  ************* 
;  *   BLOCK   *
;  ************* 
;  
N_BLOCK      DB   80H+5
         DB      "BLOC"
         DB     "K"+80H
         DD    N_BUFFE
BLOCK      DD     DOCOL
                           
        DD      LIT, PMASK, LAND
        DD      OFSET
        DD      FETCH,PLUS
        DD      TOR,PREV
        DD      FETCH,LDUP
        DD      FETCH,RR
        DD      LSUB
        DD      LDUP,PLUS
        DD      ZBRAN
        DD      BLOC1-$
BLOC2      DD      PBUF,ZEQU
        DD      ZBRAN
        DD      BLOC3-$
        DD      DROP,RR
        DD      BUFFE,LDUP
        DD      RR,ONE
        DD      RSLW
        DD      LIT, CW,LSUB
BLOC3      DD      LDUP,FETCH
        DD      RR,LSUB
        DD      LDUP,PLUS
        DD      ZEQU
        DD      ZBRAN
        DD      BLOC2-$
        DD      LDUP,PREV
        DD      STORE
BLOC1      DD      FROMR,DROP
        DD      CELLP,SEMIS
;

;  ************* 
;  *   FLUSH   *
;  ************* 
;  
N_FLUSH      DB   80H+5
         DB      "FLUS"
         DB     "H"+80H
         DD    N_BLOCK
FLUSH      DD     DOCOL
                           
        DD      NOBUF,ONEP
        DD      ZERO,XDO
FLUS1      DD      ZERO,BUFFE
        DD      DROP
        DD      XLOOP
        DD      FLUS1-$
        DD      SEMIS
;

;  ************ 
;  *   LOAD   *
;  ************ 
;  
N_LOAD      DB   80H+4
         DB      "LOA"
         DB     "D"+80H
         DD    N_FLUSH
LOAD      DD     DOCOL
                           
        DD      BLK
        DD      FETCH,TOR
        DD      LIN,FETCH
        DD      TOR,ZERO
        DD      LIN,STORE
        DD      BSCR,STAR
        DD      BLK,STORE       ;BLK <- SCR * B/SCR
        DD      INTER   ;INTERPRET FROM OTHER
SCREEN      DD      FROMR,LIN
        DD      STORE
        DD      FROMR,BLK
        DD      STORE
        DD      SEMIS
;

;  *********** 
;  *   -->   *
;  *********** 
;  
N_ARROW      DB   80H+3+40H
         DB      "--"
         DB     ">"+80H
         DD    N_LOAD
ARROW      DD     DOCOL
                           
        DD      QLOAD
        DD      ZERO
        DD      LIN
        DD      STORE
        DD      BSCR
        DD      BLK
        DD      FETCH
        DD      OVER
        DD      LMOD
        DD      LSUB
        DD      BLK
        DD      PSTOR
        DD      SEMIS
        ;
;
;


;  ************* 
;  *   LINOS   *
;  ************* 
;  
N_LINOS      DB   80H+5
         DB      "LINO"
         DB     "S"+80H
         DD    N_ARROW
LINOS      DD     $+CW
                           
        POP     EAX        ; Function number
        POP     EDX        ; Third parameter, if any
        POP     ECX        ; Second parameter, if any
        POP     EBX        ; First parameter.
        INT     80H        ; Generic call on LINUX 
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]        ; Positive means okay. Negative means -errno.
;

;
        ;
;------------------------------------
;       SYSTEM DEPENDANT CHAR I/O
;------------------------------------
;

; Code fields are filled in during bootup. 
; Lower case labels starting with "c_.." are c-supplied facilities.

;  ************ 
;  *   TYPE   *
;  ************ 
;  
N_LTYPE      DB   80H+4
         DB      "TYP"
         DB     "E"+80H
         DD    N_LINOS
LTYPE      DD     DOCOL
                           
        DD      $+(CW*1) ;  Turns this code word into high level.
        CALL    c_type
        LEA     ESP,[ESP+(CW*2)]    ; remove input
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;
;  ************** 
;  *   EXPECT   *
;  ************** 
;  
N_EXPEC      DB   80H+6
         DB      "EXPEC"
         DB     "T"+80H
         DD    N_LTYPE
EXPEC      DD     $+CW
                           
        CALL    c_expec
        LEA     ESP,[ESP+(CW*2)]    ; remove input
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  *********** 
;  *   KEY   *
;  *********** 
;  
N_KEY      DB   80H+3
         DB      "KE"
         DB     "Y"+80H
         DD    N_EXPEC
KEY      DD     $+CW
                           
        CALL    c_key
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ***************** 
;  *   ?TERMINAL   *
;  ***************** 
;  
N_QTERM      DB   80H+9
         DB      "?TERMINA"
         DB     "L"+80H
         DD    N_KEY
QTERM      DD     $+CW
                           
        CALL    c_qterm
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;
 ;
;


;  ************ 
;  *   EMIT   *
;  ************ 
;  
N_EMIT      DB   80H+4
         DB      "EMI"
         DB     "T"+80H
         DD    N_QTERM
EMIT      DD     DOCOL
                           
        DD      SPFET, ONE, LTYPE
        DD      DROP
        DD      SEMIS
;
;
;
;
;
        ;
;------------------------------------
;       SYSTEM DEPENDANT DISK I/O
;------------------------------------



;  ****************** 
;  *   BLOCK-FILE   *
;  ****************** 
;  
N_BLFL      DB   80H+10
         DB      "BLOCK-FIL"
         DB     "E"+80H
         DD    N_EMIT
BLFL      DD     DOVAR
                           
        
        DB      10
        DB      "BLOCKS.BLK"
        BYTE    254-9 DUP(?)               ; Allow for some path

;  ******************** 
;  *   BLOCK-HANDLE   *
;  ******************** 
;  
N_BHAN      DB   80H+12
         DB      "BLOCK-HANDL"
         DB     "E"+80H
         DD    N_BLFL
BHAN      DD     DOVAR
                           
        DD      -1
;
;
;
;


;  ****************** 
;  *   DISK-ERROR   *
;  ****************** 
;  
N_DERR      DB   80H+10
         DB      "DISK-ERRO"
         DB     "R"+80H
         DD    N_BHAN
DERR      DD     DOVAR
                           
        DD      -1
;
;
;



;  ****************** 
;  *   BLOCK-INIT   *
;  ****************** 
;  
N_BLINI      DB   80H+10
         DB      "BLOCK-INI"
         DB     "T"+80H
         DD    N_DERR
BLINI      DD     c_BLINI   ; ################## TEMP ##############
c_BLINI:                           
        XOR     EAX,EAX
        MOV     AL,BYTE PTR[(BLFL+CW)]
        LEA     EBX,(BLFL+CW)+1
        PUSH    EBX
        PUSH    EAX
        CALL    c_block_init
        MOV     [(DERR+CW)],EAX
        LEA     ESP,[ESP+(CW*2)]    ; remove input
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;  ****************** 
;  *   BLOCK-EXIT   *
;  ****************** 
;  
N_BLEXI      DB   80H+10
         DB      "BLOCK-EXI"
         DB     "T"+80H
         DD    N_BLINI
BLEXI      DD     $+CW
                           
        CALL    c_block_exit
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
;

;      ( ADDR  BLK#  FLAG (0=W, 1=R)
;  *********** 
;  *   R/W   *
;  *********** 
;  
N_RSLW      DB   80H+3
         DB      "R/"
         DB     "W"+80H
         DD    N_BLEXI
RSLW      DD     $+CW
                           
        CALL c_rslw
        MOV     [(DERR+CW)],EAX
        LEA     ESP,[ESP+(CW*3)]    ; remove input
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   


 ;
;
;
;
;
;
        ;
        ; At line     LINE ~3500

;  ********* 
;  *   '   *
;  ********* 
;  
N_TICK      DB   80H+1+40H
         DB     "'"+80H
         DD    N_RSLW
TICK      DD     DOCOL
                           
        DD      DFIND
        DD      ZEQU
        DD      ZERO
        DD      QERR
        DD      DROP
        DD      LITER
        DD      SEMIS
;

;  ****************** 
;  *   FORGET-VOC   *
;  ****************** 
;  
N_FORGV      DB   80H+10
         DB      "FORGET-VO"
         DB     "C"+80H
         DD    N_TICK
FORGV      DD     DOCOL
                           
        DD      TDUP
        DD      ULESS
        DD      ZBRAN
        DD      FORGV1-$
;        Vocabulary itself is also forgotten.
        DD      FORTH
        DD      DEFIN
        DD      FETCH     ; Unlink by linking next vocabulary.
        DD      VOCL
        DD      STORE
        DD      BRAN
        DD      FORGV2-$
FORGV1: ;  Forget part of contents.
        DD      SWAP
        DD      TOR
        DD      LIT,2+(CW*1)
        DD      LSUB    ;  TOS is now phantom NFA.
        DD      LDUP
FORGV3:
        DD      PFA
        DD      LFA
        DD      FETCH
        DD      LDUP
        DD      RR
        DD      ULESS
        DD      ZBRAN
        DD      FORGV3-$
        DD      SWAP
        DD      TWOP    ;  Skip over " "-name.
        DD      STORE
        DD      FROMR
FORGV2      DD      SEMIS
;

;  ************** 
;  *   FORGET   *
;  ************** 
;  
N_FORG      DB   80H+6
         DB      "FORGE"
         DB     "T"+80H
         DD    N_FORGV
FORG      DD     DOCOL
                           
        DD      CURR
        DD      FETCH
        DD      CONT
        DD      FETCH
        DD      LSUB
        DD      LIT,18H
        DD      QERR
        DD      TICK
        DD      LDUP
        DD      FENCE
        DD      FETCH
        DD      LESS
        DD      LIT,15H
        DD      QERR
        DD      LDUP
        DD      NFA
        DD      LIT,FORGV
        DD      FORV
        DD      DROP
        DD      SEMIS
;

;  ************ 
;  *   BACK   *
;  ************ 
;  
N_BACK      DB   80H+4
         DB      "BAC"
         DB     "K"+80H
         DD    N_FORG
BACK      DD     DOCOL
                           
        DD      HERE
        DD      LSUB
        DD      COMMA
        DD      SEMIS
;

;  ************* 
;  *   BEGIN   *
;  ************* 
;  
N_BEGIN      DB   80H+5+40H
         DB      "BEGI"
         DB     "N"+80H
         DD    N_BACK
BEGIN      DD     DOCOL
                           
        DD      QCOMP
        DD      HERE
        DD      ONE
        DD      SEMIS
;

;  ************* 
;  *   ENDIF   *
;  ************* 
;  
N_LENDIF      DB   80H+5+40H
         DB      "ENDI"
         DB     "F"+80H
         DD    N_BEGIN
LENDIF      DD     DOCOL
                           
        DD      QCOMP
        DD      TWO     ; Magic number
        DD      QPAIR
        DD      HERE
        DD      OVER
        DD      LSUB
        DD      SWAP
        DD      STORE
        DD      SEMIS
;

;  ************ 
;  *   THEN   *
;  ************ 
;  
N_THEN      DB   80H+4+40H
         DB      "THE"
         DB     "N"+80H
         DD    N_LENDIF
THEN      DD     DOCOL
                           
        DD      LENDIF
        DD      SEMIS
;

;  ********** 
;  *   DO   *
;  ********** 
;  
N_DO      DB   80H+2+40H
         DB      "D"
         DB     "O"+80H
         DD    N_THEN
DO      DD     DOCOL
                           
        DD      COMP
        DD      XDO
        DD      HERE
        DD      THREE   ; Magic number
        DD      SEMIS
;

;  ************ 
;  *   LOOP   *
;  ************ 
;  
N_LLOOP      DB   80H+4+40H
         DB      "LOO"
         DB     "P"+80H
         DD    N_DO
LLOOP      DD     DOCOL
                           
        DD      THREE   ; Magic number
        DD      QPAIR
        DD      COMP
        DD      XLOOP
        DD      BACK
        DD      SEMIS
;

;  ************* 
;  *   +LOOP   *
;  ************* 
;  
N_PLOOP      DB   80H+5+40H
         DB      "+LOO"
         DB     "P"+80H
         DD    N_LLOOP
PLOOP      DD     DOCOL
                           
        DD      THREE   ; Magic number
        DD      QPAIR
        DD      COMP
        DD      XPLOO
        DD      BACK
        DD      SEMIS
;

;  ************* 
;  *   UNTIL   *
;  ************* 
;  
N_UNTIL      DB   80H+5+40H
         DB      "UNTI"
         DB     "L"+80H
         DD    N_PLOOP
UNTIL      DD     DOCOL
                           
        DD      ONE
        DD      QPAIR
        DD      COMP
        DD      ZBRAN
        DD      BACK
        DD      SEMIS
;

;  *********** 
;  *   END   *
;  *********** 
;  
N_LEND      DB   80H+3+40H
         DB      "EN"
         DB     "D"+80H
         DD    N_UNTIL
LEND      DD     DOCOL
                           
        DD      UNTIL
        DD      SEMIS
;

;  ************* 
;  *   AGAIN   *
;  ************* 
;  
N_AGAIN      DB   80H+5+40H
         DB      "AGAI"
         DB     "N"+80H
         DD    N_LEND
AGAIN      DD     DOCOL
                           
        DD      ONE
        DD      QPAIR
        DD      COMP
        DD      BRAN
        DD      BACK
        DD      SEMIS
;

;  ************** 
;  *   REPEAT   *
;  ************** 
;  
N_REPEA      DB   80H+6+40H
         DB      "REPEA"
         DB     "T"+80H
         DD    N_AGAIN
REPEA      DD     DOCOL
                           
        DD      TOR
        DD      TOR
        DD      AGAIN
        DD      FROMR
        DD      FROMR
        DD      TWO     ; Magic number
        DD      LSUB
        DD      LENDIF
        DD      SEMIS
;

;  ********** 
;  *   IF   *
;  ********** 
;  
N_LIF      DB   80H+2+40H
         DB      "I"
         DB     "F"+80H
         DD    N_REPEA
LIF      DD     DOCOL
                           
        DD      COMP
        DD      ZBRAN
        DD      HERE
        DD      ZERO
        DD      COMMA
        DD      TWO     ; Magic number           
        DD      SEMIS
;

;  ************ 
;  *   ELSE   *
;  ************ 
;  
N_LELSE      DB   80H+4+40H
         DB      "ELS"
         DB     "E"+80H
         DD    N_LIF
LELSE      DD     DOCOL
                           
        DD      TWO     ; Magic number 
        DD      QPAIR
        DD      COMP
        DD      BRAN
        DD      HERE
        DD      ZERO
        DD      COMMA
        DD      SWAP
        DD      TWO     ; Magic number           
        DD      LENDIF
        DD      TWO     ; Magic number           
        DD      SEMIS
;

;  ************* 
;  *   WHILE   *
;  ************* 
;  
N_WHILE      DB   80H+5+40H
         DB      "WHIL"
         DB     "E"+80H
         DD    N_LELSE
WHIL      DD     DOCOL      ; WHIEL is a reserved word.
                           
        DD      LIF
        DD      TWOP        ; Magic number           
        DD      SEMIS
;

;  ************** 
;  *   SPACES   *
;  ************** 
;  
N_SPACES      DB   80H+6
         DB      "SPACE"
         DB     "S"+80H
         DD    N_WHILE
SPACES      DD     DOCOL
                           
        DD      ZERO
        DD      MAX
        DD      DDUP
        DD      ZBRAN
        DD      SPAX1-$
        DD      ZERO
        DD      XDO     ;DO
SPAX2      DD      SPACE
        DD      XLOOP
        DD      SPAX2-$    ;LOOP
SPAX1      DD      SEMIS
;

;  ********** 
;  *   <#   *
;  ********** 
;  
N_BDIGS      DB   80H+2
         DB      "<"
         DB     "#"+80H
         DD    N_SPACES
BDIGS      DD     DOCOL
                           
        DD      PAD
        DD      HLD
        DD      STORE
        DD      SEMIS
;

;  ********** 
;  *   #>   *
;  ********** 
;  
N_EDIGS      DB   80H+2
         DB      "#"
         DB     ">"+80H
         DD    N_BDIGS
EDIGS      DD     DOCOL
                           
        DD      DROP
        DD      DROP
        DD      HLD
        DD      FETCH
        DD      PAD
        DD      OVER
        DD      LSUB
        DD      SEMIS
;

;  ************ 
;  *   SIGN   *
;  ************ 
;  
N_SIGN      DB   80H+4
         DB      "SIG"
         DB     "N"+80H
         DD    N_EDIGS
SIGN      DD     DOCOL
                           
        DD      ROT
        DD      ZLESS
        DD      ZBRAN
        DD      SIGN1-$ ;IF
        DD      LIT,2DH
        DD      HOLD    ;ENDIF
SIGN1      DD      SEMIS
;

;  ********* 
;  *   #   *
;  ********* 
;  
N_DIG      DB   80H+1
         DB     "#"+80H
         DD    N_SIGN
DIG      DD     DOCOL
                           
        DD      BASE
        DD      FETCH
        DD      MSMOD
        DD      ROT
        DD      LIT,9
        DD      OVER
        DD      LESS
        DD      ZBRAN
        DD      DIG1-$  ;IF
        DD      LIT,7
        DD      PLUS    ;ENDIF
DIG1      DD      LIT,30H
        DD      PLUS
        DD      HOLD
        DD      SEMIS
;

;  ********** 
;  *   #S   *
;  ********** 
;  
N_DIGS      DB   80H+2
         DB      "#"
         DB     "S"+80H
         DD    N_DIG
DIGS      DD     DOCOL
                           
DIGS1      DD      DIG     ;BEGIN
        DD      OVER
        DD      OVER
        DD      LOR
        DD      ZEQU
        DD      ZBRAN
        DD      DIGS1-$ ;UNTIL
        DD      SEMIS
;

;  *********** 
;  *   D.R   *
;  *********** 
;  
N_DDOTR      DB   80H+3
         DB      "D."
         DB     "R"+80H
         DD    N_DIGS
DDOTR      DD     DOCOL
                           
        DD      TOR
        DD      SWAP
        DD      OVER
        DD      DABS
        DD      BDIGS
        DD      DIGS
        DD      SIGN
        DD      EDIGS
        DD      FROMR
        DD      OVER
        DD      LSUB
        DD      SPACES
        DD      LTYPE
        DD      SEMIS
;

;  ********** 
;  *   .R   *
;  ********** 
;  
N_DOTR      DB   80H+2
         DB      "."
         DB     "R"+80H
         DD    N_DDOTR
DOTR      DD     DOCOL
                           
        DD      TOR
        DD      STOD
        DD      FROMR
        DD      DDOTR
        DD      SEMIS
;

;  ********** 
;  *   D.   *
;  ********** 
;  
N_DDOT      DB   80H+2
         DB      "D"
         DB     "."+80H
         DD    N_DOTR
DDOT      DD     DOCOL
                           
        DD      ZERO
        DD      DDOTR
        DD      SPACE
        DD      SEMIS
;

;  ********* 
;  *   .   *
;  ********* 
;  
N_DOT      DB   80H+1
         DB     "."+80H
         DD    N_DDOT
DOT      DD     DOCOL
                           
        DD      STOD
        DD      DDOT
        DD      SEMIS
;

;  ********* 
;  *   ?   *
;  ********* 
;  
N_QUES      DB   80H+1
         DB     "?"+80H
         DD    N_DOT
QUES      DD     DOCOL
                           
        DD      FETCH
        DD      DOT
        DD      SEMIS
;

;  ********** 
;  *   U.   *
;  ********** 
;  
N_UDOT      DB   80H+2
         DB      "U"
         DB     "."+80H
         DD    N_QUES
UDOT      DD     DOCOL
                           
        DD      ZERO
        DD      DDOT
        DD      SEMIS
;

;  ***************** 
;  *   FOR-WORDS   *
;  ***************** 
;  
N_FORW      DB   80H+9
         DB      "FOR-WORD"
         DB     "S"+80H
         DD    N_UDOT
FORW      DD     DOCOL
                           
        DD      TOR
        DD      CONT
        DD      FETCH
        DD      FETCH
        DD      TOR
FORW1      DD      FROMR
        DD      RR
        DD      OVER
        DD      PFA
        DD      LFA
        DD      FETCH
        DD      TOR
        DD      EXEC
        DD      RR
        DD      ZEQU
        DD      ZBRAN
        DD      FORW1-$
        DD      FROMR
        DD      DROP
        DD      FROMR
        DD      DROP
        DD      SEMIS
;

;  **************** 
;  *   FOR-VOCS   *
;  **************** 
;  
N_FORV      DB   80H+8
         DB      "FOR-VOC"
         DB     "S"+80H
         DD    N_FORW
FORV      DD     DOCOL
                           
        DD      TOR
        DD      VOCL
        DD      FETCH
        DD      TOR
FORV1      DD      FROMR
        DD      RR
        DD      OVER
        DD      FETCH
        DD      TOR
        DD      EXEC
        DD      RR
        DD      ZEQU
        DD      ZBRAN
        DD      FORV1-$
        DD      FROMR
        DD      DROP
        DD      FROMR
        DD      DROP
        DD      SEMIS
;

;  ************* 
;  *   VLIST   *
;  ************* 
;  
N_VLIST      DB   80H+5
         DB      "VLIS"
         DB     "T"+80H
         DD    N_FORV
VLIST      DD     DOCOL
                           
        DD      CSLL
        DD      LOUT
        DD      STORE
        DD      LIT, IDDOT
        DD      FORW
        DD      SEMIS
;
;
;


;  *********** 
;  *   BYE   *
;  *********** 
;  
N_BYE      DB   80H+3
         DB      "BY"
         DB     "E"+80H
         DD    N_VLIST
BYE      DD     DOCOL
                           
; Exit to linux, with okay status. 
        DD      ZERO, ZERO, ZERO, ONE, LINOS
;
;

;  ************ 
;  *   LIST   *
;  ************ 
;  
N_LLIST      DB   80H+4
         DB      "LIS"
         DB     "T"+80H
         DD    N_BYE
LLIST      DD     DOCOL
                           
        DD      DECA
        DD      CR,LDUP
        DD      SCR,STORE
        DD      PDOTQ
        
        DB      6
        DB      "SCR # "
        DD      DOT
        DD      LIT,10H
        DD      ZERO,XDO
LIST1      DD      CR,IDO
        DD      LIT,3
        DD      DOTR,SPACE
        DD      IDO,SCR
        DD      FETCH,DLINE
        DD      QTERM   ; ?TERMINAL
        DD      ZBRAN
        DD      LIST2-$
        DD      LLEAV
LIST2      DD      XLOOP
        DD      LIST1-$
        DD      CR,SEMIS
;

;  ************* 
;  *   INDEX   *
;  ************* 
;  
N_INDEX      DB   80H+5
         DB      "INDE"
         DB     "X"+80H
         DD    N_LLIST
INDEX      DD     DOCOL
                           
        DD      LIT,FF
        DD      EMIT,CR
        DD      ONEP,SWAP
        DD      XDO
INDE1      DD      CR,IDO
        DD      LIT,3
        DD      DOTR,SPACE
        DD      ZERO,IDO
        DD      DLINE,QTERM
        DD      ZBRAN
        DD      INDE2-$
        DD      LLEAV
INDE2      DD      XLOOP
        DD      INDE1-$
        DD      SEMIS
;

;  ************* 
;  *   TRIAD   *
;  ************* 
;  
N_TRIAD      DB   80H+5
         DB      "TRIA"
         DB     "D"+80H
         DD    N_INDEX
TRIAD      DD     DOCOL
                           
        DD      LIT,FF
        DD      EMIT
        DD      LIT,3
        DD      SLASH
        DD      LIT,3
        DD      STAR
        DD      LIT,3
        DD      OVER,PLUS
        DD      SWAP,XDO
TRIA1      DD      CR,IDO
        DD      LLIST
        DD      QTERM   ; ?TERMINAL
        DD      ZBRAN
        DD      TRIA2-$
        DD      LLEAV   ;LEAVE
TRIA2      DD      XLOOP
        DD      TRIA1-$    ;ENDIF
        DD      CR
        DD      SEMIS
; This word is not even fig!

;  ************ 
;  *   .CPU   *
;  ************ 
;  
N_DOTCPU      DB   80H+4
         DB      ".CP"
         DB     "U"+80H
         DD    N_TRIAD
DOTCPU      DD     DOCOL
                           
; PRINT CPU TYPE (8088)
        DD      BASE,FETCH
        DD      LIT,36
        DD      BASE,STORE
        DD      LIT,(CW*12),PORIG ;
        DD      TFET

        DD      LIT, 10000H, STAR, PLUS, ZERO
;
        DD      DDOT
        DD      BASE,STORE
        DD      SEMIS
;
;           CODE LEVEL "MATCH" DEFINITIONS
;

;  ************* 
;  *   MATCH   *
;  ************* 
;  
N_MATCH      DB   80H+5
         DB      "MATC"
         DB     "H"+80H
         DD    N_DOTCPU
MATCH      DD     $+CW
                           
        MOV     EDI,ESI   ; SAVE IP
        POP     ECX      ; STRING COUNT
        POP     EBX      ;STRING ADDR
        POP     EDX      ;BYTES LEFT TO SEARCH
        POP     ESI      ;CURSOR ADDR
        PUSH    ESI      ;SAVE COPY
MAT1:   LODSB           ;GET FIRST BYTE
        CMP     AL,[EBX] ;MATCH?
        JNZ     MAT3    ;NO
        PUSH    EBX      ;SAVE STRING ADDR
        PUSH    ECX      ; &   STRING COUNT
        PUSH    ESI      ; &   CURSOR ADDR
; TRY TO MATCH REMAINING CHARS IN STRING
;
MAT2:   DEC     ECX      ;STR. COUNT -1
        JZ      MATCHOK ;EXIT - MATCH FOUND
        DEC     EDX      ;BYTES LEFT -1
        JZ      NOMATCH ;EXIT - NO MATCH
        INC     EBX      ;NEXT STR CHAR ADDR
        LODSB           ;GET FIRST BYTE
        CMP     AL,[EBX] ;MATCH?
        JZ      MAT2    ;YES, GET MORE
; NO MATCH YET
        POP     ESI
        POP     ECX
        POP     EBX      ;RESTORE POINTERS
MAT3:   DEC     EDX      ;BYTE LEFT COUNT -1
        JNZ     MAT1    ;START OVER
        JMP     MAT4    ;EXIT...NO MATCH
MATCHOK:
NOMATCH:
        POP     ECX      ;ADJUST STACK
        POP     ECX      ;FOR EXIT
        POP     ECX
; EXIT HERE: DX = TRUE/FALSE FLAG ( 0=NO MATCH)
;
MAT4:   MOV     EAX,ESI   ;NEW CURSOR ADDR
        POP     ESI      ;GET STARTING ADDR
        SUB     EAX,ESI   ;COMPUTE CURSOR OFFSET
        MOV     ESI,EDI   ;GET BACK UP
        PUSH    EDX
        PUSH    EAX
        LODSD                 ; NEXT
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]             ; BYE..BYE
        ;
;
;
;**** LAST DICTIONARY WORD ****

;  ************ 
;  *   TASK   *
;  ************ 
;  
N_TASK      DB   80H+4
         DB      "TAS"
         DB     "K"+80H
         DD    N_MATCH
TASK      DD     DOCOL
                           
        DD      SEMIS
;
 ;

%if 0

The remaining memory ( up to 'EM' ) is
used for:

        1. EXTENSION DICTIONARY
        2. PARAMETER STACK
        3. TERMINAL INPUT BUFFER
        4. RETURN STACK
        5. USER VARIABLE AREA
        6. DISK BUFFERS (UNLESS REQURIED <1 MBYTE)


%endif


;       This is the proper way to do it.
;       No memory addresses should be arrived at through equates.
;       However now we must teach the linker to keep the
;       two sections together.

FORTHSIZE       EQU     $-figforth

       ;  section dictionary nobits write exec alloc

INITDP:                 ;  It may be that it is not consecutive with TASK
                        ;  And that is a hell of a problem.
        BUFFERSIZE      EQU  (KBBUF+2*CW)*NBUF

; Allow 1MB (1048576) for dictionary growth.
       BYTE        1048576 - FORTHSIZE - RTS - US - BUFFERSIZE DUP(?)
INITS0:                         ; Growns down
STRTIB: 
        BYTE        RTS DUP(?)            ; Start return stack area
INITR0:                         ; Grows down
STRUSA: 
        BYTE        US DUP(?)             ; User area
BUF1:   
        BYTE        BUFFERSIZE DUP(?)     ; FIRST DISK BUFFER
EM:
;
;

 ;    ENDS
        ;
%if 0

  MISC. NOTES AND SCATTERED THOUGHTS

- This source will assemble on all platforms where NASM is
  available by the command line:
  nasm -fbin fig86.asm -o fig86.com
  (There may be exceptions for special configurations.)
  The result will run on MSDOS systems only, or stand alone
  an an IBM-compatible computer

- In a MODERN version <ctrl> P  will echo all output to the
  printer. This is not programmed here, but a feature of the OS.
  The operating system may make available a command history too.

- Use the installation manual.  Descriptions for all FIG
  words are given.  Those ERROR messages you get in FORTH
  correspond to the relative line numbers in blocks
  4 and 5 of the installation manual's model.

- Remember that all the FORTH words in this version are
  upper case letters.  Use <CAPS LOCK> when in FORTH.

- Changing variable EM will allow you to create a larger
  dictionary space.  However I suggest you develop and
  DEBUG with EM set to 4000H.  Setting it to a larger value
  will result in a larger FORTH.EXE file, and you may
  need to run EXE2BIN ( Chap 10, DOS 2.0 ) to get enough
  disk space.  Once you are satisfied with what you have,
  then by all means take that extra memory.

- Reading the section on batch files may speed up your
  developement.  See the example files that came with
  the Macro Assembler.

- Subscribe to FORTH Dimensions.  It is a valuable source
  of system and application ideas.  Talking with fellow
  FORTH programmers is sure to stir up some exciting ideas.
  Consider joining a FIG chapter.  See the back of FORTH
  Dimensions for more info.

- <Ctrl-Break> will vector to WARM start ( Label WRM: )

%endif

; Define the entry point, not valid for auto booting.
        ;     ORIG

figforth endp
end 
