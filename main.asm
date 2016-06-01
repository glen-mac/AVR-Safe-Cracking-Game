;;;;;;;;;;;;; TO DO ;;;;;;;;
; Get HDs
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "m2560def.inc"
.include "macros.asm"

;;;;;;;;;;;;CONSTANTS;;;;;;;;;;;;;;;;;;;
.equ PORTLDIR			= 0xF0 	; PD7 - 4: output, PD3 - 0, input
.equ INITCOLMASK		= 0xEF 	; scan from the rightmost column,
.equ INITROWMASK		= 0x01 	; scan from the top row
.equ ROWMASK			= 0x0F	; mask for the row
.equ speaker250			= 61	; number of overflows for Timer4 to last 250ms
.equ speaker500			= 122	; number of overflows for Timer4 to last 500ms
.equ speaker1000		= 244	; number of overflows for Timer4 to last 1000ms
.equ max_num_rounds		= 3		; the number of rounds that will be played
.equ counter_initial	= 3		; the intial countdown value (3 seconds)
.equ pot_pos_min		= 22	; the minimum value on the pot (got from testing it)
.equ pot_pos_max		= 1004	; the maximum value on the pot (got from testing it)
.equ stage_start		= 0		; |  The
.equ stage_countdown	= 1		; |		stage
.equ stage_pot_reset	= 2		; |			 values
.equ stage_pot_find		= 3		; |				 representing
.equ stage_code_find	= 4		; |			 what
.equ stage_code_enter	= 5		; |		 stage
.equ stage_win 			= 6		; |	  we are
.equ stage_lose 		= 7		; | on
;;;;;;;;;;;;REGISTER DEFINES;;;;;;;;;;;;
.def debounce			= r2	; a flag debouncing PB1, (used after PB1 is clicked when the game is won or lost - to ensure the game doesnt restart)
.def screenStage		= r3	; the current stage the game is on
.def screenStageFol 	= r4	; a delayed version of screenstage (for checking when it is desired that the initial stage code has already run)
.def counter			= r5	; a generic countdown register
.def running			= r6	; a flag represeting if the backlight should be on indefinitely on the current screen
.def keyButtonPressed	= r7	; an internal debounce flag for the keypad
.def row				= r16 	; keypad current row number
.def col				= r17 	; keypad current column number
.def rmask				= r18 	; keypad mask for current row during scan
.def cmask				= r19	; keypad mask for current column during scan
.def temp				= r20	; temp variable
.def temp2				= r21	; second temp variable
.def keypadCode			= r22	; the 'random' code being searched for on the keypad
.def curRound			= r23	; a counter representing the current round (used for addressing memory)
.def difficultyCount	= r24	; a register holding the countdown value for the current difficulty
.def gameShouldReset	= r25  ;a boolean flag indicating the game is going to reset
;;;;;;;;;;;;DESEG VARIABLES;;;;;;;;;;;;
.dseg
gameloopTimer:			.byte 2	; counts number of timer overflows for gameloop
counterTimer: 			.byte 2	; counts number of timer overflows for counter
keypadTimer: 			.byte 2	; counts number of timer overflows for keypad
randomcode: 			.byte max_num_rounds; stores the 'random' keypad items
BacklightCounter: 		.byte 2 ; counts timer overflows
BacklightSeconds: 		.byte 1	; counts number of seconds to trigger backlight fade out
BacklightFadeCounter: 	.byte 1 ; used to pace the fade in process
BacklightFade: 			.byte 1 ; flag indicating current backlight process - stable/fade in/fade out
BacklightPWM: 			.byte 1 ; current backlight brightness
speakerCounter: 		.byte 1 ; number of loops so far for the speaker timer
speakerCounterGoal:		.byte 1 ; number of loops to do for the duration
randomPosition:			.byte 2	; used for random number (LCG method - interrupts)
highScores:				.byte 4 ; a byte array to store current highscores
;;;;;;;;;;;;VECTOR TABLE;;;;;;;;;;;;;;
.cseg
	jmp RESET
	jmp EXT_INT_R	; right push button
	jmp EXT_INT_L	; left push button
.org OVF0addr
	jmp Timer0OVF	; game loop
.org OVF1addr
	jmp Timer1OVF	; countdown timer
.org OVF2addr
	jmp Timer2OVF	; keypad timer
.org OVF3addr
	jmp Timer3OVF	; backlight timer
.org OVF4addr
	jmp Timer4OVF	; speaker timer
.org 0x3A
	jmp handleADC	; ADC complete reading
;;;;;;;;;;;;STRING LIST;;;;;;;;;;;;;;
.org 0x70 ;(1 denotes a new line, 0 denotes end of second line)
str_home_msg: 			.db 	"2121 16s1", 		1, 		"Safe Cracker",0, 	0
str_keypadscan_msg: 	.db 	"Position found!",	1, 		"Scan for number", 	0
str_findposition_msg: 	.db 	"Find POT POS", 	1, 		"Remaining:      ", 0
str_timeout_msg:		.db 	"Game over", 		1, 		"You Lose!", 		0 
str_win_msg: 			.db 	"Game complete", 	1, 		"You Win!",0, 		0 
str_reset_msg:			.db 	"Reset POT to 0", 	1, 		"Remaining:      ", 0
str_countdown_msg: 		.db 	"2121 16s1", 		1, 		"Starting in ",0, 	0
str_entercode_msg: 		.db 	"Enter Code", 		1, 							0
lcd_char_smiley: 		.db		0x00, 0x00, 0x0A, 0x00, 0x11, 0x0E, 0x00, 0x00
lcd_char_two: 			.db		0x0E, 0x02, 0x04, 0x0F, 0x00, 0x00, 0x00, 0x00
lcd_char_one: 			.db		0x0C, 0x04, 0x04, 0x0E, 0x00, 0x00, 0x00, 0x00
lcd_char_five: 			.db		0x0E, 0x08, 0x06, 0x0E, 0x00, 0x00, 0x00, 0x00
lcd_char_six: 			.db		0x0E, 0x08, 0x0E, 0x0E, 0x00, 0x00, 0x00, 0x00
lcd_char_zero: 			.db		0x0E, 0x0A, 0x0A, 0x0E, 0x00, 0x00, 0x00, 0x00

	
RESET:
	;;;;;;;;prepare STACK;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ldi temp, low(RAMEND) 
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
  	;;;;;;;;prepare LCD;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ser r16
	out DDRF, r16 
	out DDRA, r16 
	;store custom characters into data memory
	do_lcd_store_custom 	0,	lcd_char_zero
	do_lcd_store_custom 	1,	lcd_char_one
	do_lcd_store_custom 	2,	lcd_char_two
	do_lcd_store_custom 	3,	lcd_char_smiley
	do_lcd_store_custom 	5,	lcd_char_five
	do_lcd_store_custom 	6,	lcd_char_six
	;prepare ports
	clr r16
	out PORTF, r16
	out PORTA, r16
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	;do_lcd_command 0b00001100 ; Cursor on, bar, no blink
	;;;;;;;;prepare EXTERNAL INTERRUPTS;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ldi temp, (2 << ISC00)	;set INT0 
	ldi temp, (2 << ISC10)	;and INT1
	sts EICRA, temp			;as falling edge
	in temp, EIMSK
	ori temp, (1<<INT0)		;enable external
	ori temp, (1<<INT1)  	;interrupts 0,1
	out EIMSK, temp
	;;;;;;;;prepare TIMERS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	clr temp
	out TCCR0A, temp
	sts TCCR1A, temp
	sts TCCR2A, temp
	sts TCCR4A, temp
	ldi temp, (1<<CS01)
	out TCCR0B, temp
	;ldi temp, (1<<CS11)  	;not required, but included for completeness
	sts TCCR1B, temp
	;ldi temp, (1<<CS21)	;not required, but included for completeness
	sts TCCR2B, temp
	;ldi temp, (1<<CS31) 	;not required, but included for completeness
	sts TCCR3B, temp
	ldi temp, (1<<CS40)
	sts TCCR4B, temp
	toggle TIMSK0, 1<<TOIE0	 ;timer for game loop
	toggle TIMSK2, 1<<TOIE2  ;timer for keypad
	toggle TIMSK3, 1<<TOIE3	 ;timer for backlight
	;;;;;;;;prepare PORTS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  	ldi temp, PORTLDIR 		;KEYPAD
	sts DDRL, temp			;KEYPAD
	ldi temp, 0b00011000  	;set PORTE (pins 3&4) to output (Backlight = 4, Motor = 3)
	out DDRE, temp			;BACKLIGHT & MOTOR
	ldi temp, 0xFF
	out DDRC, temp			;PORTC is for LED bar
	out DDRG, temp			;PORTG is for LED bar (top 2 LEDs)
	ldi temp, 0b00000001	;set PORTB pin 1 to output for speaker
	out DDRB, temp			;PORTB is for the speaker
	ldi temp, 0b00010000	;pin position 3 is motor, 4 is LCD									
	out PORTE, temp			;PORTE is for the motor and backlight
	clr temp
	out PORTB, temp
	;;;;;;;;prepare ADC;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ldi temp, (1 << REFS0) | (0 << ADLAR) | (0 << MUX0) ;Set ADC reference
	sts ADMUX, temp
	ldi temp, (1 << MUX5); prepare MUX
	sts ADCSRB, temp
	ldi temp,  (1 << ADATE) | (1 << ADIE) | (5 << ADPS0); FREE RUNNING, INTERRUPT ENABLED, PRESCALER
	sts ADCSRA, temp
	;;;;;;;;prepare MISC;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	rcall initialiseBacklightTimer  ;;code for the backlight timer
	cleanAllReg	;clean the registers (clean slate)

	;check if my secret code is stored position 1
	;in EEPROM. If it is, data fields have been initialized
	;at some point. Otherwise we need to prepare them...
	rcall checkIfDataExists	

	;read all data, from highscores to difficulty
	;into locations where appropriate
	ReadSavedData:
	readFromEEPROM 0
	mov difficultyCount, temp
	readFromEEPROM 2
	sts highScores, temp
	readFromEEPROM 3
	sts highScores + 1, temp
	readFromEEPROM 4
	sts highScores + 2, temp
	readFromEEPROM 5
	sts highScores + 3, temp

	;;;;;;;;GAME RESTART SEGMENT;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	gameRestart:

		do_lcd_command 0b00001100 ; Display on, no cursor, no blink

		;disable some timers for the start stage
		toggle TIMSK1, 0
		toggle TIMSK4, 0
		
		;clear things we NEED cleared
		clr screenStage
		clr screenStageFol
		clr counter
		clr running
		clr curRound
		clr gameShouldReset
		sts speakerCounter, counter
		out PORTC, counter
		out PORTG, counter

		;ensure strobe light is off
		in temp, PORTA
		andi temp, 0xFD
		out PORTA, temp	

		;to prevent another game starting after win or lose, 
		;when clicking PB1 (bad)
		;The counters are cleared below, so it will be 100ms until
		;debounce is cleared again, making the debounce perfect!
		ldii debounce, 1 

		;clear data memory
		clear_datamem counterTimer
		clear_datamem gameloopTimer
		clear_datamem keypadTimer
		clear_datamem randomcode
		clear_datamem speakerCounter

		do_lcd_write_str str_home_msg 	;write home message to screen
		do_lcd_command 0b11001111		;move cursor to end of bottom row
		do_lcd_data_i 3					;draw custom character (smiley face :) )

		;check our previous value for difficulty count
		;(only works for 15, 10, 6 and will default to 20 otherwise)
 		Check15:
			cpi difficultyCount, 15
 			brne Check10
 			do_lcd_show_custom 1, 5
 			rjmp endRestoreDifficulty
 		Check10:
 			cpi difficultyCount, 10
 			brne Check6
 			do_lcd_show_custom 1, 0
 			rjmp endRestoreDifficulty
 		Check6:
 			cpi difficultyCount, 6
 			brne Set20
 			do_lcd_show_custom 0, 6
 			rjmp endRestoreDifficulty
		Set20:
			ldi difficultyCount, 20
 			do_lcd_show_custom 2, 0
			endRestoreDifficulty:
	sei

	
halt:
	cpi gameShouldReset, 1 ;should game reset?
	brne halt 
	cli	;don't disturb me while I reset
	rjmp gameRestart ;yes we should reset (set by RESET button, and buttons when at win/lose)

Timer0OVF: ;This is an 8-bit timer - Game loop.
	;timer prologue
	push yl
	push yh
	push temp
	in temp, SREG
	push temp
	lds yl, gameloopTimer
	lds yh, gameloopTimer+1
	adiw Y, 1
	sts gameloopTimer, yl
  	sts gameloopTimer+1, yh
	ldi temp, high(781)
	cpi yl, low(781)
	cpc yh, temp
	breq continueTimer0
	rjmp endTimer0

	continueTimer0:

	clr debounce  				 ;clear debounce flag
	clear_datamem gameloopTimer  ;clear the counter

	;switch case for stage select
	cpii screenStage, stage_countdown
	breq countdownSeg
	cpii screenStage, stage_pot_reset
	breq potResetSeg
	cpii screenStage, stage_pot_find
	breq potFindSeg
	cpii screenStage, stage_code_find
	breq codeFindSeg
	cpii screenStage, stage_code_enter
	breq codeEnterSeg
	cpii screenStage, stage_win
	breq winSeg
	cpii screenStage, stage_lose
	breq loseSeg

	rjmp endTimer0

	countdownSeg:
	rcall countdownFunc
	rjmp endTimer0

	potResetSeg:
	rcall potResetFunc
	rjmp endTimer0

	potFindSeg:
	rcall potFindFunc
	rjmp endTimer0

	codeFindSeg:
	rcall codeFindFunc
	rjmp endTimer0

	codeEnterSeg:
	rcall codeEnterFunc
	rjmp endTimer0

	winSeg:
	rcall winFunc
	rjmp endTimer0

	loseSeg:
	rcall loseFunc
	rjmp endTimer0

	endTimer0:
	pop temp
	out SREG, temp
	pop temp
	pop yh
	pop yl
reti

countdownFunc:
	cpii screenStageFol, stage_countdown 
	breq endCountdownFunc
	ldii running, 1	;backlight should be on
	ldii screenStageFol, stage_countdown 
	do_lcd_write_str str_countdown_msg
	ldi temp, 3	;begin to write countdown to screen
	addi temp, '0'
	do_lcd_data temp
	do_lcd_data_i '.'
	do_lcd_data_i '.'
	do_lcd_data_i '.'
	toggle TIMSK1, 1<<TOIE1 ;countdown timer needs to be on
	endCountdownFunc:
ret

potResetFunc:
	cpii screenStageFol, stage_pot_reset
	brne continuePotResetFunc
	rjmp endPotResetFunc

	continuePotResetFunc:

	ldii screenStageFol, stage_pot_reset
	enable_ADC		;ADC should be on

	do_lcd_write_str str_reset_msg 
	do_lcd_command 0b11001011 ;move cursor on screen (to write countdown)

	mov temp, difficultyCount
	sub temp, counter
	rcall asciiconv	;write countdown on screen
    
	clr row 				; this register used to ensure RESET position is held for 500ms
	clr col					; this register used to count amount of times row has been seen to ->
							; be one (obviously after checking twice in 500ms intervals it is RESET)

	endPotResetFunc:
		cpi row, 1				; is the pot still in reset position?
		breq incrementResetPotCount
		clr col
		ret
		incrementResetPotCount:
			inc col 			; numbers of times seen row as 1
			ldi temp, 5			; has it been 5 x 100ms?
			cp col, temp
			brne endIncrementResetPotCount
			ldii screenStage, stage_pot_find
		endIncrementResetPotCount:
ret

potFindFunc:
	cpii screenStageFol, stage_pot_find
	breq endPotFindFunc
	ldii screenStageFol, stage_pot_find	
	do_lcd_write_str str_findposition_msg ;this is the reset pot message?
	do_lcd_command 0b11001011	; move cursor so countdown can be written
	
	mov temp, difficultyCount
	sub temp, counter
	rcall asciiconv
	
	clr row 			    ; this register used to ensure FIND position is held for 500ms
	clr col					; this register used to count amount of times row has been seen to ->
							; be one (obviously after checking twice in 500ms intervals it is FOUND)
	endPotFindFunc:
		cpi row, 1 			; is the pot still in reset position?
		breq incrementFindPotCount	
		clr col
		ret
		incrementFindPotCount:
			inc col			 ;numbers of times  seen row as 1
			ldi temp, 10	 ;has it been 1s?
			cp col, temp
			brne endIncrementFindPotCount
			ldii screenStage, stage_code_find
		endIncrementFindPotCount:
ret

codeFindFunc:
	cpii screenStageFol, stage_code_find
	brne continueCodeFindFunc
	rjmp endCodeFindFunc

	continueCodeFindFunc:

	rcall updateHighscores ;did we beat a highscore?!?!

	ldii screenStageFol, stage_code_find

	disable_ADC

	rcall randomizePotLocation

	toggle TIMSK1, 0 ;disable countdown

	do_lcd_write_str str_keypadscan_msg
	
	lds keypadCode, TCNT3L		
	andi keypadCode, 0b1111		;take low 4 bits of timer as keypad button (random)

	clr counter	;clear counter (for new round)

	endCodeFindFunc:
ret

codeEnterFunc:
	cpii screenStageFol, stage_code_enter
	breq endCodeEnterFunc
	ldii screenStageFol, stage_code_enter
	do_lcd_command 0b00001110 ;cursor on
	do_lcd_write_str str_entercode_msg

	clr counter	;clear counter to count number of button presses to index memory in data seg

	endCodeEnterFunc:
ret
	
winFunc:
	cpii screenStageFol, stage_win
	breq epilogueWinFunc
	do_lcd_command 0b00001100 ;cursor off
	clr running					;backlight should begin to fade out
	ldii screenStageFol, stage_win
	toggle TIMSK1, 0			;turn off countdown timer
	disable_ADC					;disable adc
	speakerBeepFor speaker1000	;make some noise!!
	do_lcd_write_str str_win_msg
	clr counter					;clear counter for use in the flashing below
	epilogueWinFunc:
		inc counter
		cpii counter, 5
		brne endWinFunc
		toggleStrobe			;toggle strobe at 2hz
		clr counter
	endWinFunc: 
ret

loseFunc:
	cpii screenStageFol, stage_lose
	breq endLoseFunc
	clr running 				;backlight should begin to fade out
	speakerBeepFor speaker1000  ;make some noise :(
	ldii screenStageFol, stage_lose
	toggle TIMSK1, 0			;turn off countdown timer
	disable_ADC 				;disable adc
	ldi temp, 0
	out PORTC, temp				;turn off LED lights
	out PORTG, temp				;turn off LED lights
	do_lcd_write_str str_timeout_msg
	endLoseFunc:
ret

Timer1OVF: ;This is a countdown timer (16-bit)
	push yl
	push yh
	push temp
	in temp, SREG
	push temp
	lds yl, counterTimer
	lds yh, counterTimer+1
	adiw Y, 1
	sts counterTimer, yl
  	sts counterTimer+1, yh
	ldi temp, high(30)
	cpi yl, low(30)
	cpc yh, temp
	breq continueTimer1
	rjmp endTimer1		; fix for out of range branch

	continueTimer1:
		inc counter		;it has been 1 second
		clear_datamem counterTimer

	cpii screenStage, stage_countdown
		breq countInitialCount	;for initial countdown
	cpii screenStage, stage_pot_reset
		breq countPotResetFind 	;for RESET and FIND
	cpii screenStage, stage_pot_find
		breq countPotResetFind 	;for RESET and FIND
	rjmp endTimer1

	countInitialCount:
		ldi temp, counter_initial
		sub temp, counter
		cpi temp, 0								;find time remaining
		brne contInitialCount
		ldii screenStage, stage_pot_reset		;change to POT reset screen
		clr counter	
		clear_datamem counterTimer				;clear counter ready for POT reset screen
		speakerBeepFor speaker500				;beeeeeeeeeep
		rcall randomizePotLocation 
		rjmp endTimer1
		contInitialCount:
			addi temp, '0'
			do_lcd_command 0b11001100  ;shift cursor to where countdown is on screen, to make it smooth
			do_lcd_data temp
			do_lcd_data_i '.'
			do_lcd_data_i '.'
			do_lcd_data_i '.'
			rjmp endTimer1

	countPotResetFind:
		mov temp, difficultyCount
		sub temp, counter
		cpi temp, 0
		brne contPotResetFind
		ldii screenStage, stage_lose	; change to POT timeout
		rjmp endTimer1
		contPotResetFind:			;continues the countPotRestFind code

			speakerBeepFor speaker250	;beep on decrement

			cpii screenStage, stage_pot_find
			brne countPotReset
				do_lcd_command 0b11001011
				rjmp epilogueTimer1
			countPotReset:
				do_lcd_command 0b11001011
				rjmp epilogueTimer1

	epilogueTimer1:
		rcall asciiconv
		rjmp endTimer1
	endTimer1:
		pop temp
		out SREG, temp
		pop temp
		pop yh
		pop yl
reti

Timer3OVF:								
	push temp2
	push temp
	in temp, SREG
	push temp
	push r24
	push r25
	 
	lds r24, BacklightFadeCounter				; load the backlight fade counter
	inc r24										; increment the counter
	sts BacklightFadeCounter, r24
	cpi r24, 15									
	brne fadeFinished
	
	clr temp									; reset fade counter
	sts BacklightFadeCounter, temp	

	lds temp, BacklightFade						; check what fade state
	cpi temp, LCD_BACKLIGHT_FADEIN
	breq FadeIn
	cpi temp, LCD_BACKLIGHT_FADEOUT
	breq FadeOut							; if BacklightFade = 0 which is the case when it is first set up
	rjmp fadeFinished 

	FadeIn:									; if fading in
		lds temp2, BacklightPWM
		cpi temp2, 0xFF						; check if already max brightness
		breq BacklightFin
		inc temp2							; inc pwm
		sts BacklightPWM, temp2				; store new pwm
		rjmp dispBacklight		

	FadeOut:
		lds temp2, BacklightPWM				; if fading out
		cpi temp2, 0x00						; check if min brightness
		breq BacklightFin
		dec temp2							; dec pwm
		sts BacklightPWM, temp2				; store new pwm
		rjmp dispBacklight

	BacklightFin:
		ldi temp, LCD_BACKLIGHT_FULL
		sts BacklightFade, temp
		rjmp endFadeCode

	dispBacklight:						; output backlight
		lds temp, BacklightPWM
		sts OCR3BL, temp
	
	endFadeCode:
		clr temp							; reset the backlight counter
		sts BacklightSeconds, temp
		sts BacklightCounter, temp
		sts BacklightCounter+1, temp
		
	fadeFinished:							; if running the backlight should remain on
	
		cpii running, 1							; check if game is in one of the running stages 
		breq timer3Epilogue 
	
		lds r24, BacklightCounter				; load backlight counter
		lds r25, BacklightCounter+1
		adiw r25:r24, 1							; increment the counter
		sts BacklightCounter, r24				; store incremented value
		sts BacklightCounter+1, r25

		ldi temp, high(3906)
		cpi r24, low(3906)						; check if it has been 1 second
		cpc r25, temp
		brne timer3Epilogue

		clear_datamem BacklightCounter

		lds r24, BacklightTime				; load backlight seconds
		inc r24									; increment the backlight seconds
		sts BacklightTime, r24				; store new value

		cpi r24, 5								; check if it has been 5 seconds
		brne timer3Epilogue
		clr temp							
		sts BacklightTime, temp					; reset the seconds

	fadeOutBacklight:						; start fading out the backlight
		rcall backlightFadeOut
	
	timer3Epilogue:
		pop r25
		pop r24
		pop temp
		out SREG, temp
		pop temp
		pop temp2
reti


Timer4OVF:	;used for the speaker sounds
	push temp
	in temp, SREG
	push temp
	push temp2

	in temp, PORTB		;pull in speaker pin
	ldi temp2, 1
	eor temp, temp2		;toggle speaker pin
	out PORTB, temp	

	lds temp, speakerCounter
	inc temp
	sts speakerCounter, temp
	
	lds temp2, speakerCounterGoal ;have i reached my tone length?
	cp temp, temp2
	brne timer4Epilogue

	toggle TIMSK4, 0		;yes i have, turn me off
	clr temp
	sts speakerCounter, temp
	
	timer4Epilogue:
	pop temp2
	pop temp
	out SREG, temp
	pop temp
reti

Timer2OVF: ;keypad loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;KEYPAD LOGIC;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	push yl
	push yh
	push temp
	in temp, SREG
	push temp

	lds yl, keypadTimer
	lds yh, keypadTimer+1
	adiw Y, 1
	sts keypadTimer, yl
  	sts keypadTimer+1, yh
	ldi temp, high(390)
	cpi yl, low(390)
	cpc yh, temp
	breq continueTimer2
	rjmp endTimer2

	continueTimer2:

	clear_datamem keypadTimer
	push col
	push row
	push rmask
	push cmask
	push temp2
	clr col
	clr row
	clr rmask
	clr temp
	clr temp2
	ldi cmask, INITCOLMASK ; initial column mask

colloop:
	cpi col, 4
	brne contColloop; If all keys are scanned, repeat.
	
	;all keys were scanned, and nothing found...
	cpii screenStageFol, stage_code_find
	breq motorKill
		clr keyButtonPressed	;deal with debouncing
		rjmp epilogueTimer2
	motorKill:					;if on code find, handle the motor stopping
		in temp, PORTE
		andi temp, 0b11110111	;kill off motor pin
		out PORTE, temp
		clr counter				;restart holding counter
 		rjmp epilogueTimer2
	
contColloop:
	sts PORTL, cmask; Otherwise, scan a column.
	ldi temp, 0xFF	; Slow down the scan operation.
delay:
	dec temp
	brne delay
	lds temp, PINL; Read PORTA
	andi temp, ROWMASK; Get the keypad output value
	cpi temp, 0xF; Check if any row is low
	breq nextcol; If yes, find which row - is low
	ldi rmask, INITROWMASK ; Initialize for row check
	clr row
rowloop:
	cpi row, 4
	breq nextcol ; the row scan is over.
	mov temp2, temp
	and temp2, rmask ; check un-masked bit
	breq convert ; if bit is clear, the key is pressed
	inc row; else move to the next row
	lsl rmask
	jmp rowloop
nextcol: ; if row scan is over
	lsl cmask
	inc col ; increase column value
	rjmp colloop
convert:	
	rcall backlightFadeIn	;initialise the backlight to begin to fade in

	;find button pushed..
	mov temp, row 
	lsl temp
	lsl temp
	add temp, col ; temp = row*4 + col
	
	cpii screenStage, stage_win
	breq winLoseReset
	cpii screenStage, stage_lose
	brne checkRemaindingStages

	;when at win/lose screen and a button was pushed...
	winLoseReset:
		cpii keyButtonPressed, 1
		breq endConvert
		ldi gameShouldReset, 1
		rjmp epilogueTimer2

	checkRemaindingStages:
	
	cpii screenStage, stage_start
	breq setDifficulty

	cpii screenStageFol, stage_code_find
	brne checkIfCodeEnter 
	rjmp compareCode

	checkIfCodeEnter:
	cpii screenStageFol, stage_code_enter
	brne endConvert
	rjmp keypadCodeEnter

	endConvert:
	rjmp epilogueTimer2

setDifficulty:	
	Akey:
		cpi temp, 3 ;A
		brne Bkey
		ldi difficultyCount, 20
		do_lcd_show_custom 2, 0
		rjmp storeDiff
	Bkey:
		cpi temp, 7 ;B
		brne Ckey
		ldi difficultyCount, 15
		do_lcd_show_custom 1, 5
		rjmp storeDiff
	Ckey:
		cpi temp, 11 ;C
		brne Dkey
		ldi difficultyCount, 10
		do_lcd_show_custom 1, 0
		rjmp storeDiff
	Dkey:	
		cpi temp, 15 ;D	
		brne StarKey				
		ldi difficultyCount, 6
		do_lcd_show_custom  0, 6
		rjmp storeDiff
	StarKey:
		cpi temp, 12 ;*
		breq showScore20
		rjmp HashKey
		showScore20:	
		cpi difficultyCount, 20
		brne showScore15
			do_lcd_command 0b10001110
			lds temp, highScores
			rcall asciiconv
			rjmp performJMPtimer2End
		showScore15:
		cpi difficultyCount, 15
		brne showScore10
			do_lcd_command 0b10001110
			lds temp, highScores + 1
			rcall asciiconv
			rjmp performJMPtimer2End
		showScore10:
		cpi difficultyCount, 10
		brne showScore6
			do_lcd_command 0b10001110
			lds temp, highScores + 2
			rcall asciiconv
			rjmp performJMPtimer2End
		showScore6:
		cpi difficultyCount, 6
		breq doShowScore6
			rjmp performJMPtimer2End			
			doShowScore6:
			do_lcd_command 0b10001110
			lds temp, highScores + 3
			rcall asciiconv
			rjmp performJMPtimer2End
	HashKey:
		cpi temp, 14 ;hash key (reset highscores)
		breq doScoreClear
		rjmp performJMPtimer2End
			doScoreClear:
			ldi temp, 0
			writeToEEPROM 2, temp
			writeToEEPROM 3, temp
			writeToEEPROM 4, temp
			writeToEEPROM 5, temp
			sts highScores, temp
			sts highScores + 1, temp
			sts highScores + 2, temp
			sts highScores + 3, temp
			rjmp showScore20

	storeDiff:

		writeToEEPROM 0, difficultyCount

	performJMPtimer2End:
		rjmp epilogueTimer2	

keypadCodeEnter:
	cpii keyButtonPressed, 1
		brne enterKey
		rjmp epilogueTimer2

	enterKey:
	
		clr cmask
		ldi yl, low(randomcode) ;get the data memory for the consecutive stored keys
		ldi yh, high(randomcode)
		add yl, counter
		adc yh, cmask ;assuming number of rounds doesn't exceed 255...

		ld temp2, Y

		cp temp, temp2
		breq correctKey	;the correct key was entered
		clr counter
		do_lcd_write_str str_entercode_msg
		rjmp epilogueTimer2

	correctKey:
			
		inc counter						;increment number of correct keys

		do_lcd_data_i '*'				;draw correct key on screen

		ldii keyButtonPressed, 1		;debouncing..

		cpii counter, max_num_rounds	;check if this is the last key
		brne endkeypadCodeEnter

		ldii screenStage, stage_win		;yay we win!!

		endkeypadCodeEnter:
			rjmp epilogueTimer2

compareCode:
	cp temp, keypadCode		;check if the key entered was the correct one
		breq codeMatches
		;otherwise...
		clr counter
		rjmp epilogueTimer2

	codeMatches:

		inc counter
	
		;turn on the motor
		in temp, PORTE	
		ori temp, (1 << 3)
		out PORTE, temp

		cpii counter, 20	;key has been held for 1 second
			brne epilogueTimer2

		;store the correct key entered into data memory to check later..
		clr temp
		ldi yl, low(randomcode)
		ldi yh, high(randomcode)
		add yl,	curRound
		adc yh, temp          ;unless rounds exceeds 255....
		st Y,  keypadCode

		;increment current round and clear some stuff..
		inc curRound
		clr counter
		out PORTC, temp
		out PORTG, temp 

		;kill the motor for good
		in temp, PORTE
		andi temp, 0b11110111	;kill off motor pin
		out PORTE, temp
		ldii screenStageFol, -1 ;just a prevent method, so that motor doesn't run when the view changes 

		cpi curRound, (max_num_rounds) ;is the game over yet?
		breq prepCodeEnter			

		speakerBeepFor speaker500		;beeeep

		toggle TIMSK1, 1<<TOIE1			;enable countdown timer

		ldii screenStage, stage_pot_reset
		clr counter					;clear timer stuff
		clear_datamem counterTimer	;clear timer stuff

		rjmp epilogueTimer2

	prepCodeEnter:
		ldii screenStage, stage_code_enter  ;go to code enter screen
		ldii keyButtonPressed, 1 ;debouncing

epilogueTimer2:
	pop temp2
	pop cmask
	pop rmask
	pop row
	pop col
endTimer2:
	pop temp
	out SREG, temp
	pop temp
	pop yh
	pop yl
reti
	
EXT_INT_R:	;right push button
	push temp
	in temp, SREG
	push temp

	cpii debounce, 0
	brne preEndRestartButton

	rcall backlightFadeIn
	cpii screenStage, stage_start ;check if on start screen
		breq preEndRestartButton
		ldi gameShouldReset, 1

	preEndRestartButton:
	pop temp
	out SREG, temp
	pop temp
reti

EXT_INT_L:	;left push button
	push temp
	in temp, SREG
	push temp

	cpii debounce, 0 ;debouncing so game doesn't start itself
		brne endExtIntL
		rcall backlightFadeIn
	cpii screenStage, stage_start ;check if on start screen
		brne checkStageWin
		ldii screenStage, stage_countdown ;if we are, start countdown
		rjmp endExtIntL

	checkStageWin:
		cpii screenStage, stage_win  ;check if on win screen
			brne checkStageLose
			ldi gameShouldReset, 1
			rjmp endExtIntL

	checkStageLose:
		cpii screenStage, stage_lose	;check if on lose screen
			brne endExtIntL
			ldi gameShouldReset, 1

	endExtIntL:
	pop temp
	out SREG, temp
	pop temp
reti

handleADC:
	push temp
	in temp, SREG
	push temp
	push rmask
	push cmask
	push temp2
	push col

	;read from ADC
	lds temp2, ADCL 
  	lds temp, ADCH

	cpii screenStageFol, stage_pot_reset
		brne checkIfPotFind
		ldi rmask, high(pot_pos_min)
		cpi temp2, low(pot_pos_min)
		cpc temp, rmask		;are we less than the min?
		brge clrRowPreEndADC
		ldi row, 1			; this means that RESET is being held
		rjmp endHandleADC
		clrRowPreEndADC:
			clr row
			rjmp endHandleADC

	checkIfPotFind: ;since we arent on reset pot screen, check if we are on pot find screen

	cpii screenStageFol, stage_pot_find  ;cmask is LOW bits, rmask is HIGH bits
		breq performPotFind
		rjmp endHandleADC

		performPotFind:

		clr col ;boolean for 'adc is higher' to check bounds so we can lose game :(

		cp temp2, cmask
		cpc temp, rmask
		brlo adcIsLower
		rjmp adcIsHigher
		adcIsLower:		;adc is higher than target
			sub cmask, temp2
			sbc rmask, temp	
			rjmp checkBelow16
		adcIsHigher:	;adc is lower than target
			sub temp2, cmask
			sbc temp, rmask
			mov cmask, temp2
			mov rmask, temp
			ldi col, 1
		checkBelow16:	;check if within 16 adc counts
			ldi temp, high(17)
			cpi cmask, low(17)
			cpc rmask, temp
			brsh checkBelow32
			ldi temp2, 0xFF
			ldi temp, 0b11	;for LED
			ldi row, 1		; this means that POSITION is being held
			rjmp endCheckIfPotFind
		checkBelow32:	;check if within 32 adc counts
			clr row		; clear flag (which says we are within 16 ADC)
			ldi temp, high(33)
			cpi cmask, low(33)
			cpc rmask, temp
			brsh checkBelow48
			ldi temp2, 0xFF
			ldi temp, 0b01
			rjmp endCheckIfPotFind
		checkBelow48:	;check if within 48 adc counts
			ldi temp, high(49)
			cpi cmask, low(49)
			cpc rmask, temp
			brsh notWithinAnyBounds
			ldi temp2, 0xFF
			ldi temp, 0b00
			rjmp endCheckIfPotFind
		notWithinAnyBounds:
			clr temp	    ;clear these values, as the LED values will be placed in them 
			clr temp2		;but they will remain blank for within the set bounds
			cpi col, 1
			brne endCheckIfPotFind
			ldii screenStage, stage_pot_reset
		endCheckIfPotFind:
			out PORTC, temp2	;put LED lights on display
			out PORTG, temp
	endHandleADC:
	pop col
	pop temp2
	pop cmask
	pop rmask
	pop temp
	out SREG, temp
	pop temp
reti

asciiconv:	;converts numbers to ascii using the decimal subtraction method		
	push r18
	push r19
	push temp

	clr r18
	clr r19
	numtens:
	cpi temp, 10
	brlo numones ;branch if lower due to unsigned
	inc r19
	subi temp, 10
	rjmp numtens
	numones:
	mov r18, temp
	ldi temp, '0'
	addi r19, '0'
	do_lcd_data r19	;display tens
	addi r18, '0'
	do_lcd_data r18	;display ones

	pop temp
	pop r19
	pop r18
	ret

randomizePotLocation:
	push temp
	push temp2

	pickRandPotVal:
	lds cmask,  TCNT3L	   	; this register used to hold LOW 8 bits of RAND number
	mov rmask,  cmask       ; this register used to hold HIGH bits of RAND number
	andi rmask, 0b11
	
	;if outside bounds of POT, reset the value
	ldi temp, high(pot_pos_max)
	cpi cmask, low(pot_pos_max)
	cpc rmask, temp
	brsh pickRandPotVal
	;if outside bounds of POT, reset the value
	ldi temp, high(pot_pos_min)
	cpi cmask, low(pot_pos_min)
	cpc rmask, temp
	brlo pickRandPotVal

	pop temp2
	pop temp
ret


;a macro for the function below to prevent
;code from being repeated, and to clean it up a bit
.macro scoreCheckMacro
	lds temp2, highScores + @0 
	cp temp2, col
	brsh @1 	;if current score is the same or worse then leave
	writeToEEPROM @2, col ;store score in EEPROM
	sts highScores + @0, col  ;store score in local data memory
	rjmp endUpdateHighscores
.endmacro

;a function to check if the current remaining time
;on the clock, is greater than the highscore for the
;respective current difficulty. If it is, stores to
;EEPROM and updates current data memory for display
;purposes
updateHighscores:
	push col
	push temp2

	mov col, difficultyCount ;find remaining time left
	sub col, counter		 ;find remaining time left
	;switch case for current difficulty
	cpi difficultyCount, 20
	breq Score20
	cpi difficultyCount, 15
	breq Score15
	cpi difficultyCount, 10
	breq Score10
	cpi difficultyCount, 6
	breq Score6

	goToEndOfHScores:
	rjmp endUpdateHighscores

	Score20: ;if current difficulty is 20
		scoreCheckMacro 0, goToEndOfHScores, 2
	Score15: ;if current difficulty is 15
		scoreCheckMacro 1, endUpdateHighscores, 3
	Score10: ;if current difficulty is 10
		scoreCheckMacro 2, endUpdateHighscores, 4
	Score6: ;if current difficulty is 6
		scoreCheckMacro 3, endUpdateHighscores, 5

	endUpdateHighscores:
	pop temp2
	pop col
ret

;;;;;;;LEAVE THIS HERE;;;;;;;;
.include "backlight.asm"
.include "LCD.asm"

;checks if EEPROM has been initilized at some point
;if not, does so in preparation for gameplay
checkIfDataExists:
	push col
	readFromEEPROM 1
	cpi temp, 0xAA
	brne performDataInit
	rjmp endOfSaveChecking
		performDataInit:
		ldi col, 20
		writeToEEPROM 0, col ;difficulty
		ldi col, 0
		writeToEEPROM 5, col ;save score for 6s
		writeToEEPROM 4, col ;save score for 10s
		writeToEEPROM 3, col ;save score for 15s
		writeToEEPROM 2, col ;save score for 20s
		ldi col, 0xAA
		writeToEEPROM 1, col ;unique initialized flag
	endOfSaveChecking:
		pop col
ret

