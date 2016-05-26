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
;;Rand # is 11bit mask of a tiemr counter
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
.def screenStageFol	= r4; a backlog of screenstage
.def counter = r5		; a countdown variable
.def row = r16 			; current row number
.def col = r17 			; current column number
.def rmask = r18 		; mask for current row during scan
.def cmask = r19		; mask for current column during scan
.def temp = r20			; temp variable
.def temp2 = r21		; temp variable

.dseg
counterTimer: .byte 2

.cseg
	jmp RESET
;.org 0x0002
	jmp EXT_INT_R	;right push button
;.org 0x0004
	jmp EXT_INT_L	;left push button
.org OVF0addr
	jmp Timer0OVF	;game loop
.org OVF1addr
	jmp Timer1OVF	;debounce timer for push buttons
.org OVF2addr
	jmp Timer2OVF	;debounce timer for push buttons
.org OVF3addr
	jmp Timer3OVF	;keypad search code
;STRING LIST:  (1 denotes a new line, 0 denotes end of second line)
str_home_msg: .db "2121 16s1", 1, "Safe Cracker", 0
str_findposition_msg: .db "Find POT POS", 1, "Remaining: ", 0
str_timeout_msg: .db "Game over", 1, "You Lose!", 0 
str_reset_msg: .db "Reset POT to 0", 1, "Remaining ", 0
str_countdown_msg: .db "2121 16s1", 1, "Starting in ", 0
	
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
	ldi temp, (1<<CS31)
	sts TCCR3B, temp
	toggle TIMSK0, 1<<TOIE0
	;toggle TIMSK2, 1<<TOIE2
	;toggle TIMSK3, 1<<TOIE3
	;;;;;;;;prepare MISC;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  	ldi temp, PORTLDIR ; PA7:4/PA3:0, out/in
	sts DDRL, temp
	ser temp
	out DDRC, temp	;PORTC is for LED bar
	clr temp
	out PORTC, temp ;BLANK the LED bar
	clr r24
	clr r25
	clr r23
	clr r22
	clr screenStage		; initial screen (click left button to start)
	clr counter
	ldii debounce, 1
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

	ADMUX = (3 << REFS0) | (0 << ADLAR) | (0 << MUX0);
	ADCSRB = (1 << MUX5);
	ADCSRA = (1 << ADEN) | (1 << ADSC) | (1 << ADIE) | (5 << ADPS0);

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
	cpii screenStageFol, stage_pot_reset
	breq endpotResetSeg
	do_lcd_write_str str_findposition_msg
	ldi temp, 20
	rcall asciiconv
	ldii screenStageFol, stage_pot_reset
	endpotResetSeg:
	rjmp endTimer0

	potFindSeg:
	rjmp endTimer0

	codeFindSeg:
	rjmp endTimer0

	codeEnterSeg:
	rjmp endTimer0

	winSeg:
	rjmp endTimer0

	loseSeg:
	toggle TIMSK1, 0
	toggle TIMSK0,0
	do_lcd_write_str str_timeout_msg
	rjmp endTimer0

;	countdownfunc:
;		ldi countdown, 3 
;		do_lcd_write_str str_countdown_msg
;		toggle TIMSK0, 1<<TOIE0
		;ret

	ResetPot:
;		do_lcd_write_str str_reset_msg
;		do_lcd_data countdown

	Timeout: 
;		do_lcd_write_str str_timeout_msg
	
	FindPos: 
;		do_lcd_write_str str_findposition_msg

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
	breq runTimer1
	rjmp endTimer1		; fix for out of range branch
	runTimer1:

	inc counter
	clear_datamem counterTimer

	cpii screenStage, stage_countdown
	breq countInitialCount
	cpii screenStage, stage_pot_reset
	breq countPotReset
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

	countPotReset:
	ldi temp, 20
	sub temp, counter
	cpi temp, 0
	brne contPotReset
	ldii screenStage, stage_lose			; change to POT timeout
	rjmp endTimer1
	contPotReset:

	do_lcd_write_str str_findposition_msg

	rcall asciiconv
	rjmp endTimer1
	endTimer1:
	pop temp
	pop yh
	pop yl
	reti


Timer2OVF:  ;the timer for push button debouncing
	push temp
	adiw r24:r25, 1
	ldi temp, high(debDELAY)
	cpi r24, low(debDELAY)
	cpc r25, temp
	brne endTimer2
	ldii debounce, 1
	toggle TIMSK2, 0
	clr r24
	clr r25
	endTimer2:
	pop temp
	reti

Timer3OVF: ;keypad loop
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
	breq endTimer3	; If all keys are scanned, repeat.
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
	cpi col, 3 ; If the pressed key is in col.3 
	breq letters ; we have a letter
				 ; If the key is not in col.3 and
	cpi row, 3 ; If the key is in row3,
	breq symbols; we have a symbol or 0
	mov temp, row ; Otherwise we have a number in 1 -9
	lsl temp
	add temp, row
	add temp, col ; temp = row*3 + col
	inc temp
	jmp convert_end
symbols:
	cpi col, 0 ; Check if we have a star
	breq star ;star
	cpi col, 1 ; or if we have zero
	breq zero
	rjmp endTimer3
star:
	rjmp RESET
zero:
	ldi temp, 0; Set to zero
	rjmp convert_end
letters:	
	A:
	cpi row, 0 ;A
	brne B
;	ldi countdown, 20
	rjmp ResetPot
	B:
	cpi row, 1 ;B
	brne C
;	ldi countdown, 15
	rjmp ResetPot
	C:
	cpi row, 2 ;C
	brne D
;	ldi countdown, 10
	rjmp ResetPot
	D:						
;	ldi countdown, 6
	rjmp ResetPot
convert_end:
	rjmp endTimer3
endTimer3:
	pop temp
	pop cmask
	pop rmask
	pop row
	pop col
	reti

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

asciiconv:
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
.include "LCD.asm"
