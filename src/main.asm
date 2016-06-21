;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; SAFE CRACKER ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GAME ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;This file is for storing the MAIN code of the Game!;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;By Glenn & Jerry ;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
.def gameShouldReset	= r25   ;a boolean flag indicating the game is going to reset
;;;;;;;;;;;;;DSEG VARIABLES;;;;;;;;;;;;
.dseg
gameloopTimer:			.byte 2	; counts number of timer overflows for gameloop
counterTimer: 			.byte 2	; counts number of timer overflows for counter
keypadTimer: 			.byte 2	; counts number of timer overflows for keypad
randomcode: 			.byte max_num_rounds; stores the 'random' keypad items
BacklightCounter: 		.byte 2 ; counts timer overflows
;BacklightTime	: 		.byte 1	; counts number of seconds to trigger backlight fade out
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
;;;;;;;;;;;;;;STRING LIST;;;;;;;;;;;;;;;;;;;
.org 0x70 ;(1 denotes a new line, 0 denotes end of second line)
str_home_msg: 			.db 	"2121 16s1", 		1, 		"Safe Cracker",0, 	0
str_keypadscan_msg: 	.db 	"Position found!",	1, 		"Scan for number", 	0
str_findposition_msg: 	.db 	"Find POT POS", 	1, 		"Remaining:      ", 0
str_timeout_msg:		.db 	"Game over", 		1, 		"You Lose!", 		0 
str_win_msg: 			.db 	"Game complete", 	1, 		"You Win!",0, 		0 
str_reset_msg:			.db 	"Reset POT to 0", 	1, 		"Remaining:      ", 0
str_countdown_msg: 		.db 	"2121 16s1", 		1, 		"Starting in ",0, 	0
str_entercode_msg: 		.db 	"Enter Code", 		1, 							0
;;;;;;;;;;;;CUSTOM CHARACTER LIST;;;;;;;;;;;;;;
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

;this is where the game sits between interrupts, checking if it should reset
halt:
	cpi gameShouldReset, 1 ;should game reset?
	brne halt 
	cli	;don't disturb me while I reset
	rjmp gameRestart ;yes we should reset (set by RESET button, and buttons when at win/lose)

	
EXT_INT_R:	;right push button (RESET game!!)
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

EXT_INT_L:	;left push button (start game, return home)
	push temp
	in temp, SREG
	push temp

	cpii debounce, 0 ;debouncing so game doesn't start itself
		brne endExtIntL
		rcall backlightFadeIn ;begin to fade in LCD
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
.include "TimerGameLoop.asm"
.include "TimerCountdown.asm"
.include "TimerBacklight.asm"
.include "TimerSpeaker.asm"
.include "TimerKeypad.asm"
.include "AdcHandler.asm"
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

