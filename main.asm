;;;;;;;;;;;;; TO DO ;;;;;;;;
;;A countdown Macro is needed because 
;;it will clear the screen then display the new time. 
;;
;;Do Pot code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "m2560def.inc"
.include "macros.asm"

;;;;;;;;;;;;CONSTANTS;;;;;;;;;;;;;;;;;;;
.equ debDELAY = 800 	;Variable debounce delay
.equ PORTLDIR = 0xF0 	; PD7 - 4: output, PD3 - 0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F
;;;;;;;;;;;;REGISTER DEFINES;;;;;;;;;;;;
.def debounce = r2  	; debounce flag boolean for push buttons
.def row = r16 ; current row number
.def col = r17 ; current column number
.def rmask = r18 ; mask for current row during scan
.def cmask = r19 ; mask for current column during scan
.def temp = r20
.def temp2 = r21
.def debtimerlo = r24	;the timer value for debouncing
.def debtimerhi = r25	;the timer value for debouncing
.def countdown = r22

.cseg
jmp RESET
jmp EXT_INT_R	;right push button
jmp EXT_INT_L	;left push button
.org OVF2addr
jmp Timer2OVF	;debounce timer for push buttons
.org OVF0addr
jmp Timer0OVF
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
	out DDRF, r16
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
	sts DDRL, temp
	ser temp
	out DDRC, temp	;PORTC is for LED bar
	clr temp
	out PORTC, temp ;BLANK the LED bar

	do_lcd_write_str str_home_msg ;write home message to screen

main:
	rjmp main


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;KEYPAD LOGIC;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
colloop:
	cpi col, 4
	breq main; If all keys are scanned, repeat.
	sts PORTL, cmask; Otherwise, scan a column.
	ldi temp, 0xFF; Slow down the scan operation.
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
	rjmp main
star:
	rjmp RESET
zero:
	ldi temp, 0; Set to zero
	rjmp convert_end
letters:	
	A:
	cpi row, 0 ;A
	brne B
	ldi countdown, 20
	rjmp ResetPot
	B:
	cpi row, 1 ;B
	brne C
	ldi countdown, 15
	rjmp ResetPot
	C:
	cpi row, 2 ;C
	brne D
	ldi countdown 10
	rjmp ResetPot
	D:						
	ldi countdown, 6
	rjmp ResetPot
convert_end:
	rjmp main



Timer0OVF: ;This is an 8-bit timer
;	cpse countdown, 0
	rjmp conttimer
	rjmp ResetPot
	conttimer: 
	adiw yh:yl, 1
	cpi YL, low(7812)
	ldi temp2, high(7812)
	cpc YH, temp2
	brne end0
	ldi temp, '0'
;	add temp, countdown 
	;do_lcd_data
	;dec countdown
	clr YL
	clr YH
	end0:
	reti

Timer2OVF:  ;the timer for push button debouncing
	push temp
	adiw debtimerlo, 1
	ldi temp, high(debDELAY)
	cpi debtimerlo, low(debDELAY)
	cpc debtimerhi, temp
	brne enddeb
	ldii debounce, 1
	toggle TIMSK2, 0
	enddeb:
	pop temp
	reti

ResetPot:
	do_lcd_write_str str_reset_msg
	do_lcd_data countdown

Timeout: 
	do_lcd_write_str str_timeout_msg
	
FindPos: 
	do_lcd_write_str str_findposition_msg
	
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
	;;;;HOW TO USE PUSH BUTTONS:
	;cpii debounce, 1
	;brne endInt
	;clr debounce
	;;;;DO STUFF HERE
	;toggle TIMSK2, 1<<TOIE2
	;endInt:
	;reti

countdownfunc:
	ldi countdown, 3 
	do_lcd_write_str str_countdown_msg
	toggle TIMSK0, 1<<TOIE0
	ret

;;;;;;;LEAVE THIS HERE - NEEDS TO BE INCLUDED LAST!!!;;;;;;;
.include "LCD.asm"
