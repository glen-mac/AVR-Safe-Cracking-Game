;;;;;;;;;;;;; TO DO ;;;;;;;;
;;A countdown Macro is needed because 
;;it will clear the screen then display the new time. 
;;
;;Do Pot code
;
;;Consider disabling interrupts for PB1 to prevent even handling code
;
;;Put keypad code in Timer0, with 0 prescaler (can disable with toggle macro)
;;when not needed)
;;
;;Scale game loop to 1ms (Tiemr 0)
;
;;Set TIMER 3 to 8 bit 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "m2560def.inc"
.include "macros.asm"

;;;;;;;;;;;;CONSTANTS;;;;;;;;;;;;;;;;;;;
.equ debDELAY = 800 	;Variable debounce delay
.equ PORTLDIR = 0xF0 	; PD7 - 4: output, PD3 - 0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F
.equ stage_start = 0
.equ stage_countdown = 1
.equ stage_pot_reset = 2
.equ stage_pot_find = 3
.equ stage_code_find = 4
.equ stage_code_enter = 5
.equ stage_win = 6
.equ stage_lose = 7
;;;;;;;;;;;;REGISTER DEFINES;;;;;;;;;;;;
.def screenStage = r3
.def debounce = r2  	; debounce flag boolean for push buttons
.def row = r16 ; current row number
.def col = r17 ; current column number
.def rmask = r18 ; mask for current row during scan
.def cmask = r19 ; mask for current column during scan
.def temp = r20
.def temp2 = r21

.cseg
.org 0x0000
	jmp RESET
.org 0x0002
	jmp EXT_INT_R	;right push button
.org 0x0004
	jmp EXT_INT_L	;left push button
.org OVF0addr
	jmp Timer0OVF	;game loop
.org OVF2addr
	jmp Timer2OVF	;debounce timer for push buttons
.org OVF3addr
	jmp Timer3OVF	;keypad search code
;STRING LIST:  (1 denotes a new line, 0 denotes end of second line)
str_home_msg: .db "2121 16s1", 1, "Safe Cracker", 0
str_findposition_msg: .db "Find POT POS", 1, "Remaining:", 0
str_timeout_msg: .db "Game over", 1, "You Lose!", 0 
str_reset_msg: .db "Reset POT to 0", 1, "Remaining ", 0
str_countdown_msg: .db "Starting in ", 1, 0
	


RESET:
	;;;;;;;;prepare stack;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
	;;;;;;;;prepare MISC;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  	ldi temp, PORTLDIR ; PA7:4/PA3:0, out/in
	clr screenStage		; initial screen (click left button to start)
	ldii debounce, 1
	sts DDRL, temp
	ser temp
	out DDRC, temp	;PORTC is for LED bar
	clr temp
	out PORTC, temp ;BLANK the LED bar

	do_lcd_write_str str_home_msg ;write home message to screen
	
halt:
	rjmp halt ;do nothing forever!


Timer0OVF: ;This is an 8-bit timer - Game loop.
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

	countdownSeg:
	rjmp endTimer0

	potResetSeg:
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
	rjmp endTimer0

	countdownfunc:
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
	reti


Timer2OVF:  ;the timer for push button debouncing
	push temp
;	adiw debtimerlo, 1
	ldi temp, high(debDELAY)
;	cpi debtimerlo, low(debDELAY)
;;	cpc debtimerhi, temp
	brne enddeb
	ldii debounce, 1
	toggle TIMSK2, 0
	enddeb:
	pop temp
	reti

Timer3OVF: ;keypad loop
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;KEYPAD LOGIC;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
	;reti

EXT_INT_L:
	cpii debounce, 1
	brne endInt
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
	endInt:
	reti

;;;;;;;LEAVE THIS HERE - NEEDS TO BE INCLUDED LAST!!!;;;;;;;
.include "LCD.asm"
