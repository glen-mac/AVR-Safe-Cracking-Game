; LCD Backlight
.equ LCD_BACKLIGHT_STABLE = 0
.equ LCD_BACKLIGHT_FADEIN = 1
.equ LCD_BACKLIGHT_FADEOUT = 2

; LCD Backlight Functions
initialiseBacklightTimer:
	push temp
	
	clr temp					; clear variables
	sts BacklightSeconds, temp
	sts BacklightCounter, temp
	sts BacklightCounter+1, temp
	sts BacklightFadeCounter, temp
	sts BacklightFade, temp
	ldi temp, 0xFF
	sts BacklightPWM, temp

	ldi temp, (1 << WGM30)|(1 << COM3B1)
	sts TCCR3A, temp

	ldi temp, 0xFF 					; initialise output compare value
	sts OCR3BL, temp
	clr temp
	sts OCR3BH, temp

	pop temp
ret

backlightFadeIn:
	push temp

	ldi temp, LCD_BACKLIGHT_FADEIN				; set backlight fade state to fade in
	sts BacklightFade, temp	
	
	clr temp									; reset the backlight counter
	sts BacklightSeconds, temp
	sts BacklightCounter, temp
	sts BacklightCounter+1, temp

	pop temp
ret

backlightFadeOut:
	push temp

	ldi temp, LCD_BACKLIGHT_FADEOUT			; set backlight fade state to fade out
	sts BacklightFade, temp

	pop temp
ret
