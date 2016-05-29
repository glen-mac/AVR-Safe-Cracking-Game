;;;;;;;;;;;;; TO DO ;;;;;;;;
; Get Keypad done, then implement rcall backlightFadeIn after we detect precense in the keypad
;
; 'RESET POT' doesn't last 500ms, neither does the FIND POT hold for 1000ms
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "m2560def.inc"
.include "macros.asm"

;;;;;;;;;;;;CONSTANTS;;;;;;;;;;;;;;;;;;;
;.equ debDELAY = 800 	;Variable debounce delay
.equ PORTLDIR			= 0xF0 	; PD7 - 4: output, PD3 - 0, input
.equ INITCOLMASK		= 0xEF ; scan from the rightmost column,
.equ INITROWMASK		= 0x01 ; scan from the top row
.equ ROWMASK			= 0x0F
.equ max_num_rounds		= 1
.equ counter_initial	= 3
.equ counter_find_pot	= 20
.equ pot_pos_min		= 35 ; our min value on the POT is 21
.equ pot_pos_max		= 980
.equ stage_start		= 0
.equ stage_countdown	= 1
.equ stage_pot_reset	= 2
.equ stage_pot_find		= 3
.equ stage_code_find	= 4
.equ stage_code_enter	= 5
.equ stage_win 			= 6
.equ stage_lose 		= 7
;;;;;;;;;;;;REGISTER DEFINES;;;;;;;;;;;;
.def debounce			= r2
.def screenStage		= r3	; current stage the game is on
.def screenStageFol 	= r4	; a backlog of screenstage
.def counter			= r5	; a countdown variable
.def running			= r6	
.def keyButtonPressed	= r7	
.def row				= r16 	; current row number
.def col				= r17 	; current column number
.def rmask				= r18 	; mask for current row during scan
.def cmask				= r19	; mask for current column during scan
.def temp				= r20	; temp variable
.def temp2				= r21	; temp variable
.def keypadCode			= r22
.def curRound			= r23
.def difficultyCount	= r24

.dseg
gameloopTimer:			.byte 2	; counts number of timer overflows for gameloop
counterTimer: 			.byte 2	; counts number of timer overflows for counter
keypadTimer: 			.byte 2	; counts number of timer overflows for keypad
randomcode: 			.byte max_num_rounds; stores the 3 'random' keypad items
BacklightCounter: 		.byte 2 ; counts timer overflows
BacklightSeconds: 		.byte 1	; counts number of seconds to trigger backlight fade out
BacklightFadeCounter: 	.byte 1 ; used to pace the fade in process
BacklightFade: 			.byte 1 ; flag indicating current backlight process - stable/fade in/fade out
BacklightPWM: 			.byte 1 ; current backlight brightness

.cseg
;.org 0x0
	jmp RESET
;.org 0x2
	jmp EXT_INT_R	;right push button
;.org 0x4
	jmp EXT_INT_L	;left push button
.org OVF0addr
	jmp Timer0OVF	;game loop
.org OVF1addr
	jmp Timer1OVF	;debounce timer for push buttons
.org OVF2addr
	jmp Timer2OVF	;debounce timer for push buttons
.org OVF3addr
	jmp Timer3OVF	;keypad search code
.org 0x3A
	jmp handleADC

.org 0x70 ;STRING LIST:  (1 denotes a new line, 0 denotes end of second line)
str_home_msg: 			.db 	"2121 16s1", 		1, 		"Safe Cracker", 	0
str_keypadscan_msg: 	.db 	"Position found!",	1, 		"Scan for number", 	0
str_findposition_msg: 	.db 	"Find POT POS", 	1, 		"Remaining: ", 		0
str_timeout_msg:		.db 	"Game over", 		1, 		"You Lose!", 		0 
str_win_msg: 			.db 	"Game complete", 	1, 		"You Win!", 		0 
str_reset_msg:			.db 	"Reset POT to 0", 	1, 		"Remaining ", 		0
str_countdown_msg: 		.db 	"2121 16s1", 		1, 		"Starting in ", 	0
str_entercode_msg: 		.db 	"Enter Code", 		1, 							0
	
RESET:
	;;;;;;;;prepare STACK;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ldi temp, low(RAMEND) ; initialize the stack
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
  	;;;;;;;;prepare LCD;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ser r16
	out DDRF, r16 ;LCD?
	out DDRA, r16 
	clr r16
	out PORTF, r16
	out PORTA, r16
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
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
	sts TCCR3A, temp
	ldi temp, (1<<CS01)
	out TCCR0B, temp
	ldi temp, (1<<CS11)
	sts TCCR1B, temp
	ldi temp, (1<<CS21)
	sts TCCR2B, temp
	ldi temp, (1<<CS11)
	sts TCCR3B, temp
	toggle TIMSK0, 1<<TOIE0
	toggle TIMSK2, 1<<TOIE2  ;timer for difficulty
	toggle TIMSK3, 1<<TOIE3
	;;;;;;;;prepare MISC;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  	ldi temp, PORTLDIR 	;KEYPAD
	sts DDRL, temp
	ldi temp, 0b00011000  ; set PORTE (pins 3&4) to output (Backlight = 4, Motor = 3)
	out DDRE, temp
	ldi temp, 0xFF
	out DDRC, temp	;PORTC is for LED bar
	out DDRG, temp	;PORTG is for LED bar (top 2 LEDs)
	ldi temp, 0b00010000	;	pin position 3 is motor, 4 is LCD									
	out PORTE, temp	
	clr temp
	out PORTC, temp  ;BLANK the LED bar
	out PORTG, temp  ;BLANK the top LEDs on LED bar
		
	ldi temp, (1 << REFS0) | (0 << ADLAR) | (0 << MUX0);     Set ADC reference to AVCC
	sts ADMUX, temp
	ldi temp, (1 << MUX5); 
	sts ADCSRB, temp
	ldi temp, (1 << ADEN) | (1 << ADATE) | (1 << ADIE) | (5 << ADPS0);ADC ENABLED, FREE RUNNING, INTERRUPT ENABLED, PRESCALER
	sts ADCSRA, temp

	rcall initialiseBacklightTimer  ;;code for the backlight timer
	
	cleanAllReg
	ldi difficultyCount, 20
	ldii debounce, 1 ;to prevent reset after win or lose, automatically starting another game when clicking PB1

	clear_datamem counterTimer
	clear_datamem gameloopTimer
	clear_datamem keypadTimer

	do_lcd_write_str str_home_msg ;write home message to screen

	sei
	
halt:
	rjmp halt ;do nothing forever!

Timer0OVF: ;This is an 8-bit timer - Game loop.
	push yl
	push yh
	push temp
	lds yl, gameloopTimer
	lds yh, gameloopTimer+1
	adiw Y, 1
	sts gameloopTimer, yl
  	sts gameloopTimer+1, yh
	ldi temp, high(781)
	cpi yl, low(781)
	cpc yh, temp
	breq contTimer0
	rjmp endTimer0

	contTimer0:

	clr debounce	;clear debounce flag
	clear_datamem gameloopTimer

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
	;ldii running, 1
	rcall countdownFunc
	rjmp endTimer0

	potResetSeg:
	;ldii running, 1 
	rcall potResetFunc
	rjmp endTimer0

	potFindSeg:
	;ldii running, 1 
	rcall potFindFunc
	rjmp endTimer0

	codeFindSeg:
	;ldii running, 1 
	rcall codeFindFunc
	rjmp endTimer0

	codeEnterSeg:
	;ldii running, 1 
	rcall codeEnterFunc
	rjmp endTimer0

	winSeg:
	cpii screenStageFol, stage_win
	breq endwinSeg
	ldii screenStageFol, stage_win
	;ldii running, 0 
	do_lcd_write_str str_win_msg  
	endwinSeg:
	rjmp endTimer0

	loseSeg:
	;ldii running, 0
	toggle TIMSK1, 0
	toggle TIMSK0,0
	do_lcd_write_str str_timeout_msg
	rjmp endTimer0

	endTimer0:
	pop temp
	pop yh
	pop yl
	reti

countdownFunc:
	cpii screenStageFol, stage_countdown
	breq endcountdownSeg
	do_lcd_write_str str_countdown_msg
	ldi temp, 3
	addi temp, '0'
	do_lcd_data temp
	do_lcd_data_i '.'
	do_lcd_data_i '.'
	do_lcd_data_i '.'
	toggle TIMSK1, 1<<TOIE1
	ldii screenStageFol, stage_countdown
	endcountdownSeg:
	ret

potResetFunc:
	cpii screenStageFol, stage_pot_reset
	breq endpotResetSeg
	;toggle TIMSK2, 0  ;disable keypad
	do_lcd_write_str str_reset_msg ;this is the reset pot message?
	mov temp, difficultyCount
	rcall asciiconv
	ldii screenStageFol, stage_pot_reset
	lds temp, ADCSRA      ;enable ADC
	ori temp, (1 << ADSC) ;enable ADC
	sts ADCSRA, temp      ;enable ADC
	clr row 				; this register used to ensure RESET position is helf for 500ms
	clr col					; this register used to counter amount of times row has been seen to
							; be one (obviously after checking twice in 500ms intervals it is RESET)
	endpotResetSeg:
		cpi row, 1
		breq incRESETpotCount	;BRNE out of range, so a quick fix
		clr col
		ret
		incRESETpotCount:
			inc col ;numbers of times you have seen row as 1
			ldi temp, 100
			cpse col, temp
			ldii screenStage, stage_pot_find
	ret

potFindFunc:
	cpii screenStageFol, stage_pot_find
	breq endpotFindSeg
	do_lcd_write_str str_findposition_msg ;this is the reset pot message?
	mov temp, difficultyCount
	sub temp, counter
	rcall asciiconv
	ldii screenStageFol, stage_pot_find
	pickRandPotVal:
	lds cmask, TCNT1L	    ; this register used to hold LOW 8 bits of RAND number
	lds rmask, TCNT1H       ; this register used to hold HIGH bits of RAND number
	andi rmask, 0b11
	
	ldi temp, high(pot_pos_max)
	cpi cmask, low(pot_pos_max)
	cpc rmask, temp
	brsh pickRandPotVal

	ldi temp, high(pot_pos_min)
	cpi cmask, low(pot_pos_min)
	cpc rmask, temp
	brlo pickRandPotVal

	clr row 			    ; this register used to ensure FIND position is helf for 500ms
	clr col					; this register used to counter amount of times row has been seen to
							; be one (obviously after checking twice in 500ms intervals it is FOUND)
	endpotFindSeg:
		cpi row, 1
		breq incFINDpotCount	;BRNE out of range, so a quick fix
		clr col
		ret
		incFINDpotCount:
			inc col ;numbers of times you have seen row as 1
			cpi col, 10
			ldii screenStage, stage_code_find
	ret

codeFindFunc:
	cpii screenStageFol, stage_code_find
	breq endcodeFindSeg

	toggle TIMSK1, 0 ;disable countdown
	ldii screenStageFol, stage_code_find
	do_lcd_write_str str_keypadscan_msg
	lds temp, ADCSRA 
	cbr temp, (ADSC + 1)   ;enable ADC
	sts ADCSRA, temp      ;enable ADC
	
	lds keypadCode, TCNT3L
	andi keypadCode, 0b1111

	clr counter	;clear counter to count timers the correct button was held

	endcodeFindSeg:
	ret

codeEnterFunc:
	cpii screenStageFol, stage_code_enter
	breq endcodeEnterSeg

	ldii screenStageFol, stage_code_enter
	do_lcd_write_str str_entercode_msg

	clr counter	;clear counter to count number of button presses to index memory in data seg

	endcodeEnterSeg:
	ret
	

Timer1OVF: ;This is a countdown timer (16-bit)
	push yl
	push yh
	push temp
	lds yl, counterTimer
	lds yh, counterTimer+1
	adiw Y, 1
	sts counterTimer, yl
  	sts counterTimer+1, yh
	ldi temp, high(30)
	cpi yl, low(30)
	cpc yh, temp
	breq timer1Second
	rjmp endTimer1		; fix for out of range branch

	timer1Second:
		inc counter
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
		cpi temp, 0
		brne contInitialCount
		ldii screenStage, stage_pot_reset		; change to POT reset screen
		clr counter								; clear counter ready for POT reset screen
		rjmp endTimer1
		contInitialCount:
			addi temp, '0'
			do_lcd_write_str str_countdown_msg
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
		ldii screenStage, stage_lose			; change to POT timeout
		rjmp endTimer1
		contPotResetFind:			;continues the countPotRestFind code
			cpii screenStage, stage_pot_find
			brne countPotReset
				do_lcd_write_str str_findposition_msg
				rjmp Timer1prologue
			countPotReset:
				do_lcd_write_str str_reset_msg
				rjmp Timer1prologue

	Timer1prologue:
		rcall asciiconv
		rjmp endTimer1
	endTimer1:
		pop temp
		pop yh
		pop yl
		reti

Timer3OVF:									; interrupt subroutine timer 2
	push temp
	push temp2
	in temp, SREG
	push temp
	push r24
	push r25

	lds r24, BacklightFadeCounter						; load the backlight fade counter
	inc r24									; increment the counter
	sts BacklightFadeCounter, r24
	cpi r24, 15							; check if has been 0.5sec/0xFF
	brne fadeFinished
	
	clr temp								; reset fade counter
	sts BacklightFadeCounter, temp	

	lds temp, BacklightFade						; check what fade state
	cpi temp, LCD_BACKLIGHT_FADEIN
	breq FadeIn
	cpi temp, LCD_BACKLIGHT_FADEOUT
	breq FadeOut							;if BacklightFade = 0 which is the case when it is first set up
	rjmp FadeFinished 

	FadeIn:									; if fading in
		lds temp2, BacklightPWM
		cpi temp2, 0xFF						; check if already max brightness
		breq lcdBacklightMax
		inc temp2							; inc pwm
		sts BacklightPWM, temp2				; store new pwm
		rjmp dispLCDBacklight		

		lcdBacklightMax:
			ldi temp, LCD_BACKLIGHT_STABLE	; set to stable pwm
			sts BacklightFade, temp		; store new fade state
			rjmp FadeFinished

	FadeOut:
		lds temp2, BacklightPWM				; if fading out
		cpi temp2, 0x00						; check if min brightness
		breq lcdBacklightMin
		dec temp2							; dec pwm
		sts BacklightPWM, temp2				;store new pwm
		rjmp dispLCDBacklight

		lcdBacklightMin:
			ldi temp, LCD_BACKLIGHT_STABLE
			sts BacklightFade, temp
			rjmp fadeFinished

	dispLCDBacklight:
		lds temp, BacklightPWM
		sts OCR3BL, temp
		
	FadeFinished:						; if running the backlight should remain on
	lds r24, BacklightCounter				; load the backlight counter
	lds r25, BacklightCounter+1
	adiw r25:r24, 1							; increment the counter
	sts BacklightCounter, r24				; store new values
	sts BacklightCounter+1, r25

	cpi r24, low(3906)						; check if it has been 1 second
	ldi temp, high(3906)
	cpc r25, temp
	brne timer3Epilogue
	
	clr temp							; clear the counter
	sts BacklightCounter, temp
	sts BacklightCounter+1, temp

	lds r24, BacklightSeconds				; load backlight seconds
	inc r24									; increment the backlight seconds
	sts BacklightSeconds, r24				; store new value

	cpi r24, 5								; check if it has been 5 seconds
	brne timer3Epilogue
	clr temp							
	sts BacklightSeconds, temp					; reset the seconds
	cpii running, 1						; check if game is in one of the running stages 
	breq timer3Epilogue 
	fadeOutBacklight:						; start fading out the backlight
		rcall backlightFadeOut
	
	timer3Epilogue:
	pop r25
	pop r24
	pop temp
	out SREG, temp
	pop temp2
	pop temp
	reti

Timer2OVF: ;keypad loop
	push yl
	push yh
	push temp

	lds yl, keypadTimer
	lds yh, keypadTimer+1
	adiw Y, 1
	sts keypadTimer, yl
  	sts keypadTimer+1, yh
	ldi temp, high(390)
	cpi yl, low(390)
	cpc yh, temp
	breq contTimer2
	rjmp endTimer2

	contTimer2:

	clear_datamem keypadTimer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;KEYPAD LOGIC;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
	
	;check if in findCode
	cpii screenStageFol, stage_code_find
	breq motorKill
	clr keyButtonPressed
	rjmp prologueTimer2
	motorKill:
	clr temp
	out PORTE, temp
	clr counter
 	rjmp prologueTimer2
	
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
;	rcall backlightFadeIn			;;initialise the backlight to begin to fade in
	mov temp, row 
	lsl temp
	lsl temp
	add temp, col ; temp = row*4 + col
	
	cpii screenStage, stage_win
	breq winLoseReset
	cpii screenStage, stage_lose
	brne checkRemaindingStages

	winLoseReset:
	rjmp RESET

	checkRemaindingStages:
	
	cpii screenStage, stage_start
	breq setDifficulty

	cpii screenStageFol, stage_code_find
	brne checkIfCodeEnter 
	rjmp compareCode

	checkIfCodeEnter:
	cpii screenStageFol, stage_code_enter
	breq keypadCodeEnter

	rjmp prologueTimer2
setDifficulty:	
	A:
	cpi temp, 3 ;A
	brne B
	ldi difficultyCount, 20
	rjmp prologueTimer2
	B:
	cpi temp, 7 ;B
	brne C
	ldi difficultyCount, 15
	rjmp prologueTimer2
	C:
	cpi temp, 11 ;C
	brne D
	ldi difficultyCount, 10
	rjmp prologueTimer2
	D:	
	cpi temp, 15 ;C	
	brne performJMPtimer2End				
	ldi difficultyCount, 6

	performJMPtimer2End:
	rjmp prologueTimer2	

keypadCodeEnter:

	cpii keyButtonPressed, 1
	brne enterKey
	rjmp prologueTimer2

	enterKey:
	
	clr cmask
	ldi yl, low(randomcode)
	ldi yh, high(randomcode)
	add yl, counter
	adc yh, cmask ;assuming number of rounds doesn't exceed 255...

	ld temp2, Y

	cp temp, temp2
	breq correctKey
	clr counter
	do_lcd_write_str str_entercode_msg
	rjmp prologueTimer2

	correctKey:
		
		inc counter		

		do_lcd_data_i '*'

		ldii keyButtonPressed, 1

		cpii counter, max_num_rounds
		brne endkeypadCodeEnter

		ldii screenStage, stage_win

		endkeypadCodeEnter:
		rjmp prologueTimer2

compareCode:

	cp temp, keypadCode
	breq codeMatches
	clr counter

	rjmp prologueTimer2
	codeMatches:

	inc counter

	in temp, PORTE
	ori temp, (1 << 3)
	out PORTE, temp

	cpii counter, 20
	brne prologueTimer2

	clr temp
	ldi yl, low(randomcode)
	ldi yh, high(randomcode)
	add yl,	curRound
	adc yh, temp          ;unless rounds exceeds 255....
	st Y,  keypadCode

	inc curRound
	clr counter
	out PORTC, temp
	out PORTG, temp


	clr temp
	out PORTE, temp
	ldii screenStageFol, -1 ;just a prevent set, so that motor doesn't run when the view changes 

	cpi curRound, (max_num_rounds) 
	breq prepCodeEnter

		toggle TIMSK1, 1<<TOIE1
		lds temp, ADCSRA 		;enable ADC
		sbr temp, (ADSC + 1)   ;enable ADC
		sts ADCSRA, temp      ;enable ADC
		ldii screenStage, stage_pot_reset
		rjmp prologueTimer2

	prepCodeEnter:
	ldii screenStage, stage_code_enter
	ldii keyButtonPressed, 1
	rjmp prologueTimer2

prologueTimer2:
	pop temp2
	pop cmask
	pop rmask
	pop row
	pop col
endTimer2:
	pop temp
	pop yh
	pop yl
	reti
;reenter:
;	clr temp 				;to reset if user enters wrong code
;	do_lcd_write_str str_entercode_msg
;	rjmp endTimer2
	
EXT_INT_R:
	rjmp RESET
	reti

EXT_INT_L:
	cpii debounce, 0
	brne preEndInt

	cpii screenStage, stage_start ;check if on start screen
	brne checkStageWin
	ldii screenStage, stage_countdown
	rjmp preEndInt

	checkStageWin:
	cpii screenStage, stage_win
	brne checkStageLose
	rjmp RESET

	checkStageLose:
	cpii screenStage, stage_lose
	brne preEndInt
	rjmp RESET	

	preEndInt:
	reti

handleADC:
	push temp
	push rmask
	push cmask
	push temp2
	push col

	lds temp2, ADCL 
  	lds temp, ADCH

	cpii screenStageFol, stage_pot_reset
		brne checkIfPotFind
		ldi rmask, high(pot_pos_min)
		cpi temp2, low(pot_pos_min)
		cpc temp, rmask
		brge clrRowPreEndADC
		ldi row, 1		; this means that RESET is being held
		rjmp endHandleADC
		clrRowPreEndADC:
			clr row
			rjmp endHandleADC

	checkIfPotFind:

	cpii screenStageFol, stage_pot_find  ;cmask is LOW bits, rmask is HIGH bits
		breq performPotFind
		rjmp endHandleADC

		performPotFind:

		clr col ;boolean for adc is higher to check bounds so we cna lose game

		cp temp2, cmask
		cpc temp, rmask
		brlo adcIsLower
		rjmp adcIsHigher
		adcIsLower:	
			sub cmask, temp2
			sbc rmask, temp	
			rjmp checkBelow16
		adcIsHigher:
			sub temp2, cmask
			sbc temp, rmask
			mov cmask, temp2
			mov rmask, temp
			ldi col, 1
		checkBelow16:
			ldi temp, high(17)
			cpi cmask, low(17)
			cpc rmask, temp
			brsh checkBelow32
			ldi temp2, 0xFF
			ldi temp, 0b11	;for LED
			ldi row, 1		; this means that POSITION is being held
			rjmp endCheckIfPotFind
		checkBelow32:
			clr row			; clear flag (which says we are within 16 ADC)
			ldi temp, high(33)
			cpi cmask, low(33)
			cpc rmask, temp
			brsh checkBelow48
			ldi temp2, 0xFF
			ldi temp, 0b01
			rjmp endCheckIfPotFind
		checkBelow48:
			ldi temp, high(49)
			cpi cmask, low(49)
			cpc rmask, temp
			brsh notWithinAnyBounds
			ldi temp2, 0xFF
			ldi temp, 0b00
			rjmp endCheckIfPotFind
		notWithinAnyBounds:
			clr temp	    ;clear these values, as the LED values will be placed in them 
			clr temp2			;but they will remain blank in for within the set bounds
			cpi col, 1
			brne endCheckIfPotFind
			ldii screenStage, stage_pot_reset
		endCheckIfPotFind:
			out PORTC, temp2
			out PORTG, temp
			rjmp endHandleADC	
	endHandleADC:
	pop col
	pop temp2
	pop cmask
	pop rmask
	pop temp
	reti

asciiconv:				;no need for ascii convert as digits show up as '*' (we need this for count down)
	push r17
	push r18
	push r19
	push temp
	clr r18
	clr r19
	clr r17
  	numhundreds:
 	cpi temp, 100
 	brlo numtens ;branch if lower due to unsigned
 	inc r17
 	subi temp, 100
 	rjmp numhundreds
	numtens:
	cpi temp, 10
	brlo numones ;branch if lower due to unsigned
	inc r19
	subi temp, 10
	rjmp numtens
	numones:
	mov r18, temp
	ldi temp, '0'
	addi r17, '0'
 	cpse r17, temp
 	do_lcd_data r17
	addi r19, '0'
	do_lcd_data r19
	addi r18, '0'
	do_lcd_data r18
	pop temp
	pop r19
	pop r18
	pop r17
	ret

;;;;;;;LEAVE THIS HERE - NEEDS TO BE INCLUDED LAST!!!;;;;;;;
.include "backlight.asm"
.include "LCD.asm"

