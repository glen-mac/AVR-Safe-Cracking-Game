; LCD Backlight
.equ LCD_BACKLIGHT_STABLE = 0
.equ LCD_BACKLIGHT_FADEIN = 1
.equ LCD_BACKLIGHT_FADEOUT = 2

; LCD Backlight Functions
initialiseBacklightTimer:
	push temp
	clr temp 							; clear variables
	sts BacklightSeconds, temp
	sts BacklightCounter, temp
	sts BacklightCounter+1, temp
	sts BacklightFadeCounter, temp
	sts BacklightFade, temp
	ldi temp, 0xFF
	sts BacklightPWM, temp

	clr temp 							; initialise timer prescale
	sts TCCR2A, temp
	ldi temp, 0b00000010
	sts TCCR2B, temp
	
	ser temp
	out DDRE, temp

	ldi temp, (1 << CS40) 				; initialise pwm timer
	sts TCCR4B, temp
	ldi temp, (1 << WGM40)|(1 << COM4A1)
	sts TCCR4A, temp

	ldi temp, 0xFF 					; initialise output compare value
	sts OCR4AL, temp
	clr temp
	sts OCR4AH, temp

	ldi temp, 1 << TOIE2 				; enable timer interrupt
	sts TIMSK2, temp

	pop temp
	ret

backlightFadeIn:						;;to turn off backlight
	push temp

	ldi temp, LCD_BACKLIGHT_FADEIN				; set backlight fade state to fade in
	sts BacklightFade, temp	
	
	clr temp									; reset the backlight counter
	sts BacklightSeconds, temp
	sts BacklightCounter, temp
	sts BacklightCounter+1, temp

	pop temp
	ret

backlightFadeOut:				;;to turn on backlight
	push temp

	ldi temp, LCD_BACKLIGHT_FADEOUT			; set backlight fade state to fade out
	sts BacklightFade, temp	

	pop temp
	ret
