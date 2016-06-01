;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; LCD CODE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;constants
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

;Set and clear functions
.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

;Stores a custom character into LCD memory
lcd_store_custom:
	push temp
	push row
	push col
	push rmask
	clr col

	lcdStoreLoop: ;loop to store into LCD 

		ldi temp, (0b01 << 6)
		mov row, col
		mov rmask, temp2

		andi rmask, 0b111 ;mask the numbers needed

		lsl rmask
		lsl rmask
		lsl rmask ;move into position

		andi row, 0b111
		or rmask, row
		or temp, rmask

		rcall lcd_set_pos  ;set pos in RAM

		lpm temp, Z+
		andi temp, 0b00011111 ;get numbers needed

		rcall lcd_set_dat

		inc col ;increment store point

		cpi col, 8
		brne lcdStoreLoop ;loop if not done

		pop rmask
		pop col
		pop row
		pop temp
ret

;A function to set point in CG
;RAM to store custom characters
lcd_set_pos:
	out PORTF, temp
	lcd_clr LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RW
	rcall sleep_1ms
	ret

;A function to store custom
;character data in CG RAM
;for our custom characters
lcd_set_dat:
	out PORTF, temp
	lcd_clr LCD_RS
	rcall sleep_1ms
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RW
	rcall sleep_1ms
	ret

;Sends a command to the LCD
lcd_command:
	push r16
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	pop r16
	ret

;Sends data to the LCD
lcd_data:
	push r16
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	pop r16
	ret

;Wait function for the LCD
lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW

;Wait Loop for the LCD
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

;generic sleep timers 
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
sleep_25ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret 

