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


OC7M_IN     EQU   $0C   ; Force channels 2 and 3 high when channel 7 resets
OC7D_IN     EQU   $0C   ; Same as above, needed for same reason.
TSCR2_IN	  EQU		$02		; disable TOI, prescale = 4
TCTL2_IN	  EQU		$A0		; Tell ch2 and ch3 to go to 0 at end of pulse length
TCTL1_IN    EQU   $40   ; upon compare, channel 7 will be set high (which will set ch2 and 3 high)
TCTL4_IN    EQU   $05   ; Mask for setting ch0 and ch1 to look for any rising edge.
TIOS_IN		  EQU		$8C		; select Ch 7,2 and 3 for OC, everything else is set for input compare
TSCR_IN 	  EQU		$80		; enable timer, normal flag CLR.
TFLG1_Chk   EQU   $8F   ; check if ch7 matches free running counter
TFLG1_Clr   EQU   $8F   ; Clear interrupts set for channels 0-3 and ch 7
TIE_IN      EQU   $03   ; Mask to turn on interrupts for channels 0 and 1.
PERCENT		  EQU		$80
MAXPERCENT	EQU		$3333
init_perc	  EQU		$0CCD	; 3,277 ticks, or 5% pulse width

init_max	  EQU		$3333	; 13,107 ticks, or 20% pulse width
count_max   EQU   $FFF0

five_sec    EQU  	$0262 ; 610 pulses = 5 seconds with 8MHz clock 
ten_sec		  EQU		$04C4	; 1220 pulses
fift_sec	  EQU		$0727 ;
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
			  
			  LDD	  pulse_width		;add hex value to high count, This code will create the first pulse duty cycle
    		STD 	TC2Hi				;setup next transition time for ch 2
    		STD   TC3Hi       ;setup next transition time for ch 3
			  MOVB  #TIE_IN, TIE  ;Turn on interrupts for ch0 and ch1
			  
			  ;BSR  LCD_Subroutine_Here
			  
DONE	  BRA		DONE		; Branch to self

;-------------------------------------
;Subroutine TIMERINIT: Initialize timer for OC2
;-------------------------------------
TIMERINIT_OC2	CLR		TIE 				;disable interrupts in Timer Interrupt Enable Register
				MOVB	#TSCR2_IN,TSCR2 	;Timer System Control Register 2
				MOVB	#TCTL2_IN,TCTL2 	;OC2 toggle on compare
				MOVB  #TCTL4_IN,TCTL4   ;Set ch0 and ch1 interrupts to activate on any rising edge.
        MOVB  #OC7M_IN,OC7M
        MOVB  #OC7D_IN,OC7D
				MOVB	#TIOS_IN,TIOS 		;select ch2 for OC
				MOVW	#pulse_width,TC2Hi		;load TC2 with initial comp
				MOVB	#TSCR_IN,TSCR1		;enable timer, std flag clr4,
				RTS							;return from subroutine


;-----------------------------------
;Ch0 Interrupt code
;-----------------------------------
rti_intCh0: 
        	LDAA	TFLG1				;Read flag first
    			ORAA	#TFLG1_Clr	;write 1 to flag for clearing ch 0-3 and ch 7
    			STAA	TFLG1   		
    			BRA SPEED_CTRL
          

    ;-----------------------------------
    ;Subroutine INC_OF
    ;increment overflow counter
    ;-----------------------------------v			
INC_OF		LDX		o_count				;increment number of overflows by 1
    			INX
    			STX   o_count
    			    
    		  BRA EndIntr

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
top_speed LDD 	#init_max				;set pulse_width to init_max(20%)
          STD 	pulse_width				;save pulse_width value
          BRA		INC_OF
          			
          			
    ;-----------------------------------
    ;Subroutine to maintain min speed (%5 duty cycle) for a long time
    ;-----------------------------------
min_speed LDD 	#init_perc				;set pulse_width to init_min(5%)
          STD 	pulse_width				;save pulse_width value
          BRA		INC_OF

    ;-----------------------------------
    ;Subroutine SPEED_CTRL
    ;-----------------------------------
SPEED_CTRL  LDD		o_count
    			  SUBD	#five_sec
    			  BLT		inc_speed			;branch if <5s
    			      
    			  LDD		o_count
    			  SUBD	#fift_sec
    			  BGT		min_speed			;branch if >15s
    			
    			  LDD		o_count
    			  SUBD	#ten_sec
    			  BGT		dec_speed			;branch if >10s
    			
    			  BRA top_speed
    	
    	;Subroutunne EndIntr
    	; Call this subroutine to end the Interrupt.		  
    			  
    			  
EndIntr   LDD	  pulse_width		;add hex value to high count
          STD 	TC2Hi				;setup next transition time for ch 2
        	STD   TC3Hi       ;setup next transition time for ch 3
        	
        	RTI   	
            
;------------------------------      			
;End of Ch0 interrupt code     
;------------------------------       

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************

            ORG   $FFFE
            DC.W  Entry           ; Reset Vector

            ORG   Vtimch0
            DC.W  rti_intCh0

            END
