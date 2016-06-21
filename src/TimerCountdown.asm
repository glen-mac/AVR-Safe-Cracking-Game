;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; COUNTDOWN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This file is for storing the MAIN code used to control the countdown
;as seen on the Countdown, RESET Pot, and Find Pot screens. It simply
;moves the cursor to the desired location and prints (difficultyCount -
;counter) which is the current time remaining. It does a check if this
;value = 0, so we know if it has timed out.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Timer1OVF: ;This is a countdown timer (16-bit)
	push yl
	push yh
	push temp
	in temp, SREG
	push temp
	lds yl, counterTimer
	lds yh, counterTimer+1
	adiw Y, 1
	sts counterTimer, yl
  	sts counterTimer+1, yh
	ldi temp, high(30)
	cpi yl, low(30)
	cpc yh, temp
	breq continueTimer1
	rjmp endTimer1		; fix for out of range branch

	continueTimer1:
		inc counter		;it has been 1 second
		clear_datamem counterTimer

	cpii screenStage, stage_countdown
		breq countInitialCount	;for initial countdown
	cpii screenStage, stage_pot_reset
		breq countPotResetFind 	;for RESET and FIND
	cpii screenStage, stage_pot_find
		breq countPotResetFind 	;for RESET and FIND
	rjmp endTimer1

	countInitialCount:
		ldi temp, counter_initial
		sub temp, counter
		cpi temp, 0								;find time remaining
		brne contInitialCount
		ldii screenStage, stage_pot_reset		;change to POT reset screen
		clr counter	
		clear_datamem counterTimer				;clear counter ready for POT reset screen
		speakerBeepFor speaker500				;beeeeeeeeeep
		rcall randomizePotLocation 
		rjmp endTimer1
		contInitialCount:
			addi temp, '0'
			do_lcd_command 0b11001100  ;shift cursor to where countdown is on screen, to make it smooth
			do_lcd_data temp
			do_lcd_data_i '.'
			do_lcd_data_i '.'
			do_lcd_data_i '.'
			rjmp endTimer1

	countPotResetFind:
		mov temp, difficultyCount
		sub temp, counter
		cpi temp, 0
		brne contPotResetFind
		ldii screenStage, stage_lose	; change to POT timeout
		rjmp endTimer1
		contPotResetFind:			;continues the countPotRestFind code

			speakerBeepFor speaker250	;beep on decrement

			cpii screenStage, stage_pot_find
			brne countPotReset
				do_lcd_command 0b11001011
				rjmp epilogueTimer1
			countPotReset:
				do_lcd_command 0b11001011
				rjmp epilogueTimer1

	epilogueTimer1:
		rcall asciiconv
		rjmp endTimer1
	endTimer1:
		pop temp
		out SREG, temp
		pop temp
		pop yh
		pop yl
reti
