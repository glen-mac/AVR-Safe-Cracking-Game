;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GAME LOOP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This file is for storing the MAIN code used to control the views and 
;screen stages in the game. It is triggered every 100ms, and runs code
;in segments depending on the current stage of the game. A register, 
;'screenStageFol' is used to ensure that the 'startup' code for a stage
;is run once, while code that follows on from each of these respective
;blocks may be run every single time the game loop executes while still
;in that very same stage.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Timer0OVF: ;This is an 8-bit timer - Main game loop.
	;timer prologue
	push yl
	push yh
	push temp
	in temp, SREG
	push temp
	lds yl, gameloopTimer
	lds yh, gameloopTimer+1
	adiw Y, 1
	sts gameloopTimer, yl
  	sts gameloopTimer+1, yh
	ldi temp, high(781)
	cpi yl, low(781)
	cpc yh, temp
	breq continueTimer0
	rjmp endTimer0

	continueTimer0:

	clr debounce  				 ;clear debounce flag
	clear_datamem gameloopTimer  ;clear the counter

	;switch case for stage select
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

	rjmp endTimer0

	countdownSeg:
	rcall countdownFunc
	rjmp endTimer0

	potResetSeg:
	rcall potResetFunc
	rjmp endTimer0

	potFindSeg:
	rcall potFindFunc
	rjmp endTimer0

	codeFindSeg:
	rcall codeFindFunc
	rjmp endTimer0

	codeEnterSeg:
	rcall codeEnterFunc
	rjmp endTimer0

	winSeg:
	rcall winFunc
	rjmp endTimer0

	loseSeg:
	rcall loseFunc
	rjmp endTimer0

	endTimer0:
	pop temp
	out SREG, temp
	pop temp
	pop yh
	pop yl
reti

countdownFunc:
	cpii screenStageFol, stage_countdown 
	breq endCountdownFunc
	ldii running, 1	;backlight should be on
	ldii screenStageFol, stage_countdown 
	do_lcd_write_str str_countdown_msg
	ldi temp, 3	;begin to write countdown to screen
	addi temp, '0'
	do_lcd_data temp
	do_lcd_data_i '.'
	do_lcd_data_i '.'
	do_lcd_data_i '.'
	toggle TIMSK1, 1<<TOIE1 ;countdown timer needs to be on
	endCountdownFunc:
ret

potResetFunc:
	cpii screenStageFol, stage_pot_reset
	brne continuePotResetFunc
	rjmp endPotResetFunc

	continuePotResetFunc:

	ldii screenStageFol, stage_pot_reset
	enable_ADC		;ADC should be on

	do_lcd_write_str str_reset_msg 
	do_lcd_command 0b11001011 ;move cursor on screen (to write countdown)

	mov temp, difficultyCount
	sub temp, counter
	rcall asciiconv	;write countdown on screen
    
	clr row 				; this register used to ensure RESET position is held for 500ms
	clr col					; this register used to count amount of times row has been seen to ->
							; be one (obviously after checking twice in 500ms intervals it is RESET)

	endPotResetFunc:
		cpi row, 1				; is the pot still in reset position?
		breq incrementResetPotCount
		clr col
		ret
		incrementResetPotCount:
			inc col 			; numbers of times seen row as 1
			ldi temp, 5			; has it been 5 x 100ms?
			cp col, temp
			brne endIncrementResetPotCount
			ldii screenStage, stage_pot_find
		endIncrementResetPotCount:
ret

potFindFunc:
	cpii screenStageFol, stage_pot_find
	breq endPotFindFunc
	ldii screenStageFol, stage_pot_find	
	do_lcd_write_str str_findposition_msg ;this is the reset pot message?
	do_lcd_command 0b11001011	; move cursor so countdown can be written
	
	mov temp, difficultyCount
	sub temp, counter
	rcall asciiconv
	
	clr row 			    ; this register used to ensure FIND position is held for 500ms
	clr col					; this register used to count amount of times row has been seen to ->
							; be one (obviously after checking twice in 500ms intervals it is FOUND)
	endPotFindFunc:
		cpi row, 1 			; is the pot still in reset position?
		breq incrementFindPotCount	
		clr col
		ret
		incrementFindPotCount:
			inc col			 ;numbers of times  seen row as 1
			ldi temp, 10	 ;has it been 1s?
			cp col, temp
			brne endIncrementFindPotCount
			ldii screenStage, stage_code_find
		endIncrementFindPotCount:
ret

codeFindFunc:
	cpii screenStageFol, stage_code_find
	brne continueCodeFindFunc
	rjmp endCodeFindFunc

	continueCodeFindFunc:

	rcall updateHighscores ;did we beat a highscore?!?!

	ldii screenStageFol, stage_code_find

	disable_ADC

	rcall randomizePotLocation

	toggle TIMSK1, 0 ;disable countdown

	do_lcd_write_str str_keypadscan_msg
	
	lds keypadCode, TCNT3L		
	andi keypadCode, 0b1111		;take low 4 bits of timer as keypad button (random)

	clr counter	;clear counter (for new round)

	endCodeFindFunc:
ret

codeEnterFunc:
	cpii screenStageFol, stage_code_enter
	breq endCodeEnterFunc
	ldii screenStageFol, stage_code_enter
	do_lcd_command 0b00001110 ;cursor on
	do_lcd_write_str str_entercode_msg

	clr counter	;clear counter to count number of button presses to index memory in data seg

	endCodeEnterFunc:
ret
	
winFunc:
	cpii screenStageFol, stage_win
	breq epilogueWinFunc
	do_lcd_command 0b00001100 ;cursor off
	clr running					;backlight should begin to fade out
	ldii screenStageFol, stage_win
	toggle TIMSK1, 0			;turn off countdown timer
	disable_ADC					;disable adc
	speakerBeepFor speaker1000	;make some noise!!
	do_lcd_write_str str_win_msg
	clr counter					;clear counter for use in the flashing below
	epilogueWinFunc:
		inc counter
		cpii counter, 5
		brne endWinFunc
		toggleStrobe			;toggle strobe at 2hz
		clr counter
	endWinFunc: 
ret

loseFunc:
	cpii screenStageFol, stage_lose
	breq endLoseFunc
	clr running 				;backlight should begin to fade out
	speakerBeepFor speaker1000  ;make some noise :(
	ldii screenStageFol, stage_lose
	toggle TIMSK1, 0			;turn off countdown timer
	disable_ADC 				;disable adc
	ldi temp, 0
	out PORTC, temp				;turn off LED lights
	out PORTG, temp				;turn off LED lights
	do_lcd_write_str str_timeout_msg
	endLoseFunc:
ret
