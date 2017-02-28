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
sec_count   FDB   $0000 ; Contains seconds that have passed.
select      FDB   $00
 
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

one_sec     EQU   $007A ; 122 pulses = 1 seconds
five_sec    EQU  	$0262 ; 610 pulses = 5 seconds with 8MHz clock 
ten_sec		  EQU		$04C4	; 1220 pulses
fift_sec	  EQU		$0727 ;
FIFT        EQU   $F

slope		    EQU		$10		; Duty Cycle profile slope (15% in 5 sec = 3% per sec OR [ (13,107 ticks - 3277 ticks)/5 sec] * [ 5sec /610 pulses ] = 16 ticks per pulse, 16 hex = 10

;LCD Variables
LCD_DATA	  EQU PORTK		
LCD_CTRL	  EQU PORTK		
RS	        EQU mPORTK_BIT0	
EN	        EQU mPORTK_BIT1
;----------------------USE $1050-$2FFF for Scratch Pad 
R1          EQU     $1051
R2          EQU     $1052
R3          EQU     $1053
TEMP        EQU     $1200


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

; Loop to see check when to print. (Will call print command once per second)
loop_s  LDD   o_count
			  LDX   #one_sec
			  IDIV          ; o_count / (122 pulses) = # of seconds
			  CPX   sec_count ; result - counted seconds
			  BEQ   loop_s    ; IF seconds = 0 or result == counted seconds, THEN continue looping/polling
			  STX   sec_count ; sec_count = result
			  BRA   PrLCD     ; Print current count
a_print LDD   sec_count ;
			  CPD   #FIFT      ; if sec_count == 15 (exit condition)
			  BEQ   DONE
			  BRA   loop_s 
			  
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

;-------------------------------------
;Subroutine PrLCD Prints # of pulses to LCD Screen
;-------------------------------------

PrLCD 
      LDAA  #$FF
		  STAA  DDRK		
		  LDAA  #$33
		  JSR	  COMWRT4    	
  		JSR   DELAY
  		LDAA  #$32
		  JSR	  COMWRT4		
 		  JSR   DELAY
		  LDAA	#$28	
		  JSR	  COMWRT4    	
		  JSR	  DELAY   		
		  LDAA	#$0E     	
		  JSR	  COMWRT4		
		  JSR   DELAY
		  LDAA	#$01     	
		  JSR	  COMWRT4    	
		  JSR   DELAY
		  LDAA	#$06     	
		  JSR	  COMWRT4    	
		  JSR   DELAY
		  LDAA	#$80     	
		  JSR	  COMWRT4    	
		  JSR   DELAY
		 
		  LDAA  #'O'     	
		  JSR	  DATWRT4 
		  JSR   DELAY
		  LDAA  #':'     	
		  JSR	  DATWRT4 
		  JSR   DELAY
		  LDAA	#' '     	
		  JSR	  DATWRT4    	
		  JSR   DELAY
		  
		  
		  ldd   o_count
		  jsr   parse_hex5
		  
		  
		  
o_prt5 
	    	    
		  LDAA	#' '     	
		  JSR	  DATWRT4    	
		  JSR   DELAY
		  LDAA  #'T'     	
		  JSR	  DATWRT4 
		  JSR   DELAY
		  LDAA  #':'     	
		  JSR	  DATWRT4 
		  JSR   DELAY
		  LDAA	#' '     	
		  JSR	  DATWRT4    	
		  JSR   DELAY
		  
		  
		  
		  ldd   sec_count
		  jsr   parse_hex3
		  
o_prt3 
      LDAA	#'s'     	
		  JSR	  DATWRT4    	
		  JSR   DELAY
		   	
AGAIN: JSR  a_print	 ; AGAIN ; Former Again end loop. Now returns to check seconds     	
;----------------------------
COMWRT4:               		
		  STAA	TEMP		
		  ANDA  #$F0
		  LSRA
		  LSRA
		  STAA  LCD_DATA
		  BCLR  LCD_CTRL,RS 	
		  BSET  LCD_CTRL,EN 	
		  NOP
		  NOP
		  NOP				
		  BCLR  LCD_CTRL,EN 	
		  LDAA  TEMP
		  ANDA  #$0F
    	LSLA
    	LSLA
  		STAA  LCD_DATA
		  BCLR  LCD_CTRL,RS 	
		  BSET  LCD_CTRL,EN 	
		  NOP
		  NOP
		  NOP				
		  BCLR  LCD_CTRL,EN 	
		  RTS
;--------------		  
DATWRT4:                   	
		  STAA	 TEMP		
		  ANDA   #$F0
		  LSRA
		  LSRA
		  STAA   LCD_DATA
		  BSET   LCD_CTRL,RS 	
		  BSET   LCD_CTRL,EN 	
		  NOP
		  NOP
		  NOP				
		  BCLR   LCD_CTRL,EN 	
		  LDAA   TEMP
		  ANDA   #$0F
    	LSLA
      LSLA
  		STAA   LCD_DATA
  		BSET   LCD_CTRL,RS
		  BSET   LCD_CTRL,EN 	
		  NOP
		  NOP
		  NOP				
		  BCLR   LCD_CTRL,EN 	
		  RTS
;-------------------		  

DELAY

        PSHA		;Save Reg A on Stack
        LDAA    #1		  
        STAA    R3		
;-- 1 msec delay. The Serial Monitor works at speed of 48MHz with XTAL=8MHz on Dragon12+ board
;Freq. for Instruction Clock Cycle is 24MHz (1/2 of 48Mhz). 
;(1/24MHz) x 10 Clk x240x100=1 msec. Overheads are excluded in this calculation.         
L3      LDAA    #100
        STAA    R2
L2      LDAA    #240
        STAA    R1
L1      NOP         ;1 Intruction Clk Cycle
        NOP         ;1
        NOP         ;1
        DEC     R1  ;4
        BNE     L1  ;3
        DEC     R2  ;Total Instr.Clk=10
        BNE     L2
        DEC     R3
        BNE     L3
;--------------        
        PULA			;Restore Reg A
        RTS
;-------------------


;Prints out count, one digit at a time
parse_hex5:
        pshd
        ldaa    #$FF
        staa    select
        puld
        ldx     #$2710       ;10,000 initial divisor value
        bra     hex_con     

        
parse_hex3:
        pshd
        ldaa    #$00
        staa    select   
        puld
        ldx     #$64          ;100 initial divisor value
        bra     hex_con     



hex_con 
               
        pshx 
        IDIV           ;d/x
        leay     $0,x  ;put digit val in y for dig
        
        
        pulx           ;grab prev divisior
        pshd           ;save remainder
        
        
        xgdx           ;put x in d
        
        ldx     #$0a   ;10
        idiv           ;x%=10 next digit
        puld           ;remainder is in d
        
        bra     dig    ;exit is in dig
        
        
        
dig:    
        xgdy           ;put y(digit val) in d and the remainder in y

        subd  #$00
        bne   num1
        
        LDAA  #'0'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
        
num1    subd  #$01
        bne   num2
        
        LDAA  #'1'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
		    
num2    subd  #$01
        bne   num3
        
        LDAA  #'2'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
		    
num3    subd  #$01
        bne   num4
        
        LDAA  #'3'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
		    
num4    subd  #$01
        bne   num5
        
        LDAA  #'4'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
		    
num5    subd  #$01
        bne   num6
        
        LDAA  #'5'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
		    
num6    subd  #$01
        bne   num7
        
        LDAA  #'6'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
		    
num7    subd  #$01
        bne   num8
        
        LDAA  #'7'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
		    
num8    subd  #$01
        bne   num9
        
        LDAA  #'8'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
		    
num9    subd  #$01
        bne   noDig
          
        LDAA  #'9'
	
		    JSR	  DATWRT4    	
		    JSR   DELAY
		    XGDY           ;put remainder back in d from y
		    jsr   hex_con
		    
noDig   
        ldaa  select
        cmpa  #$FF
        beq   br5
        JSR   o_prt3
br5     JSR   o_prt5

;------------------------h-----------
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

;-----------------------------------
;Ch0 Interrupt code
;-----------------------------------
rti_intCh0: 
        	LDAA	TFLG1				;Read flag first
    			ORAA	#TFLG1_Clr	;write 1 to flag for clearing ch 1
    			STAA	TFLG1   		
    			
    			RTI       

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************

            ORG   $FFFE
            DC.W  Entry           ; Reset Vector

            ORG   Vtimch0
            DC.W  rti_intCh0
            
            ORG   Vtimch1
            DC.W  rti_intCh1

            END
