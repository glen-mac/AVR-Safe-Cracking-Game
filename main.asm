;;;;;;;;;;;;; TO DO ;;;;;;;;
;;
;;Do Pot code
;
;;Consider disabling interrupts for PB1 to prevent even handling code
;
;;Put keypad code in Timer0, with 0 prescaler (can disable with toggle macro)
;;when not needed)
;;
;
;;Set TIMER 3 to 8 bit 
;;
;;Rand # is 11bit mask of a timer counter
;;Keypad selection is lower 4 bit mask of rand #
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "m2560def.inc"
.include "macros.asm"

;;;;;;;;;;;;CONSTANTS;;;;;;;;;;;;;;;;;;;
.equ debDELAY = 800 	;Variable debounce delay
.equ PORTLDIR = 0xF0 	; PD7 - 4: output, PD3 - 0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F
.equ counter_initial = 3
.equ counter_find_pot = 20
.equ pot_pos_min = 35 ; our min value on the POT is 21
.equ pot_pos_max = 980
.equ stage_start = 0
.equ stage_countdown = 1
.equ stage_pot_reset = 2
.equ stage_pot_find = 3
.equ stage_code_find = 4
.equ stage_code_enter = 5
.equ stage_win = 6
.equ stage_lose = 7
;;;;;;;;;;;;REGISTER DEFINES;;;;;;;;;;;;
.def debounce = r2  	; debounce flag boolean for push buttons
.def screenStage = r3	; current stage the game is on
.def screenStageFol = r4; a backlog of screenstage
.def counter = r5		; a countdown variable
.def running = r6		
.def row = r16 			; current row number
.def col = r17 			; current column number
.def rmask = r18 		; mask for current row during scan
.def cmask = r19		; mask for current column during scan
.def temp = r20			; temp variable
.def temp2 = r21		; temp variable

.dseg
counterTimer: .byte 2
randomcode: .byte 2
;;;;;;;;;;;;;;;;;;;;;;BACKLIGHT;;;;;;;;;;;;;;;;;;;;;
BacklightCounter: .byte 2 						; counts timer overflows
BacklightSeconds: .byte 1 						; counts number of seconds to trigger backlight fade out
BacklightFadeCounter: .byte 1 					; used to pace the fade in process
BacklightFade: .byte 1 							; flag indicating current backlight process - stable/fade in/fade out
BacklightPWM: .byte 1 							; current backlight brightness

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

.org 0x50
;STRING LIST:  (1 denotes a new line, 0 denotes end of second line)
str_home_msg: .db "2121 16s1", 1, "Safe Cracker", 0
str_findposition_msg: .db "Find POT POS", 1, "Remaining: ", 0
str_timeout_msg: .db "Game over", 1, "You Lose!", 0 
str_win_msg: .db "Game complete", 1, "You Win!", 0 
str_reset_msg: .db "Reset POT to 0", 1, "Remaining ", 0
str_countdown_msg: .db "2121 16s1", 1, "Starting in ", 0
str_entercode_msg: .db "Enter Code", 1, " ", 0
	
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
	;toggle TIMSK2, 1<<TOIE2
	toggle TIMSK3, 1<<TOIE3
	;;;;;;;;prepare MISC;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  	ldi temp, PORTLDIR ; PA7:4/PA3:0, out/in
	sts DDRL, temp
	
	ldi temp, 0xFF
	out DDRC, temp	;PORTC is for LED bar
	out DDRG, temp	;PORTG is for LED bar (top 2 LEDs)
		
	ldi temp, (1 << REFS0) | (0 << ADLAR) | (0 << MUX0);     Set ADC reference to AVCC
	sts ADMUX, temp
	ldi temp, (1 << MUX5); 
	sts ADCSRB, temp
	ldi temp, (1 << ADEN) | (1 << ADATE) | (1 << ADIE) | (5 << ADPS0);ADC ENABLED, FREE RUNNING, INTERRUPT ENABLED, PRESCALER
	sts ADCSRA, temp

	clr temp
	out PORTC, temp  ;BLANK the LED bar
	out PORTG, temp  ;BLANK the top LEDs on LED bar
	
	ldi temp, 0b00010000      ; set PORTE (pins 2&3) to output (Backlight = 2, Motor = 3)
	out DDRE, temp
	ser temp										; clear PORTH
	out PORTE, temp	
	;out OCR3BL, temp
	
	rcall initialiseBacklightTimer  ;;code for the backlight timer
	
	clr r24
	clr r25
	clr r23
	clr r22
	clr screenStage		; initial screen (click left button to start)
	clr counter
	ldii debounce, 1
	ldii running, 0 

	clear_datamem counterTimer
	do_lcd_write_str str_home_msg ;write home message to screen
	sei
	
halt:
	rjmp halt ;do nothing forever!

Timer0OVF: ;This is an 8-bit timer - Game loop.
	push temp
	clr temp
	addi r22, 1
	adc r23, temp
	ldi temp, high(781)
	cpi r22, low(781)
	cpc r23, temp
	breq contTimer0
	pop temp
	reti
	contTimer0:
	clr r22
	clr r23

;createADCint

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
	ldii running, 1
	rcall countdownFunc
	rjmp endTimer0

	potResetSeg:
	ldii running, 1 
	rcall potResetFunc
	rjmp endTimer0

	potFindSeg:
	ldii running, 1 
	rcall potFindFunc
	rjmp endTimer0

	codeFindSeg:
	ldii running, 1 
	rcall codeFindFunc
	rjmp endTimer0

	codeEnterSeg:
	ldii running, 1 
	rjmp endTimer0

	winSeg:
	ldii running, 0 
	do_lcd_write_str str_win_msg  
	rjmp endTimer0
	;Timer:
;	in temp, SREG
;	push temp 
;	push r25
;	push r24 
;	adiw r25:r24, 1
;	cpi r24, low(3906) 
;	ldi temp, high(3906)
;	cpc r25, temp
;	brne endif
;	
;	com flash
;	out PORTC, patlo
;	clr r24
;	clr r25
;	endif:
;	pop r24 
;	pop r25 
;;	pop temp
;	out SREG, temp
;	reti 
	loseSeg:
	ldii running, 0
	toggle TIMSK1, 0
	toggle TIMSK0,0
	do_lcd_write_str str_timeout_msg
	rjmp endTimer0

	endTimer0:
	pop temp
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
	do_lcd_write_str str_reset_msg ;this is the reset pot message?
	ldi temp, 20
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
			cpi col, 5
			ldii screenStage, stage_pot_find
	ret

potFindFunc:
	cpii screenStageFol, stage_pot_find
	breq endpotFindSeg
	do_lcd_write_str str_findposition_msg ;this is the reset pot message?
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
	ldii screenStageFol, stage_code_find
	lds temp, ADCSRA 
	cbr temp, (ADSC + 1)   ;enable ADC
	;sts ADCSRA, temp      ;enable ADC
	endcodeFindSeg:
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
		ldi temp, 20
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
	cpi r24, 30								; check if has been 1sec/0xFF
	brne fadeFinished
	
	clr temp								; reset fade counter
	sts BacklightFadeCounter, temp	

	lds temp, BacklightFade				; check what fade state
	cpi temp, LCD_BACKLIGHT_FADEIN
	breq fadeIn
	cpi temp, LCD_BACKLIGHT_FADEOUT
	breq fadeOut					;if BacklightFade = 0 which is the case when it is first set up
	rjmp fadeFinished

	fadeIn:									; if fading in
		lds temp2, BacklightPWM
		cpi temp2, 0xFF						; check if already max brightness
		breq lcdBacklightMax
		inc temp2							; inc pwm
		sts BacklightPWM, temp2				; store new pwm
		rjmp dispLCDBacklight		

		lcdBacklightMax:
			ldi temp, LCD_BACKLIGHT_STABLE	; set to stable pwm
			sts BacklightFade, temp		; store new fade state
			rjmp fadeFinished

	fadeOut:
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
		;clr temp
		;sts OCR3AH, temp	
	
	fadeFinished:						; if running the backlight should remain on
	cpii running, 1						; check if running
	breq timer3Epilogue
		
	lds r24, BacklightCounter				; load the backlight counter
	lds r25, BacklightCounter+1
	adiw r25:r24, 1							; increment the counter
		
	sts BacklightCounter, r24				; store new values
	sts BacklightCounter+1, r25

	cpi r24, low(7812)						; check if it has been 1 second
	ldi temp, high(7812)
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;KEYPAD LOGIC;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	push col
	push row
	push rmask
	push cmask
	push temp
	clr col
	clr row
	clr rmask
	clr cmask
	clr temp
colloop:
	cpi col, 4
	brne contColloop; If all keys are scanned, repeat.
 	jmp endTimer2
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
	jmp colloop
convert:	
;	rcall backlightFadeIn			;;initialise the backlight to begin to fade in
	cpi col, 3 ; If the pressed key is in col.3 
	breq letters ; we have a letter
				 ; If the key is not in col.3 and
	cpi row, 3 ; If the key is in row3,
	breq symbols; we have a symbol or 0
	mov temp, row ; Otherwise we have a number in 1 -9
	lsl temp
	add temp, row
	add temp, col ; temp = row*3 + col
	subi temp, -'1'
	rjmp comparecode
symbols:
	cpi col, 0 ; Check if we have a star
	breq star ;star
	cpi col, 1 ; or if we have zero
	breq zero
	ldi temp, '#'
	rjmp comparecode
star:
	ldi temp, '*'	;need to display this key too
	rjmp comparecode
zero:
	ldi temp, 0; Set to zero
	rjmp comparecode
letters:	
	cpii screenStage, stage_start
	brne entercode
	A:
	cpi row, 0 ;A
	brne B
;	ldi countdown, 20
;	rjmp ResetPot
	B:
	cpi row, 1 ;B
	brne C
;	ldi countdown, 15
;	rjmp ResetPot
	C:
	cpi row, 2 ;C
	brne D
;	ldi countdown, 10
;	rjmp ResetPot
	D:						
;	ldi countdown, 6
;	rjmp ResetPot	

	entercode:	;if not for difficulty
	ldi temp, 'A'
	add temp, row
comparecode: 		;compare the letter pressed, if it is equal to the sequential letter of the next sequence proceed with the code 
;	lds yl, counterTimer
	;lds yh, counterTimer+1
	
	
	;ldi ZL, LOW(randomcode)
	;ldi ZH, HIGH(randomcode)
	lpm temp2, Z+
	cpse temp2, temp
	rjmp reenter
	ldi temp, '*'			
	do_lcd_data temp
	toggle TIMSK2, 1<<TOIE2
	ldii debounce, 1
endTimer2:
	pop temp
	pop cmask
	pop rmask
	pop row
	pop col
	reti
reenter:
	clr temp 				;to reset if user enters wrong code
	do_lcd_write_str str_entercode_msg
	rjmp endTimer2
	
EXT_INT_R:
	;;;;HOW TO USE PUSH BUTTONS:
	;cpii debounce, 1
	;brne endInt
	;clr debounce
	;;;;DO STUFF HERE
	;toggle TIMSK2, 1<<TOIE2
	;endInt:
	reti

EXT_INT_L:
	cpii debounce, 1
	brne endIntL
	clr debounce
	;check screenstage 'switch statement'
	cpii screenStage, stage_start ;check if on start screen
	brne checkStageWin
	ldii screenStage, stage_countdown
	rjmp preEndInt
	checkStageWin:
	cpii screenStage, stage_win
	brne preEndInt
	ldii screenStage, stage_start
	preEndInt:
	toggle TIMSK2, 1<<TOIE2
	endIntL:
	reti

handleADC:
	push temp
	push rmask
	push cmask
	push temp2

	lds temp2, ADCL 
	;out PORTC, temp2
  	lds temp, ADCH
	;out PORTG, temp

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
		endCheckIfPotFind:
			out PORTC, temp2
			out PORTG, temp
			rjmp endHandleADC	
	endHandleADC:
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

