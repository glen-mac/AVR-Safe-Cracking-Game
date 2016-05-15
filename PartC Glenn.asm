.include "m2560def.inc"
.def row = r16 ; current row number
.def col = r17 ; current column number
.def rmask = r18 ; mask for current row during scan
.def cmask = r19 ; mask for current column during scan
.def temp1 = r20
.def temp2 = r21
.equ PORTLDIR = 0xF0 ; PD7 - 4: output, PD3 - 0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F
;r24/25 taken

.def accum = r22
.def optemp = r27
.def temp = r23
; y is debounce timer
.def debflag = r26
.def hundreds = r7
.def tens = r8
.def ones = r9

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	mov r16, temp
	rcall lcd_data
	rcall lcd_wait
.endmacro
.macro toggleDebounce
	push temp
	ldi temp, @0
	sts TIMSK0, temp
	pop temp
.endmacro

.cseg
	.org 0x0000
	jmp RESET
	.org OVF0addr
	jmp Timer0OVF 

RESET:
	ldi temp1, low(RAMEND) ; initialize the stack
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1
	
	;prepare timer
	clr temp
	out TCCR0A, temp 
	ldi temp, 0b00000010;Prescaling value=8
	out TCCR0B, temp
	toggleDebounce 0
	sei

	ldi temp, '0'
	clr yl
	clr yh
	clr debflag
	clr accum
	clr optemp

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;; prepare LCD
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
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;; prepare LCD

	ldi temp1, PORTLDIR ; PA7:4/PA3:0, out/in
	sts DDRL, temp1
	ser temp1; PORTC is output
	out DDRC, temp1
	clr temp1
	out PORTC, temp1 

	do_lcd_data
	do_lcd_command 0b11000000 ;change to 2 line

main:
	cpi debflag, 0
	brne main
	ldi cmask, INITCOLMASK ; initial column mask
	clr col

colloop:
	cpi col, 4
	breq main; If all keys are scanned, repeat.
	sts PORTL, cmask; Otherwise, scan a column.
	ldi temp1, 0xFF; Slow down the scan operation.

delay:
	dec temp1
	brne delay
	lds temp1, PINL; Read PORTA
	andi temp1, ROWMASK; Get the keypad output value
	cpi temp1, 0xF; Check if any row is low
	breq nextcol; If yes, find which row - is low
	ldi rmask, INITROWMASK ; Initialize for row check
	clr row

rowloop:
	cpi row, 4
	breq nextcol ; the row scan is over.
	mov temp2, temp1
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
	mov temp1, row ; Otherwise we have a number in 1 -9
	lsl temp1
	add temp1, row
	add temp1, col ; temp1 = row*3 + col
	inc temp1
	;;
	ldi temp, 10
	mul optemp, temp ;multiply current value by 10 (base 10 durr)
	add r0, temp1
	mov optemp, r0
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
	ldi temp1, 0; Set to zero
	ldi temp, 10
	mul optemp, temp ;multiply current value by 10 (base 10 durr)
	mov optemp, r0
	rjmp convert_end

letters:
	cpi row, 0 ;add
	brne remain1
	add accum, optemp
	rcall asciiconv
	rjmp main
	remain1:
	cpi row, 1 ;subract
	brne remain2
	sub accum, optemp
	rcall asciiconv
	rjmp main
	remain2: 
	cpi row, 2 ;multiply
	brne divide
	mul accum, optemp
	mov accum, r0
	rcall asciiconv
	rjmp main
	push temp1
	clr temp1
	divide:						
	cp accum, optemp
	brlo divideEpilogue
	sub accum, optemp									
	inc temp1
	jmp divide
	divideEpilogue:
	mov accum, temp1								
	pop temp1
	rcall asciiconv
	rjmp main

convert_end:
	out PORTC, temp1; Write value to PORTC
	ldi temp, '0'
	add temp, temp1
	do_lcd_data   ; temp
	toggleDebounce 1<<TOIE0
	ldi debflag, 1
	jmp main

asciiconv:
	clr optemp
	clr hundreds
	clr tens 
	clr ones 
	mov temp, accum
	do_lcd_command 0b00000001 ;clear screen
	numhundreds:
	cpi temp, 100
	brlo numtens
	inc hundreds
	subi temp, 100
	rjmp numhundreds
	numtens:
	cpi temp, 10
	brlo numones
	inc tens
	subi temp, 10
	rjmp numtens
	numones:
	mov ones, temp
	endascii:
	;display
	ldi temp, '0'
	add temp, hundreds
	do_lcd_data
	ldi temp, '0'
	add temp, tens
	do_lcd_data
	ldi temp, '0'
	add temp, ones
	do_lcd_data
	out PORTC, ones
	do_lcd_command 0b11000000 ;change to 2 line
	ret


Timer0OVF:
	push temp
	adiw yh:yl, 1
	ldi temp, high(1200)
	cpi yl, low(1200)
	cpc yh, temp
	brne timerend
	clr debflag
	toggleDebounce 0
	clr yl
	clr yh
	timerend:
	pop temp
	reti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; LCD CODE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

;
; Send a command to the LCD (r16)
;

lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

