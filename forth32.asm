; FlatForth - an x86 32-bit flat MASM-assembling figForth, with no M4 in sight.
; Derived from: (see below FIG notice which is left intact)


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

BMASK   EQU     80000000H

; ########################################################################################
; ENTRY macros to define dictionary headers. There is one for code immediately
; following, and another for DOCOL etc. Forth routines.
; NOTE WELL the C_Label - MASM silently (!) fails on the original code:
;   label DD $+4
;
; with a value of 4 instead of currentlocation + 4. These things, along with bizarre behaviour
; of colon/no-colon on labels, are sent to try us.

; Initial value of link. Each ENTRY links to the previous one.
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
        extern  c_expect:PROC
        extern  c_key:PROC
        extern  c_qterminal:PROC
        extern  c_readwrite:PROC
        extern  c_block_exit:PROC
        extern  c_block_init:PROC
        extern  c_exit:PROC
 ;



        ;
; ########################################################################################
;                      BOOTCODE   
; ########################################################################################


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

; ######################################################################
; NEXT, the Forth address (inner) interpreter.

; The NEXT macro goes at the end of code words. It is the same code as above.

NEXT    MACRO
        LODSD 
        MOV     EBX,EAX                  
        JMP      DWORD PTR[EBX]   
ENDM



; #######################################################################
;       Dictionary starts here.

DP0:
;  *********** 
;  *   LIT   *
;  *********** 
;  
        CODE_ENTRY LIT, 80H+3, "LI", "T"+80H

        LODSD           ; AX <- LITERAL
        PUSH    EAX
        NEXT
;

;  *************** 
;  *   EXECUTE   *
;  *************** 
;  
        CODE_ENTRY EXEC, 80H+7, "EXECUT", "E"+80H

        POP     EBX      ; GET CFA
        JMP      DWORD PTR[EBX]
;

;  ************** 
;  *   BRANCH   *
;  ************** 
;  
        CODE_ENTRY BRAN, 80H+6, "BRANC", "H"+80H

BRAN1:  ADD     ESI,[ESI]
        NEXT
;

;  *************** 
;  *   0BRANCH   *
;  *************** 
;  
        CODE_ENTRY ZBRAN, 80H+7, "0BRANC", "H"+80H
        POP     EAX      ; GET STACK VALUE
        OR      EAX,EAX   ; ZERO?
        JZ      BRAN1   ; YES, BRANCH
        LEA     ESI,[ESI+(CW*1)]
        NEXT
;

;  ************ 
;  *   NOOP   *
;  ************ 
;  
        CODE_ENTRY NOOP, 80H+4, "NOO", "P"+80H

        NEXT
;

;  ************** 
;  *   (LOOP)   * 
;  ************** 
;  
        CODE_ENTRY XLOOP, 80H+6, "(LOOP", ")"+80H

        MOV     EBX,1    ; INCREMENT
XLOO1:  ADD     [EBP],EBX ; INDEX = INDEX + INCR
        MOV     EAX,[EBP] ; GET NEW INDEX
        SUB     EAX,[EBP+(CW*1)]        ; COMPARE WITH LIMIT
        XOR     EAX,EBX   ; TEST SIGN
        JS      BRAN1   ; KEEP LOOPING
;
;  END OF `DO' LOOP
        ADD     EBP,(CW*2)             ; ADJ RETURN STACK
        LEA     ESI,[ESI+(CW*1)]       ; BYPASS BRANCH OFFSET
        NEXT
;

;  *************** 
;  *   (+LOOP)   *
;  *************** 
;  
        CODE_ENTRY XPLOO, 80H+7, "(+LOOP", ")"+80H

        POP     EBX      ; GET LOOP VALUE
        JMP SHORT     XLOO1
;

;  ************ 
;  *   (DO)   *
;  ************ 
;  
        CODE_ENTRY XDO, 80H+4, "(DO", ")"+80H
                           
        POP     EDX      ; INITIAL INDEX VALUE
        POP     EAX      ; LIMIT VALUE
        XCHG    EBP,ESP   ; GET RETURN STACK
        PUSH    EAX
        PUSH    EDX
        XCHG    EBP,ESP   ; GET PARAMETER STACK
        NEXT
;

;  ********* 
;  *   I   *
;  ********* 
;  
        CODE_ENTRY_1 IDO, 80H+1, "I"+80H
                           
        MOV     EAX,[EBP] ; GET INDEX VALUE
        PUSH    EAX
        NEXT
;

;  *************** 
;  *   +ORIGIN   *
;  *************** 
;  
        ENTRY PORIG, 80H+7, "+ORIGI", "N"+80H, DOCOL
                           
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
        CODE_ENTRY DIGIT, 80H+5, "DIGI", "T"+80H
                           
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
        NEXT
;   NUMBER ERROR
DIGI2:  SUB     EAX,EAX   ;FALSE FLAG
        PUSH    EAX
        NEXT
        ;

;  ************** 
;  *   (FIND)   *
;  ************** 
;  ### TODO: make this (optiomnally) case insensitive.
        CODE_ENTRY PFIND, 80H+6, "(FIND", ")"+80H
                           
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
        NEXT
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
        NEXT
;

;  *************** 
;  *   ENCLOSE   *
;  *************** 
;  
        CODE_ENTRY ENCL, 80H+7, "ENCLOS", "E"+80H
                           
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
        NEXT
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
        NEXT
;
;   FOUND TERMINATOR CHARACTER
ENCL4:  MOV     EAX,EDX
        INC     EAX      ;COUNT+1
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  ********** 
;  *   CR   *
;  ********** 
;  
        ENTRY CR, 80H+2, "C", "R"+80H, DOCOL
                           
        DD      LIT,LF
        DD      EMIT
        DD      SEMIS
;

;  ************* 
;  *   CMOVE   *
;  ************* 
;  
        CODE_ENTRY LCMOVE, 80H+5, "CMOV", "E"+80H
                           
        CLD             ;INC DIRECTION
        MOV     EBX,ESI   ;SAVE IF
        POP     ECX      ;COUNT
        POP     EDI      ;DEST
        POP     ESI      ;SOURCE
;       MOV    AX,DS
;       MOV    ES,AX   ;ES <- DS
        REP     MOVSB   ;THAT'S THE MOVE
        MOV     ESI,EBX   ;GET BACK IP
        NEXT
;

;  ********** 
;  *   U*   *
;  ********** 
;  
        CODE_ENTRY USTAR, 80H+2, "U", "*"+80H
                           
        POP     EAX
        POP     EBX
        MUL     EBX      ;UNSIGNED
        XCHG    EAX,EDX   ;AX NOW = MSW
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  ********** 
;  *   U/   *
;  ********** 
;  
        CODE_ENTRY USLAS, 80H+2, "U", "/"+80H
                           
        POP     EBX      ;DIVISOR
        POP     EDX      ;MSW OF DIVIDEND
        POP     EAX      ;LSW OF DIVIDEND
        CMP     EDX,EBX   ;DICIDE BY 0?
        JNB     DZERO   ; ERROR - ZERO DIVIDE
        DIV     EBX      ;16 BIT DIVIDE
        PUSH    EDX
        PUSH    EAX
        NEXT
;
;      DIVIDE BY ZERO ERROR - SHOW MAX NUMBERS
DZERO:  MOV     EAX,-1
        MOV     EDX,EAX
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  *********** 
;  *   AND   *
;  *********** 
;  
        CODE_ENTRY LAND, 80H+3, "AN", "D"+80H
                           
        POP     EAX
        POP     EBX
        AND     EAX,EBX
        PUSH    EAX
        NEXT
;

;  ********** 
;  *   OR   *
;  ********** 
;  
        CODE_ENTRY LOR, 80H+2, "O", "R"+80H
                           
        POP     EAX      ; (S1) <- (S1) OR (S2)
        POP     EBX
        OR      EAX,EBX
        PUSH    EAX
        NEXT
;

;  *********** 
;  *   XOR   *
;  *********** 
;  
        CODE_ENTRY LXOR, 80H+3, "XO", "R"+80H
                           
        POP     EAX      ; (S1) <- (S1) XOR (S2)
        POP     EBX
        XOR     EAX,EBX
        PUSH    EAX
        NEXT
;

;  *********** 
;  *   SP@   *
;  *********** 
;  
        CODE_ENTRY SPFET, 80H+3, "SP", "@"+80H
                           
        MOV     EAX,ESP   ; (S1) <- (SP)
        PUSH    EAX
        NEXT
;

;  *********** 
;  *   SP!   *
;  *********** 
;  
        CODE_ENTRY SPSTO, 80H+3, "SP", "!"+80H
                           
        MOV     EBX, DWORD PTR[USINI+(CW*1)]   ;USER VAR BASE ADDR
        MOV     ESP,[EBX+(CW*3)]        ;RESET PARAM STACK POINTER
        NEXT
;

;  *********** 
;  *   RP@   *
;  *********** 
;  
        CODE_ENTRY RPFET, 80H+3, "RP", "@"+80H
                           ;(S1) <- (RP)
        MOV     EAX,EBP   ;RETURN STACK ADDR
        PUSH    EAX
        NEXT
;

;  *********** 
;  *   RP!   *
;  *********** 
;  
        CODE_ENTRY RPSTO, 80H+3, "RP", "!"+80H
                           
        MOV     EBX, DWORD PTR[USINI+(CW*1)]   ;(AX) <- USR VAR BASE
        MOV     EBP,[EBX+(CW*4)]        ;RESET RETURN STACK PTR
        NEXT
;

;  ********** 
;  *   ;S   *
;  ********** 
;  
        CODE_ENTRY SEMIS, 80H+2, ";", "S"+80H
                           
        MOV     ESI,[EBP] ;(IP) <- (R1)
        LEA     EBP,[EBP+(CW*1)]
        NEXT
;

;  ************* 
;  *   LEAVE   *
;  ************* 
;  
        CODE_ENTRY LLEAV, 80H+5, "LEAV", "E"+80H

                           ;LIMIT <- INDEX
        MOV     EAX,[EBP] ;GET INDEX
        MOV     [EBP+(CW*1)],EAX        ;STORE IT AT LIMIT
        NEXT
        ;
;

;  ********** 
;  *   >R   *
;  ********** 
        CODE_ENTRY TOR, 80H+2, ">", "R"+80H

                        ; (R1) <- (S1)
        POP     EBX      ;GET STACK PARAMETER
        LEA     EBP,[EBP-(CW*1)]    ;MOVE RETURN STACK DOWN
        MOV     [EBP],EBX ;ADD TO RETURN STACK
        NEXT
;

;  ********** 
;  *   R>   *
;  ********** 
;  
        CODE_ENTRY FROMR, 80H+2, "R", ">"+80H

                          ;(S1) <- (R1)
        MOV     EAX,[EBP] ; GET RETURN STACK VALUE
        LEA     EBP,[EBP+(CW*1)]
        PUSH    EAX
        NEXT
;

;  ********* 
;  *   R   *
;  ********* 
; Synonym.
        ENTRY_1 RR, 80H+1, "R"+80H, IDO+(CW*1)
;

;  ********** 
;  *   0=   *
;  ********** 
;  
        CODE_ENTRY ZEQU, 80H+2, "0", "="+80H
                           
        POP     EAX
        OR      EAX,EAX   ;DO TEST
        MOV     EAX,1    ;TRUE
        JZ      ZEQU1   ;IT'S 0
        DEC     EAX      ;FALSE
ZEQU1:  PUSH    EAX
        NEXT
;

;  ********** 
;  *   0<   *
;  ********** 
;  
        CODE_ENTRY ZLESS, 80H+2, "0", "<"+80H
                           
        POP     EAX
        OR      EAX,EAX   ;SET FLAGS
        MOV     EAX,1    ;TRUE
        JS      ZLESS1
        DEC     EAX      ;FALSE
ZLESS1: PUSH    EAX
        NEXT
;

;  ********* 
;  *   +   *
;  ********* 
;  
        CODE_ENTRY_1 PLUS, 80H+1, "+"+80H

        POP     EAX      ;(S1) <- (S1) + (S2)
        POP     EBX
        ADD     EAX,EBX
        PUSH    EAX
        NEXT
;

;  ********** 
;  *   D+   *
;  ********** 
;  
        CODE_ENTRY DPLUS, 80H+2, "D", "+"+80H
                           
        POP     EAX      ; YHW
        POP     EDX      ; YLW
        POP     EBX      ; XHW
        POP     ECX      ; XLW
        ADD     EDX,ECX   ; SLW
        ADC     EAX,EBX   ; SHW
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  ************* 
;  *   MINUS   *
;  ************* 
        CODE_ENTRY MINUS, 80H+5, "MINU", "S"+80H
                           
        POP     EAX
        NEG     EAX
        PUSH    EAX
        NEXT
;

;  ************** 
;  *   DMINUS   *
;  ************** 
;  
        CODE_ENTRY DMINU, 80H+6, "DMINU", "S"+80H
                           
        POP     EBX
        POP     ECX
        SUB     EAX,EAX
        MOV     EDX,EAX
        SUB     EDX,ECX   ; MAKE 2'S COMPLEMENT
        SBB     EAX,EBX   ; HIGH CELL
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  ************ 
;  *   OVER   *
;  ************ 
;  
        CODE_ENTRY    OVER, 80H+4, "OVE", "R"+80H

        POP     EDX
        POP     EAX
        PUSH    EAX
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  ************ 
;  *   DROP   *
;  ************ 
;  
        CODE_ENTRY    DROP, 80H+4, "DRO", "P"+80H
                           
        POP     EAX
        NEXT
;

;  ************ 
;  *   SWAP   *
;  ************ 
;  
        CODE_ENTRY    SWAP, 80H+4, "SWA", "P"+80H
                           
        POP     EDX
        POP     EAX
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  *********** 
;  *   DUP   *
;  *********** 
;  
        CODE_ENTRY    LDUP, 80H+3, "DU", "P"+80H
                           
        POP     EAX
        PUSH    EAX
        PUSH    EAX
        NEXT
;

;  ************ 
;  *   2DUP   *
;  ************ 
;  
        CODE_ENTRY    TDUP, 80H+4, "2DU", "P"+80H
                           
        POP     EAX
        POP     EDX
        PUSH    EDX
        PUSH    EAX
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  ********** 
;  *   +!   *
;  ********** 
;  
        CODE_ENTRY    PSTOR, 80H+2, "+", "!"+80H
                           
        POP     EBX      ;ADDRESS
        POP     EAX      ;INCREMENT
        ADD     [EBX],EAX
        NEXT
;

;  ************** 
;  *   TOGGLE   *
;  ************** 
;  
        CODE_ENTRY    TOGGL, 80H+6, "TOGGL", "E"+80H

        POP     EAX      ;BIT PATTERN
        POP     EBX      ;ADDR
        XOR     [EBX],EAX ;
        NEXT
;

;  ********* 
;  *   @   *
;  ********* 
;  
        CODE_ENTRY_1    FETCH, 80H+1, "@"+80H
                           
        POP     EBX
        MOV     EAX,[EBX]
        PUSH    EAX
        NEXT
;

;  ********** 
;  *   C@   *
;  ********** 
;  
        CODE_ENTRY    CFET, 80H+2, "C", "@"+80H
                           
        POP     EBX
        XOR     EAX,EAX
        MOV     AL,[EBX]
        PUSH    EAX
        NEXT
;

;  ********** 
;  *   2@   *
;  ********** 
;  
        CODE_ENTRY    TFET, 80H+2, "2", "@"+80H
                           
        POP     EBX      ;ADDR
        MOV     EAX,[EBX] ;MSW
        MOV     EDX,[EBX+(CW*1)]        ;LSW
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  ********* 
;  *   !   *
;  ********* 
;  
        CODE_ENTRY_1    STORE, 80H+1, "!"+80H
                           
        POP     EBX      ;ADDR
        POP     EAX      ;DATA
        MOV     [EBX],EAX
        NEXT
;

;  ********** 
;  *   C!   *
;  ********** 
;  
        CODE_ENTRY    CSTOR, 80H+2, "C", "!"+80H
                           
        POP     EBX      ;ADDR
        POP     EAX      ;DATA
        MOV     [EBX],AL
        NEXT
;

;  ********** 
;  *   2!   *
;  ********** 
;  
        CODE_ENTRY    TSTOR, 80H+2, "2", "!"+80H
                           
        POP     EBX      ;ADDR
        POP     EAX      ;MSW
        MOV     [EBX],EAX
        POP     EAX      ;LSW
        MOV     [EBX+(CW*1)],EAX
        NEXT
;
;  ********** 
;  *   L@   *
;  ********** 
;  
        CODE_ENTRY    LFET, 80H+2, "L", "@"+80H
                           
        POP     EBX      ;MEM LOC
        POP     EAX      ;SEG REG VAL
        MOV     EDX,10H
        MUL     EDX
        ADD     EAX,EBX
        MOV     EAX,[EAX]
        PUSH    EAX
        NEXT
;
;
;
;  ********** 
;  *   L!   *
;  ********** 
;  
        CODE_ENTRY    LSTORE, 80H+2, "L", "!"+80H

        POP     EBX      ;MEM LOC
        POP     EAX      ;SEG REG VAL
        MOV     EDX,10H
        MUL     EDX
        ADD     EAX,EBX
        POP     EBX
        MOV     [EAX],EBX
        NEXT
;
;
;

;  ********* 
;  *   :   *
;  ********* 
;  
        ENTRY_1    COLON, 80H+1+40H, ":"+80H, DOCOL
                           
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
        NEXT
;

;  ********* 
;  *   ;   *
;  ********* 
;  
        ENTRY_1    SEMI, 80H+1+40H, ";"+80H, DOCOL
                           
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
        ENTRY    CON, 80H+8, "CONSTAN", "T"+80H, DOCOL
                           
        DD      CREAT
        DD      SMUDG
        DD      COMMA
        DD      PSCOD
DOCON:  MOV     EAX,[EBX+(CW*1)] ;GET DATA FROM PFA
        PUSH    EAX
        NEXT
;

;  **************** 
;  *   VARIABLE   *
;  **************** 
;  
        ENTRY    VAR, 80H+8, "VARIABL", "E"+80H, DOCOL
                           
        DD      CON
        DD      PSCOD
DOVAR:  LEA     EAX,[EBX+(CW*1)] ;(AX) <- PFA
        PUSH    EAX
        NEXT
;

;  ************ 
;  *   USER   *
;  ************ 
;  
        ENTRY    USER, 80H+4, "USE", "R"+80H, DOCOL
                           
        DD      CON
        DD      PSCOD
DOUSE:  MOV     EBX,[EBX+(CW*1)] ;PFA  
        MOV     EDI, DWORD PTR[USINI+(CW*1)]   ;USER VAR ADDRESS
        LEA     EAX,[EBX+EDI]      ;ADDR OF VARIABLE
        PUSH    EAX
        NEXT
;

;  ********* 
;  *   0   *
;  ********* 
;  
        CODE_ENTRY_1    ZERO, 80H+1, "0"+80H
                           
        XOR     EAX,EAX
        PUSH    EAX
        NEXT
;

;  ********* 
;  *   1   *
;  ********* 
;  
        CODE_ENTRY_1    ONE, 80H+1, "1"+80H
                           
        MOV     EAX,1
        PUSH    EAX
        NEXT
;

;  ********* 
;  *   2   *
;  ********* 
;  
        CODE_ENTRY_1    TWO, 80H+1, "2"+80H
                           
        MOV     EAX,2
        PUSH    EAX
        NEXT
;

;  ********* 
;  *   3   *
;  ********* 
;  
        CODE_ENTRY_1    THREE, 80H+1, "3"+80H
                           
        MOV     EAX,3
        PUSH    EAX
        NEXT
;
 ;  ********** 
;  *   BL   *
;  ********** 
;  
        ENTRY    BLS, 80H+2, "B", "L"+80H, DOCON
                           
; THIS IS ONLY A SPACE CHAR
    DD 20H
;

;  *********** 
;  *   C/L   *
;  *********** 
;  
        ENTRY    CSLL, 80H+3, "C/", "L"+80H, DOCON
                           
        DD      64
;


;  ************* 
;  *   FIRST   *
;  ************* 
;  
        ENTRY    FIRST, 80H+5, "FIRS", "T"+80H, DOCON
                           
        DD      BUF1
 ;
;
;
;

;  ************* 
;  *   LIMIT   *
;  ************* 
;  
        ENTRY    LIMIT, 80H+5, "LIMI", "T"+80H, DOCON
                           
        DD      BUF1+(KBBUF+2*CW)*NBUF
; THE END  OF THE MEMORY 

;  ********** 
;  *   EM   *
;  ********** 
;  
        ENTRY    LEM, 80H+2, "E", "M"+80H, DOCON
                           
        DD      EM
;

;  ************* 
;  *   B/BUF   *
;  ************* 
;  
        ENTRY    BBUF, 80H+5, "B/BU", "F"+80H, DOCON
                           
        DD      KBBUF
;

;  ************* 
;  *   B/SCR   *
;  ************* 
;  
        ENTRY    BSCR, 80H+5, "B/SC", "R"+80H, DOCON
                           
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
        ENTRY    UZERO, 80H+2, "U", "0"+80H, DOUSE
                           
        DD      (CW*1)
;

;  ************** 
;  *   RUBOUT   *
;  ************** 
;  
        ENTRY    RUBOUT, 80H+6, "RUBOU", "T"+80H, DOUSE
                           
        DD      (CW*2)
;

;  ********** 
;  *   S0   *
;  ********** 
;  
        ENTRY    SZERO, 80H+2, "S", "0"+80H, DOUSE
                           
        DD      (CW*3)
;

;  ********** 
;  *   R0   *
;  ********** 
;  
        ENTRY    RZERO, 80H+2, "R", "0"+80H, DOUSE
                           
        DD      (CW*4)
;

;  *********** 
;  *   TIB   *
;  *********** 
;  
        ENTRY    TIB, 80H+3, "TI", "B"+80H, DOUSE
                           
        DD      (CW*5)
;

;  ************* 
;  *   WIDTH   *
;  ************* 
;  
        ENTRY    WIDTHE, 80H+5, "WIDT", "H"+80H, DOUSE
                           
        DD      (CW*6)
;

;  *************** 
;  *   WARNING   *
;  *************** 
;  
        ENTRY    WARN, 80H+7, "WARNIN", "G"+80H, DOUSE
                           
        DD      (CW*7)
;

;  ************* 
;  *   FENCE   *
;  ************* 
;  
        ENTRY    FENCE, 80H+5, "FENC", "E"+80H, DOUSE
                           
        DD      (CW*8)
;

;  ********** 
;  *   DP   *
;  ********** 
;  
        ENTRY    LDP, 80H+2, "D", "P"+80H, DOUSE
                           
        DD      (CW*9)
;

;  **************** 
;  *   VOC-LINK   *
;  **************** 
;  
        ENTRY    VOCL, 80H+8, "VOC-LIN", "K"+80H, DOUSE
                           
        DD      (CW*10)
;

;  ************** 
;  *   OFFSET   *
;  ************** 
;  
        ENTRY    OFSET, 80H+6, "OFFSE", "T"+80H, DOUSE
                           
        DD      (CW*11)
;
; End of user variables with fixed place.
;

;  *********** 
;  *   SCR   *
;  *********** 
;  
        ENTRY    SCR, 80H+3, "SC", "R"+80H, DOUSE
                           
        DD      (CW*14)
;

;  *************** 
;  *   CONTEXT   *
;  *************** 
;  
        ENTRY    CONT, 80H+7, "CONTEX", "T"+80H, DOUSE
                           
        DD      (CW*16)
;

;  *************** 
;  *   CURRENT   *
;  *************** 
;  
        ENTRY    CURR, 80H+7, "CURREN", "T"+80H, DOUSE
                           
        DD      (CW*17)
;

;  ************* 
;  *   STATE   *
;  ************* 
;  
        ENTRY    STATE, 80H+5, "STAT", "E"+80H, DOUSE
                           
        DD      (CW*18)
;

;  ************ 
;  *   BASE   *
;  ************ 
;  
        ENTRY    BASE, 80H+4, "BAS", "E"+80H, DOUSE
                           
        DD      (CW*19)
;

;  *********** 
;  *   DPL   *
;  *********** 
;  
        ENTRY    DPL, 80H+3, "DP", "L"+80H, DOUSE
                           
        DD      (CW*20)
;

;  *********** 
;  *   FLD   *
;  *********** 
;  
        ENTRY    LFLD, 80H+3, "FL", "D"+80H, DOUSE
                           
        DD      (CW*21)
;

;  *********** 
;  *   CSP   *
;  *********** 
;  
        ENTRY    LCSP, 80H+3, "CS", "P"+80H, DOUSE
                           
        DD      (CW*22)
;

;  ********** 
;  *   R#   *
;  ********** 
;  
        ENTRY    RNUM, 80H+2, "R", "#"+80H, DOUSE
                           
        DD      (CW*23)
;

;  *********** 
;  *   HLD   *
;  *********** 
;  
        ENTRY    HLD, 80H+3, "HL", "D"+80H, DOUSE
                           
        DD      (CW*24)
;

;  ********** 
;  *   IN   *
;  ********** 
;  
        ENTRY    LIN, 80H+2, "I", "N"+80H, DOUSE
                           
        DD      (CW*25)
;

;  *********** 
;  *   OUT   *
;  *********** 
;  
        ENTRY    LOUT, 80H+3, "OU", "T"+80H, DOUSE
                           
        DD      (CW*26)
;

;  *********** 
;  *   BLK   *
;  *********** 
;  
        ENTRY    BLK, 80H+3, "BL", "K"+80H, DOUSE
                           
        DD      (CW*27)
;
;========== END USER VARIABLES =============;
;

;  ********** 
;  *   1+   *
;  ********** 
;  
        CODE_ENTRY    ONEP, 80H+2, "1", "+"+80H
                           
        POP     EAX
        INC     EAX
        PUSH    EAX
        NEXT
;

;  ********** 
;  *   2+   *
;  ********** 
;  
        CODE_ENTRY    TWOP, 80H+2, "2", "+"+80H
                           
        POP     EAX
        ADD     EAX,2
        PUSH    EAX
        NEXT
;

;  ************* 
;  *   CELL+   *
;  ************* 
;  
        CODE_ENTRY    CELLP, 80H+5, "CELL", "+"+80H
                           
        POP     EAX
        ADD     EAX,CW
        PUSH    EAX
        NEXT
;

;  ************ 
;  *   HERE   *
;  ************ 
;  
        ENTRY    HERE, 80H+4, "HER", "E"+80H, DOCOL
                           
        DD      LDP
        DD      FETCH
        DD      SEMIS
;

;  ************* 
;  *   ALLOT   *
;  ************* 
;  
        ENTRY    ALLOT, 80H+5, "ALLO", "T"+80H, DOCOL
                           
        DD      LDP
        DD      PSTOR
        DD      SEMIS
;

;  ********* 
;  *   ,   *
;  ********* 
;  
        ENTRY_1    COMMA, 80H+1, ","+80H, DOCOL
                           
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
        ENTRY    CCOMM, 80H+2, "C", ","+80H, DOCOL
                           
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
        CODE_ENTRY_1    LSUB, 80H+1, "-"+80H
                           
        POP     EDX      ;S1
        POP     EAX
        SUB     EAX,EDX
        PUSH    EAX
        NEXT
;

;  ********* 
;  *   =   *
;  ********* 
;  
        ENTRY_1    EQUAL, 80H+1, "="+80H, DOCOL
                           
        DD      LSUB
        DD      ZEQU
        DD      SEMIS
;

;  ********* 
;  *   <   *
;  ********* 
;  
        CODE_ENTRY_1    LESS, 80H+1, "<"+80H
                           
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
        NEXT
;

;  ********** 
;  *   U<   *
;  ********** 
;  
        ENTRY    ULESS, 80H+2, "U", "<"+80H, DOCOL
                           
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
        ENTRY_1    GREAT, 80H+1, ">"+80H, DOCOL
                           
        DD      SWAP
        DD      LESS
        DD      SEMIS
;

;  *********** 
;  *   ROT   *
;  *********** 
;  
        CODE_ENTRY    ROT, 80H+3, "RO", "T"+80H
                           
        POP     EDX      ;S1
        POP     EBX      ;S2
        POP     EAX      ;S3
        PUSH    EBX
        PUSH    EDX
        PUSH    EAX
        NEXT
;

;  ************* 
;  *   SPACE   *
;  ************* 
;  
        ENTRY    SPACE, 80H+5, "SPAC", "E"+80H, DOCOL
                           
        DD      BLS
        DD      EMIT
        DD      SEMIS
;

;  ************ 
;  *   -DUP   *
;  ************ 
;  
        ENTRY    DDUP, 80H+4, "-DU", "P"+80H, DOCOL
                           
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
        ENTRY    TRAV, 80H+8, "TRAVERS", "E"+80H, DOCOL
                           
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
        ENTRY    LATES, 80H+6, "LATES", "T"+80H, DOCOL
                           
        DD      CURR
        DD      FETCH
        DD      FETCH
        DD      SEMIS
;

;  *********** 
;  *   LFA   *
;  *********** 
;  
        ENTRY    LFA, 80H+3, "LF", "A"+80H, DOCOL
                           
        DD      LIT,(CW*2)
        DD      LSUB
        DD      SEMIS
;

;  *********** 
;  *   CFA   *
;  *********** 
;  
        ENTRY    CFA, 80H+3, "CF", "A"+80H, DOCOL
                           
        DD      LIT, CW
        DD      LSUB
        DD      SEMIS
;

;  *********** 
;  *   NFA   *
;  *********** 
;  
        ENTRY    NFA, 80H+3, "NF", "A"+80H, DOCOL
                           
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
        ENTRY    PFA, 80H+3, "PF", "A"+80H, DOCOL
                           
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
        ENTRY    SCSP, 80H+4, "!CS", "P"+80H, DOCOL
                           
        DD      SPFET
        DD      LCSP
        DD      STORE
        DD      SEMIS
;

;  ************** 
;  *   ?ERROR   *
;  ************** 
;  
        ENTRY    QERR, 80H+6, "?ERRO", "R"+80H, DOCOL
                           
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
        ENTRY    QCOMP, 80H+5, "?COM", "P"+80H, DOCOL
                           
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
        ENTRY    QEXEC, 80H+5, "?EXE", "C"+80H, DOCOL
                           
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
        ENTRY    QPAIR, 80H+6, "?PAIR", "S"+80H, DOCOL
                           
        DD      LSUB
        DD      LIT,13H
        DD      QERR
        DD      SEMIS
;

;  ************ 
;  *   ?CSP   *
;  ************ 
;  
        ENTRY    QCSP, 80H+4, "?CS", "P"+80H, DOCOL
                           
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
        ENTRY    QLOAD, 80H+8, "?LOADIN", "G"+80H, DOCOL
                           
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
        ENTRY    COMP, 80H+7, "COMPIL", "E"+80H, DOCOL
                           
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
        ENTRY_1    LBRAC, 80H+1+40H, "["+80H, DOCOL
                           
        DD      ZERO
        DD      STATE
        DD      STORE
        DD      SEMIS
;

;  ********* 
;  *   ]   *
;  ********* 
;  
        ENTRY_1    RBRAC, 80H+1, "]"+80H, DOCOL
                           
        DD      LIT,0C0H
        DD      STATE
        DD      STORE
        DD      SEMIS
;

;  ************** 
;  *   SMUDGE   *
;  ************** 
;  
        ENTRY    SMUDG, 80H+6, "SMUDG", "E"+80H, DOCOL
                           
        DD      LATES
        DD      LIT,20H
        DD      TOGGL
        DD      SEMIS
;

;  *********** 
;  *   HEX   *
;  *********** 
;  
        ENTRY    HEX, 80H+3, "HE", "X"+80H, DOCOL
                           
        DD      LIT,16
        DD      BASE
        DD      STORE
        DD      SEMIS
;

;  *************** 
;  *   DECIMAL   *
;  *************** 
;  
        ENTRY    DECA, 80H+7, "DECIMA", "L"+80H, DOCOL
                           
        DD      LIT,10
        DD      BASE
        DD      STORE
        DD      SEMIS
;

;  *************** 
;  *   (;CODE)   *
;  *************** 
;  
        ENTRY    PSCOD, 80H+7, "(;CODE", ")"+80H, DOCOL
                           
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
        ENTRY    SEMIC, 80H+5+40H, ";COD", "E"+80H, DOCOL
                           
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
        ENTRY    BUILD, 80H+7, "<BUILD", "S"+80H, DOCOL
                           
        DD      ZERO
        DD      CON
        DD      SEMIS
;

;  ************* 
;  *   DOES>   *
;  ************* 
;  
        ENTRY    DOES, 80H+5, "DOES", ">"+80H, DOCOL
                           
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
        NEXT
;

;  ************* 
;  *   COUNT   *
;  ************* 
;  
        ENTRY    COUNT, 80H+5, "COUN", "T"+80H, DOCOL
                           
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
        ENTRY    DTRAI, 80H+9, "-TRAILIN", "G"+80H, DOCOL
                           
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
        ENTRY    PDOTQ, 80H+4, '(."', ")"+80H, DOCOL
                        
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
        ENTRY    DOTQ, 80H+2+40H, '.', '"'+80H, DOCOL
                        
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
        ENTRY    QUERY, 80H+5, "QUER", "Y"+80H, DOCOL
                           
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
        ENTRY_1    NULL, 80H+1+40H, 80H, DOCOL

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
        CODE_ENTRY    FILL, 80H+4, "FIL", "L"+80H
                           
        POP     EAX      ; FILL CHAR
        POP     ECX      ; FILL COUNT
        POP     EDI      ; BEGIN ADDR
;       MOV    BX,DS
;       MOV    ES,BX   ; ES <- DS
        CLD             ; INC DIRECTION
        REP     STOSB   ;STORE BYTE
        NEXT
;

;  ************* 
;  *   ERASE   *
;  ************* 
;  
        ENTRY    LERASE, 80H+5, "ERAS", "E"+80H, DOCOL
                           
        DD      ZERO
        DD      FILL
        DD      SEMIS
;

;  ************** 
;  *   BLANKS   *
;  ************** 
;  
        ENTRY    BLANK, 80H+6, "BLANK", "S"+80H, DOCOL
                           
        DD      BLS
        DD      FILL
        DD      SEMIS
;

;  ************ 
;  *   HOLD   *
;  ************ 
;  
        ENTRY    HOLD, 80H+4, "HOL", "D"+80H, DOCOL
                           
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
        ENTRY    PAD, 80H+3, "PA", "D"+80H, DOCOL
                           
        DD      HERE
        DD      LIT,84
        DD      PLUS
        DD      SEMIS
;

;  ************ 
;  *   WORD   *
;  ************ 
;  
        ENTRY    LWORD, 80H+4, "WOR", "D"+80H, DOCOL
                           
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
        ENTRY    PNUMB, 80H+8, "(NUMBER", ")"+80H, DOCOL
                           
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
        ENTRY    NUMB, 80H+6, "NUMBE", "R"+80H, DOCOL
                           
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
        ENTRY    DFIND, 80H+5, "-FIN", "D"+80H, DOCOL
                           
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
        ENTRY    PABOR, 80H+7, "(ABORT", ")"+80H, DOCOL
                           
        DD      ABORT
        DD      SEMIS
;

;  ************* 
;  *   ERROR   *
;  ************* 
;  
        ENTRY    ERROR, 80H+5, "ERRO", "R"+80H, DOCOL
                           
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
        ENTRY    IDDOT, 80H+3, "ID", "."+80H, DOCOL
                           
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
        DD      SEMIS
;

;  ************** 
;  *   CREATE   *
;  ************** 
;  
        ENTRY    CREAT, 80H+6, "CREAT", "E"+80H, DOCOL
                           
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
        ENTRY    BCOMP, 80H+9+40H, "[COMPILE", "]"+80H, DOCOL
                           
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
        ENTRY    LITER, 80H+7+40H, "LITERA", "L"+80H, DOCOL
                           
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
        ENTRY    DLITE, 80H+8+40H, "DLITERA", "L"+80H, DOCOL
                           
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
        ENTRY    QSTAC, 80H+6, "?STAC", "K"+80H, DOCOL
                           
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
        ENTRY   INTER, 80H+9, "INTERPRE", "T"+80H, DOCOL
                           
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
        ENTRY   IMMED, 80H+9, "IMMEDIAT", "E"+80H, DOCOL
                           
        DD      LATES
        DD      LIT,40H
        DD      TOGGL
        DD      SEMIS
;

;  ****************** 
;  *   VOCABULARY   *
;  ****************** 
;  
        ENTRY   VOCAB, 80H+10, "VOCABULAR", "Y"+80H, DOCOL
                           
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
        ENTRY   FORTH, 80H+5+40H, "FORT", "H"+80H, DODOE
                           
        DD      DOVOC
        DB      80H+1, " "+80H  ; Dummy name field
        DD      N_TASK
        DD      0       ; END OF VOCABULARY LIST
;

;  ******************* 
;  *   DEFINITIONS   *
;  ******************* 
;  
        ENTRY   DEFIN, 80H+11, "DEFINITION", "S"+80H, DOCOL
                           
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
        ENTRY_1   PAREN, 80H+1+40H, "("+80H, DOCOL
                           
        DD      LIT,')'
        DD      LWORD
        DD      SEMIS
;

;  ************ 
;  *   QUIT   *
;  ************ 
;  
        ENTRY   QUIT, 80H+4, "QUI", "T"+80H, DOCOL
                           
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
        ENTRY   ABORT, 80H+5, "ABOR", "T"+80H, DOCOL
                           
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
        NEXT
;
WRM1      DD      WARM
;

;  ************ 
;  *   WARM   *
;  ************ 
;  
        ENTRY   WARM, 80H+4, "WAR", "M"+80H, DOCOL
                           
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
        NEXT
;
CLD1:
        DD      COLD
;

;  ************ 
;  *   COLD   *
;  ************ 
;  
        ENTRY   COLD, 80H+4, "COL", "D"+80H, DOCOL
                           
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
        CODE_ENTRY   STOD, 80H+4, "S->", "D"+80H
                           
        POP     EDX      ;S1
        SUB     EAX,EAX
        OR      EDX,EDX
        JNS     STOD1   ;POS
        DEC     EAX      ;NEG
STOD1:  PUSH    EDX
        PUSH    EAX
        NEXT
;

;  ********** 
;  *   +-   *
;  ********** 
;  
        ENTRY   PM, 80H+2, "+", "-"+80H, DOCOL
                           
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
        ENTRY   DPM, 80H+3, "D+", "-"+80H, DOCOL
                           
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
        ENTRY   LABS, 80H+3, "AB", "S"+80H, DOCOL
                           
        DD      LDUP
        DD      PM
        DD      SEMIS
;

;  ************ 
;  *   DABS   *
;  ************ 
;  
        ENTRY   DABS, 80H+4, "DAB", "S"+80H, DOCOL
                           
        DD      LDUP
        DD      DPM
        DD      SEMIS
;

;  *********** 
;  *   MIN   *
;  *********** 
;  
        ENTRY   MIN, 80H+3, "MI", "N"+80H, DOCOL
                           
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
        ENTRY   MAX, 80H+3, "MA", "X"+80H, DOCOL
                           
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
        ENTRY   MSTAR, 80H+2, "M", "*"+80H, DOCOL
                           
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
        ENTRY   MSLAS, 80H+2, "M", "/"+80H, DOCOL
                           
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
        ENTRY_1   STAR, 80H+1, "*"+80H, DOCOL
                           
        DD      MSTAR
        DD      DROP
        DD      SEMIS
;

;  ************ 
;  *   /MOD   *
;  ************ 
;  
        ENTRY   SLMOD, 80H+4, "/MO", "D"+80H, DOCOL
                           
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
        ENTRY_1   SLASH, 80H+1, "/"+80H, DOCOL
                           
        DD      SLMOD
        DD      SWAP
        DD      DROP
        DD      SEMIS
;

;  *********** 
;  *   MOD   *
;  *********** 
;  
        ENTRY   LMOD, 80H+3, "MO", "D"+80H, DOCOL
                           
        DD      SLMOD
        DD      DROP
        DD      SEMIS
;

;  ************* 
;  *   */MOD   *
;  ************* 
;  
        ENTRY   SSMOD, 80H+5, "*/MO", "D"+80H, DOCOL
                           
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
        ENTRY   SSLA, 80H+2, "*", "/"+80H, DOCOL
                           
        DD      SSMOD
        DD      SWAP
        DD      DROP
        DD      SEMIS
;

;  ************* 
;  *   M/MOD   *
;  ************* 
;  
        ENTRY   MSMOD, 80H+5, "M/MO", "D"+80H, DOCOL
                           
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
        ENTRY   PLINE, 80H+6, "(LINE", ")"+80H, DOCOL
                           
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
        ENTRY   DLINE, 80H+5, ".LIN", "E"+80H, DOCOL
                           
        DD      PLINE
        DD      DTRAI
        DD      LTYPE
        DD      SEMIS
;

;  *************** 
;  *   MESSAGE   *
;  *************** 
;  
        ENTRY   MESS, 80H+7, "MESSAG", "E"+80H, DOCOL
                           
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

%if 0
; ##### These are not implemented on this version, as most PC's don't have ports. ###

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

%endif

;  *********** 
;  *   USE   *
;  *********** 
;  
        ENTRY   USE, 80H+3, "US", "E"+80H, DOVAR
                           
        DD BUF1
;

;  ************ 
;  *   PREV   *
;  ************ 
;  
        ENTRY   PREV, 80H+4, "PRE", "V"+80H, DOVAR

        DD      BUF1
;

;  ************* 
;  *   #BUFF   *
;  ************* 
;  
        ENTRY   NOBUF, 80H+5, "#BUF", "F"+80H, DOCON
                           
        ;NO. OF BUFFERS
        DD      NBUF
;

;  ************ 
;  *   +BUF   *
;  ************ 
;  
        ENTRY   PBUF, 80H+4, "+BU", "F"+80H, DOCOL
                           
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
        ENTRY   UPDAT, 80H+6, "UPDAT", "E"+80H, DOCOL
                           
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
        ENTRY   MTBUF, 80H+13, "EMPTY-BUFFER", "S"+80H, DOCOL
                           
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
        ENTRY   BUFFE, 80H+6, "BUFFE", "R"+80H, DOCOL
                           
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
        ENTRY   BLOCK, 80H+5, "BLOC", "K"+80H, DOCOL
                           
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
        ENTRY   FLUSH, 80H+5, "FLUS", "H"+80H, DOCOL
                           
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
        ENTRY   LOAD, 80H+4, "LOA", "D"+80H, DOCOL
                           
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
        ENTRY   ARROW, 80H+3+40H, "--", ">"+80H, DOCOL
                           
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


%if 0
; ################## NOT USED ################
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
%endif
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
        CODE_ENTRY   LTYPE, 80H+4, "TYP", "E"+80H

        CALL    c_type
        LEA     ESP,[ESP+(CW*2)]    ; remove input
        NEXT
;

;
;  ************** 
;  *   EXPECT   *
;  ************** 
;  
        CODE_ENTRY   EXPEC, 80H+6, "EXPEC", "T"+80H

        CALL    c_expect
        LEA     ESP,[ESP+(CW*2)]    ; remove input
        NEXT
;

;  *********** 
;  *   KEY   *
;  *********** 
;  
        CODE_ENTRY   LKEY, 80H+3, "KE", "Y"+80H
                           
        CALL    c_key
        PUSH    EAX
        NEXT
;

;  ***************** 
;  *   ?TERMINAL   *
;  ***************** 
;  
        CODE_ENTRY   QTERM, 80H+9, "?TERMINA", "L"+80H
                           
        CALL    c_qterminal
        PUSH    EAX
        NEXT
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
        ENTRY   BLFL, 80H+10, "BLOCK-FIL", "E"+80H, DOVAR
                           
        
        DB      10
        DB      "BLOCKS.BLK"
        BYTE    254-9 DUP(?)               ; Allow for some path

;  ******************** 
;  *   BLOCK-HANDLE   *
;  ******************** 
;  
        ENTRY   BHAN, 80H+12, "BLOCK-HANDL", "E"+80H, DOVAR
                           
        DD      -1


;  ****************** 
;  *   DISK-ERROR   *
;  ****************** 
;  
        ENTRY   DERR, 80H+10, "DISK-ERRO", "R"+80H, DOVAR
                           
        DD      -1

;  ****************** 
;  *   BLOCK-INIT   *
;  ****************** 
;  
        CODE_ENTRY   BLINI, 80H+10, "BLOCK-INI", "T"+80H

        XOR     EAX,EAX
        MOV     AL,BYTE PTR[(BLFL+CW)]
        LEA     EBX,(BLFL+CW)+1
        PUSH    EBX
        PUSH    EAX
        CALL    c_block_init
        MOV     [(DERR+CW)],EAX
        LEA     ESP,[ESP+(CW*2)]    ; remove input
        NEXT
;

;  ****************** 
;  *   BLOCK-EXIT   *
;  ****************** 
;  
        CODE_ENTRY   BLEXI, 80H+10, "BLOCK-EXI", "T"+80H
                           
        CALL    c_block_exit
        NEXT
;

;      ( ADDR  BLK#  FLAG (0=W, 1=R)
;  *********** 
;  *   R/W   *
;  *********** 
;  
        CODE_ENTRY   RSLW, 80H+3, "R/", "W"+80H
                           
        CALL c_readwrite
        MOV     [(DERR+CW)],EAX
        LEA     ESP,[ESP+(CW*3)]    ; remove input
        NEXT



;  ********* 
;  *   '   *
;  ********* 
;  
        ENTRY_1   TICK, 80H+1+40H, "'"+80H, DOCOL
                           
        DD      DFIND
        DD      ZEQU
        DD      ZERO
        DD      QERR
        DD      DROP
        DD      LITER
        DD      SEMIS
;

; The original figForth FORGET code. The 2.148 version did not work any better,
; so cleaned it out and restored the DP resetting.
;  ************** 
;  *   FORGET   *
;  ************** 
;  
        ENTRY   FORG, 80H+6, "FORGE", "T"+80H, DOCOL
                           
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
        DD      LDP
        DD      STORE
        DD      LFA
        DD      FETCH
        DD      CONT
        DD      FETCH
        DD      STORE
        DD      SEMIS
;

;  ************ 
;  *   BACK   *
;  ************ 
;  
        ENTRY   BACK, 80H+4, "BAC", "K"+80H, DOCOL
                           
        DD      HERE
        DD      LSUB
        DD      COMMA
        DD      SEMIS
;

;  ************* 
;  *   BEGIN   *
;  ************* 
;  
        ENTRY   BEGIN, 80H+5+40H, "BEGI", "N"+80H, DOCOL
                           
        DD      QCOMP
        DD      HERE
        DD      ONE
        DD      SEMIS
;

;  ************* 
;  *   ENDIF   *
;  ************* 
;  
        ENTRY   LENDIF, 80H+5+40H, "ENDI", "F"+80H, DOCOL
                           
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
        ENTRY   THEN, 80H+4+40H, "THE", "N"+80H, DOCOL
                           
        DD      LENDIF
        DD      SEMIS
;

;  ********** 
;  *   DO   *
;  ********** 
;  
        ENTRY   DO, 80H+2+40H, "D", "O"+80H, DOCOL
                           
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
        ENTRY   LLOOP, 80H+4+40H, "LOO", "P"+80H, DOCOL
                           
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
        ENTRY   PLOOP, 80H+5+40H, "+LOO", "P"+80H, DOCOL
                           
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
        ENTRY   UNTIL, 80H+5+40H, "UNTI", "L"+80H, DOCOL
                           
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
        ENTRY   LEND, 80H+3+40H, "EN", "D"+80H, DOCOL
                           
        DD      UNTIL
        DD      SEMIS
;

;  ************* 
;  *   AGAIN   *
;  ************* 
;  
        ENTRY   AGAIN, 80H+5+40H, "AGAI", "N"+80H, DOCOL
                           
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
        ENTRY   REPEA, 80H+6+40H, "REPEA", "T"+80H, DOCOL
                           
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
        ENTRY   LIF, 80H+2+40H, "I", "F"+80H, DOCOL
                           
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
        ENTRY   LELSE, 80H+4+40H, "ELS", "E"+80H, DOCOL
                           
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
        ENTRY   WHIL, 80H+5+40H, "WHIL", "E"+80H, DOCOL
                           
        DD      LIF
        DD      TWOP        ; Magic number           
        DD      SEMIS
;

;  ************** 
;  *   SPACES   *
;  ************** 
;  
        ENTRY   SPACES, 80H+6, "SPACE", "S"+80H, DOCOL
                           
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
        ENTRY   BDIGS, 80H+2, "<", "#"+80H, DOCOL
                           
        DD      PAD
        DD      HLD
        DD      STORE
        DD      SEMIS
;

;  ********** 
;  *   #>   *
;  ********** 
;  
        ENTRY   EDIGS, 80H+2, "#", ">"+80H, DOCOL
                           
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
        ENTRY   SIGN, 80H+4, "SIG", "N"+80H, DOCOL
                           
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
        ENTRY_1   DIG, 80H+1, "#"+80H, DOCOL
                           
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
        ENTRY   DIGS, 80H+2, "#", "S"+80H, DOCOL
                           
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
        ENTRY   DDOTR, 80H+3, "D.", "R"+80H, DOCOL
                           
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
        ENTRY   DOTR, 80H+2, ".", "R"+80H, DOCOL
                           
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
        ENTRY   DDOT, 80H+2, "D", "."+80H, DOCOL
                           
        DD      ZERO
        DD      DDOTR
        DD      SPACE
        DD      SEMIS
;

;  ********* 
;  *   .   *
;  ********* 
;  
        ENTRY_1   DOT, 80H+1, "."+80H, DOCOL
                           
        DD      STOD
        DD      DDOT
        DD      SEMIS
;

;  ********* 
;  *   ?   *
;  ********* 
;  
        ENTRY_1   QUES, 80H+1, "?"+80H, DOCOL
                           
        DD      FETCH
        DD      DOT
        DD      SEMIS
;

;  ********** 
;  *   U.   *
;  ********** 
;  
        ENTRY   UDOT, 80H+2, "U", "."+80H, DOCOL
                           
        DD      ZERO
        DD      DDOT
        DD      SEMIS
;

;
; The original figForth VLIST code
; *************
; *   VLIST   *
; *************
;
        ENTRY   VLIST, 80H+5, "VLIS", "T"+80H, DOCOL
        DD      LIT
        DD      80H
        DD      LOUT
        DD      STORE
        DD      CONT
        DD      FETCH
        DD      FETCH
VLIS1   DD      LOUT            ; BEGIN
        DD      FETCH
        DD      CSLL
        DD      GREAT
        DD      ZBRAN            ; IF
        DD      VLIS2-$
        DD      CR
        DD      ZERO
        DD      LOUT
        DD      STORE             ; ENDIF
VLIS2   DD      LDUP
        DD      IDDOT
        DD      SPACE
        DD      SPACE
        DD      PFA
        DD      LFA
        DD      FETCH
        DD      LDUP
        DD      ZEQU
        DD      QTERM
        DD      LOR
        DD      ZBRAN             ; UNTIL
        DD      VLIS1-$
        DD      DROP
        DD      SEMIS

;  *********** 
;  *   BYE   *
;  *********** 
;  
        CODE_ENTRY   BYE, 80H+3, "BY", "E"+80H
                           
        CALL c_exit
  
;  ************ 
;  *   LIST   *
;  ************ 
;  
        ENTRY   LLIST, 80H+4, "LIS", "T"+80H, DOCOL
                           
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
        ENTRY   INDEX, 80H+5, "INDE", "X"+80H, DOCOL
                           
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
        ENTRY   TRIAD, 80H+5, "TRIA", "D"+80H, DOCOL

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
        ENTRY   DOTCPU, 80H+4, ".CP", "U"+80H, DOCOL
                           
; PRINT CPU TYPE (80386)
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
;
;
;**** LAST DICTIONARY WORD in the FORTH vocabulary ****

;  ************ 
;  *   TASK   *
;  ************ 
;  
        ENTRY   TASK, 80H+4, "TAS", "K"+80H, DOCOL
                           
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
INITS0:                         ; Grows down
STRTIB: 
        BYTE        RTS DUP(?)            ; Start return stack area
INITR0:                         ; Grows down
STRUSA: 
        BYTE        US DUP(?)             ; User area
BUF1:   
        BYTE        BUFFERSIZE DUP(?)     ; FIRST DISK BUFFER
EM:

figforth endp
end 
