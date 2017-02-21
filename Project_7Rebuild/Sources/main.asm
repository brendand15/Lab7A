;*****************************************************************
;* This stationery serves as the framework for a                 *
;* user application (single file, absolute assembly application) *
;* For a more comprehensive program that                         *
;* demonstrates the more advanced functionality of this          *
;* processor, please see the demonstration applications          *
;* located in the examples subdirectory of the                   *
;* Freescale CodeWarrior for the HC12 Program directory          *
;*****************************************************************

; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry        ; for absolute assembly: mark this as application entry point



; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

ROMStart    EQU  $4000  ; absolute address to place my code/constant data

; variable/data section

 ifdef _HCS12_SERIALMON
            ORG $3FFF - (RAMEnd - RAMStart)
 else
            ORG RAMStart
 endif
 
pulse_width	FDB		init_perc  ; Creates the pulse_width variable for use with pwm 
o_count		  FDB		$0000	; Number of overflows
 
 ; Insert here your data definition.
Counter     DS.W 1
FiboRes     DS.W 1

TSCR2_IN	  EQU		$02		; disable TOI, prescale = 4
TCTL2_IN	  EQU		$10		; initialize OC2 toggle
TIOS_IN		  EQU		$0C		; select Ch 2 and 3 for OC, everything else is set for input compare
TSCR_IN 	  EQU		$80		; enable timer, normal flag CLR.
PERCENT		  EQU		$80
MAXPERCENT	EQU		$3333
init_perc	  EQU		$0CCD	; 3,277 ticks, or 5% pulse width

init_max	  EQU		$3333	; 13,107 ticks, or 20% pulse width
count_max   EQU   $FFF0

five_sec    EQU  	$0262   ; 610 pulses = 5 seconds with 8MHz clock
ten_sec		  EQU		$04C4	; 1220 pulses
fift_sec	  EQU		$0727
slope		    EQU		$10		; Duty Cycle profile slope (15% in 5 sec = 3% per sec OR [ (13,107 ticks - 3277 ticks)/5 sec] * [ 5sec /610 pulses ] = 16 ticks per pulse, 16 hex = 10



; code section
            ORG   ROMStart


Entry:
_Startup:
            ; remap the RAM &amp; EEPROM here. See EB386.pdf
 ifdef _HCS12_SERIALMON
            ; set registers at $0000
            CLR   $11                  ; INITRG= $0
            ; set ram to end at $3FFF
            LDAB  #$39
            STAB  $10                  ; INITRM= $39

            ; set eeprom to end at $0FFF
            LDAA  #$9
            STAA  $12                  ; INITEE= $9


            LDS   #$3FFF+1        ; See EB386.pdf, initialize the stack pointer
 else
            LDS   #RAMEnd+1       ; initialize the stack pointer
 endif

            CLI                     ; enable interrupts
mainLoop:

;Lab7A.asm

;---------------------------------
;MAIN PROGRAM: Lab7A, generates a square wave
;
;
;---------------------------------

			  BSR		TIMERINIT_OC2	; Timer initialization subr
DONE	  BSR		SQ_WAVE		; square wave gen subr
			  BRA		DONE		; Branch to self

;-------------------------------------
;Subroutine TIMERINIT: Initialize timer for OC2
;-------------------------------------
TIMERINIT_OC2	CLR		TIE 				;disable interrupts in Timer Interrupt Enable Register
				MOVB	#TSCR2_IN,TSCR2 	;Timer System Control Register 2
				MOVB	#TCTL2_IN,TCTL2 	;OC2 toggle on compare
				MOVB	#TIOS_IN,TIOS 		;select ch2 for OC
				MOVW	#pulse_width,TC2Hi		;load TC2 with initial comp
				MOVB	#TSCR_IN,TSCR1		;enable timer, std flag clr4,
				RTS							;return from subroutine

;----------------------------------
;CLEARFLG
;Clear C@F flag by reading TFLG1 when C2F set and then writing 1 to C2F
;----------------------------------
CLEARFLG	LDAA	TFLG1				;Read flag first
			    ORAA	#$04				;write 1 to flag for clearing
			    STAA	TFLG1
			    
			    BRA SPEED_CTRL

;-----------------------------------
;Subroutine INC_OF
;increment overflow counter
;-----------------------------------v			
INC_OF		  LDX		o_count				;increment number of overflows by 1
			    INX
			    LDD   o_count
			    SUBD  count_max
			    BEQ   RES_COUNT
			    STX   o_count
			    
		      BRA	SQ_WAVE
RES_COUNT CLR o_count
          BRA SQ_WAVE


;-----------------------------------
;Subroutine SQWAVE
;-----------------------------------
SQ_WAVE 	BRCLR	TFLG1,$04,SQ_WAVE 	;Poll for C2F Flag
			    LDD		TC2Hi				;load value from TC2 reg
    			ADDD	#pulse_width		;add hex value to high count
    			STD 	TC2Hi				;setup next transition time
    			BSR		CLEARFLG			;generate repetitive signal
    			RTS

;-----------------------------------
;Subroutine Increase speed
;     min + (overflow * slope)
;-----------------------------------
inc_speed	LDD		pulse_width			;loads previous pulse width
    			ADDD	#slope					;increment pulse_width by the slope
    			STD		pulse_width				;save our new pulse_width value
    			BRA		INC_OF

;-----------------------------------
;Subroutine to decrease motor speed
;     20% dutycycle ticks - (overflow - 10sec) * slope
;-----------------------------------
dec_speed	LDD		pulse_width			;loads previous pulse width
    			SUBD	#slope					;decrement pulse_width by the slope
    			STD		pulse_width				;save our new pulse_width value
    			BRA		INC_OF

;-----------------------------------
;Subroutine to maintain top speed (%20 duty cycle) for 5 seconds
;-----------------------------------
top_speed 	LDD 	#init_max				;set pulse_width to init_max(20%)
      			STD 	pulse_width				;save pulse_width value
      			BRA		INC_OF

;-----------------------------------
;Subroutine SPEED_CTRL
;-----------------------------------
SPEED_CTRL  LDAA	TFLG1				;Read flag first
			      ORAA	#$04				;write 1 to flag for clearing
			      STAA	TFLG1
			
		    	  LDD		o_count
			      SUBD	#five_sec
			      BLT		inc_speed			;branch if <5s
			
			      LDD		o_count
			      SUBD	#ten_sec
			      BGT		dec_speed			;branch if >10s
			
			      BRA top_speed


		  	  
		  	  
		  	  
      			END


;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry           ; Reset Vector
