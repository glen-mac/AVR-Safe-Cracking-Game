;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; BACKLIGHT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This file is for storing the MAIN code used to control the LCD backlight,
;from fading it in and out, to ensure it should stay completly on. This
;segment of code relies heavily on the helper functions below the Timer3
;code through the use of the functions being called throughout main.asm
;in normal code operation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; LCD Backlight
.equ LCD_BACKLIGHT_FULL = 0
.equ LCD_BACKLIGHT_FADEIN = 1
.equ LCD_BACKLIGHT_FADEOUT = 2

Timer3OVF:	;this timer controls the backlighting of the LCD display (fading, and display)							
	push temp2
	push temp
	in temp, SREG
	push temp
	push r24
	push r25
	 
	lds r24, BacklightFadeCounter				; load the backlight fade counter
	inc r24										; increment the counter
	sts BacklightFadeCounter, r24
	cpi r24, 15									
	brne fadeFinished
	
	clr temp									; reset fade counter
	sts BacklightFadeCounter, temp	

	lds temp, BacklightFade						; check what fade state
	cpi temp, LCD_BACKLIGHT_FADEIN
	breq FadeIn
	cpi temp, LCD_BACKLIGHT_FADEOUT
	breq FadeOut							; if BacklightFade = 0 which is the case when it is first set up
	rjmp fadeFinished 

	FadeIn:									; if fading in
		lds temp2, BacklightPWM
		cpi temp2, 0xFF						; check if already max brightness
		breq BacklightFin
		inc temp2							; inc pwm
		sts BacklightPWM, temp2				; store new pwm
		rjmp dispBacklight		

	FadeOut:
		lds temp2, BacklightPWM				; if fading out
		cpi temp2, 0x00						; check if min brightness
		breq BacklightFin
		dec temp2							; dec pwm
		sts BacklightPWM, temp2				; store new pwm
		rjmp dispBacklight

	BacklightFin:
		ldi temp, LCD_BACKLIGHT_FULL
		sts BacklightFade, temp
		rjmp endFadeCode

	dispBacklight:						; output backlight
		lds temp, BacklightPWM
		sts OCR3BL, temp
	
	endFadeCode:
		clr temp							; reset the backlight counter
		sts BacklightTime, temp
		sts BacklightCounter, temp
		sts BacklightCounter+1, temp
		
	fadeFinished:							; if running the backlight should remain on
	
		cpii running, 1							; check if game is in one of the running stages 
		breq timer3Epilogue 
	
		lds r24, BacklightCounter				; load backlight counter
		lds r25, BacklightCounter+1
		adiw r25:r24, 1							; increment the counter
		sts BacklightCounter, r24				; store incremented value
		sts BacklightCounter+1, r25

		ldi temp, high(3906)
		cpi r24, low(3906)						; check if it has been 1 second
		cpc r25, temp
		brne timer3Epilogue

		clear_datamem BacklightCounter

		lds r24, BacklightTime				; load backlight seconds
		inc r24									; increment the backlight seconds
		sts BacklightTime, r24				; store new value

		cpi r24, 5								; check if it has been 5 seconds
		brne timer3Epilogue
		clr temp							
		sts BacklightTime, temp					; reset the seconds

	fadeOutBacklight:						; start fading out the backlight
		rcall backlightFadeOut
	
	timer3Epilogue:
		pop r25
		pop r24
		pop temp
		out SREG, temp
		pop temp
		pop temp2
reti

; LCD Backlight Functions
initialiseBacklightTimer:
	push temp
	
	clr temp					; clear variables
	sts BacklightTime, temp
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

;set LCD to begin to fade out
backlightFadeOut:
	push temp

	ldi temp, LCD_BACKLIGHT_FADEOUT			; set backlight fade state to fade out
	sts BacklightFade, temp

	pop temp
ret

backlightFadeIn:
	push temp

	ldi temp, LCD_BACKLIGHT_FADEIN				; set backlight fade state to fade in
	sts BacklightFade, temp	
	
	clr temp									; reset the backlight counter
	sts BacklightTime, temp
	sts BacklightCounter, temp
	sts BacklightCounter+1, temp

	pop temp
ret

;set LCD to begin to fade in

