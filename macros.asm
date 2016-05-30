; Clear 2-byte word of data memory (set to 0)
; Params: 
; 0) 16bit address of first byte
.macro clear_datamem
	push temp
	push yl
	push yh
    ldi yl, low(@0)
    ldi yh, high(@0)
    clr temp
    st y+, temp
    st y, temp
	pop yh
	pop yl
	pop temp
.endmacro

; Does LCD Command
; Params: 
; 0) 8bit command
.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

; Put immediate value on screen
; Params: 
; 0) 8bit immediate value
.macro do_lcd_data_i
	ldi r16, @0
	do_lcd_data r16
.endmacro

.macro disable_ADC
	push temp
	push temp2
	ldi temp2, (1 << ADEN) | (1 << ADSC)
	com temp2
	lds temp, ADCSRA 
	and temp, temp2   ;disable ADC
	sts ADCSRA, temp      ;disable ADC
	pop temp2
	pop temp
.endmacro

.macro enable_ADC
	push temp
	lds temp, ADCSRA 
	ori temp, (1 << ADEN) | (1 << ADSC)  ;disable ADC
	sts ADCSRA, temp      ;disable ADC
	pop temp
.endmacro

.macro do_lcd_store_custom
	push zl
	push zh
	push temp2
	ldi zl, low(@1<<1)
	ldi zh, high(@1<<1)
	ldi temp2, @0
	rcall lcd_store_custom
	pop temp2
	pop zh
	pop zl
.endmacro

.macro do_lcd_show_custom
	do_lcd_command 0b10001110
	do_lcd_data_i @0
	do_lcd_command 0b10001111
	do_lcd_data_i @1
.endmacro

.macro reset_Stack
	ldi temp, low(RAMEND) ; initialize the stack
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
.endmacro

; Pass this macro a register, and it will put
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
	do_lcd_clear
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

;Toggles a timer with value passed in (0 or 1<<TIMSKN where N is a timer..)
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

.macro cleanAllReg
	clr screenStage		
	clr screenStageFol 	
	clr counter		
	clr running			
	clr keyButtonPressed	
	clr row				
	clr col				
	clr rmask				
	clr cmask				
	clr temp				
	clr temp2				
	clr keypadCode		
	clr curRound		
	clr difficultyCount
	clr debounce
.endmacro

;Toggles the strobe light when called
.macro toggleStrobe
	push temp
	push temp2
		in temp, PORTA
		ldi temp2, 0b00000010
		eor temp, temp2
		out PORTA, temp	
	pop temp2
	pop temp
.endmacro



.macro performRandomLCG
	push temp
	push temp2
	push col

	ldi col, 1
	lds temp, randomPosition
	lds temp2, randomPosition + 1
	add temp, col
	ldi col, 0
	adc temp2, col
	sts randomPosition, temp
	sts randomPosition + 1, temp2

	pop col
	pop temp2
	pop temp
.endmacro


.macro speakerBeepFor
	push temp
		ldi temp, @0
		sts speakerCounterGoal, temp
		toggle TIMSK4, 1<<TOIE4
	pop temp
.endmacro
