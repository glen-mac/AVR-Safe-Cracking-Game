;Does LCD Command
.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

;Pass this macro an immediate value, and it will put
;the value on screen
.macro do_lcd_data_i
	ldi r16, @0
	do_lcd_data r16
.endmacro

;Pass this macro an register, and it will put
;the value within the register on screen
.macro do_lcd_data
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

;Clear the LCD Panel (also resets cursor to line 1)
.macro do_lcd_clear
	do_lcd_command 0b00000001 
.endmacro

;Change cursor to the bottom line
.macro do_lcd_bottom
	do_lcd_command 0b11000000 ;change to 2 line
.endmacro

;Given a 16bit cseg address, will write the contained string to the screen
.macro do_lcd_write_str
	push r17
	push zl
	push zh
	ldi zl, low(@0<<1)
	ldi zh, high(@0<<1)
	writeLoop:
	lpm r17, z+ 
	cpi r17, 1
	brne endLineCheck
	do_lcd_bottom
	rjmp writeLoop
	endLineCheck:
	cpi r17, 0
	brne redoLoop
	rjmp endWrite
	redoLoop:
	do_lcd_data r17
	rjmp writeLoop
	endWrite:
	pop zh
	pop zl
	pop r17
.endmacro

;Toggles TIMER2 with value passed in 
.macro toggle
	push temp
	ldi temp, @1
	sts @0, temp
	pop temp
.endmacro

;Load immediate (for registers below r16)
.macro ldii
	push r16
	ldi r16, @1
	mov @0, r16
	pop r16
.endmacro

;Compare immediate (for registers below r16)
.macro cpii
	push r16
	ldi r16, @1
	cp @0, r16 
	pop r16
.endmacro

;Add immediate
.macro addi
	push r16
	ldi r16, @1
	add @0, r16
	pop r16
.endmacro
