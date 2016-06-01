;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;; KEYPAD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This file is for storing the MAIN code used to control and read from the
;keypad. This file contains a large segment of code, due to the keypad
;being such an integral part of the whole system. It is split into sub sections
;where appropriate to make the flow of the timer more easily seen.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Timer2OVF: ;keypad loop

	push yl
	push yh
	push temp
	in temp, SREG
	push temp

	lds yl, keypadTimer
	lds yh, keypadTimer+1
	adiw Y, 1
	sts keypadTimer, yl
  	sts keypadTimer+1, yh
	ldi temp, high(390)
	cpi yl, low(390)
	cpc yh, temp
	breq continueTimer2
	rjmp endTimer2

	continueTimer2:

	clear_datamem keypadTimer
	push col
	push row
	push rmask
	push cmask
	push temp2
	clr col
	clr row
	clr rmask
	clr temp
	clr temp2
	ldi cmask, INITCOLMASK ; initial column mask

colloop:
	cpi col, 4
	brne contColloop; If all keys are scanned, repeat.
	
	;all keys were scanned, and nothing found...
	cpii screenStageFol, stage_code_find
	breq motorKill
		clr keyButtonPressed	;deal with debouncing
		rjmp epilogueTimer2
	motorKill:					;if on code find, handle the motor stopping
		in temp, PORTE
		andi temp, 0b11110111	;kill off motor pin
		out PORTE, temp
		clr counter				;restart holding counter
 		rjmp epilogueTimer2
	
contColloop:
	sts PORTL, cmask; Otherwise, scan a column.
	ldi temp, 0xFF	; Slow down the scan operation.
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
	rjmp colloop
convert:	
	rcall backlightFadeIn	;initialise the backlight to begin to fade in

	;find button pushed..
	mov temp, row 
	lsl temp
	lsl temp
	add temp, col ; temp = row*4 + col
	
	cpii screenStage, stage_win
	breq winLoseReset
	cpii screenStage, stage_lose
	brne checkRemaindingStages

	;when at win/lose screen and a button was pushed...
	winLoseReset:
		cpii keyButtonPressed, 1
		breq endConvert
		ldi gameShouldReset, 1
		rjmp epilogueTimer2

	checkRemaindingStages:
	
	cpii screenStage, stage_start
	breq startScreenKeypad

	cpii screenStageFol, stage_code_find
	brne checkIfCodeEnter 
	rjmp compareCode

	checkIfCodeEnter:
	cpii screenStageFol, stage_code_enter
	brne endConvert
	rjmp keypadCodeEnter

	endConvert:
	rjmp epilogueTimer2

startScreenKeypad:	

	rcall StartScreenButtonClick
	rjmp epilogueTimer2	

keypadCodeEnter:
	cpii keyButtonPressed, 1
		brne enterKey
		rjmp epilogueTimer2

	enterKey:
	
		clr cmask
		ldi yl, low(randomcode) ;get the data memory for the consecutive stored keys
		ldi yh, high(randomcode)
		add yl, counter
		adc yh, cmask ;assuming number of rounds doesn't exceed 255...

		ld temp2, Y

		cp temp, temp2
		breq correctKey	;the correct key was entered
		clr counter
		do_lcd_write_str str_entercode_msg
		rjmp epilogueTimer2

	correctKey:
			
		inc counter						;increment number of correct keys

		do_lcd_data_i '*'				;draw correct key on screen

		ldii keyButtonPressed, 1		;debouncing..

		cpii counter, max_num_rounds	;check if this is the last key
		brne endkeypadCodeEnter

		ldii screenStage, stage_win		;yay we win!!

		endkeypadCodeEnter:
			rjmp epilogueTimer2

compareCode:
	cp temp, keypadCode		;check if the key entered was the correct one
		breq codeMatches
		;otherwise...
		clr counter
		rjmp epilogueTimer2

	codeMatches:

		inc counter
	
		;turn on the motor
		in temp, PORTE	
		ori temp, (1 << 3)
		out PORTE, temp

		cpii counter, 20	;key has been held for 1 second
			brne epilogueTimer2

		;store the correct key entered into data memory to check later..
		clr temp
		ldi yl, low(randomcode)
		ldi yh, high(randomcode)
		add yl,	curRound
		adc yh, temp          ;unless rounds exceeds 255....
		st Y,  keypadCode

		;increment current round and clear some stuff..
		inc curRound
		clr counter
		out PORTC, temp
		out PORTG, temp 

		;kill the motor for good
		in temp, PORTE
		andi temp, 0b11110111	;kill off motor pin
		out PORTE, temp
		ldii screenStageFol, -1 ;just a prevent method, so that motor doesn't run when the view changes 

		cpi curRound, (max_num_rounds) ;is the game over yet?
		breq prepCodeEnter			

		speakerBeepFor speaker500		;beeeep

		toggle TIMSK1, 1<<TOIE1			;enable countdown timer

		ldii screenStage, stage_pot_reset
		clr counter					;clear timer stuff
		clear_datamem counterTimer	;clear timer stuff

		rjmp epilogueTimer2

	prepCodeEnter:
		ldii screenStage, stage_code_enter  ;go to code enter screen
		ldii keyButtonPressed, 1 ;debouncing

epilogueTimer2:
	pop temp2
	pop cmask
	pop rmask
	pop row
	pop col
endTimer2:
	pop temp
	out SREG, temp
	pop temp
	pop yh
	pop yl
reti

;handles the keypresses on the start screen
;from setting difficulty to reseting and viewing
;highscores
StartScreenButtonClick:
	Akey:
		cpi temp, 3 ;A
		brne Bkey
		ldi difficultyCount, 20
		do_lcd_show_custom 2, 0
		rjmp storeDiff
	Bkey:
		cpi temp, 7 ;B
		brne Ckey
		ldi difficultyCount, 15
		do_lcd_show_custom 1, 5
		rjmp storeDiff
	Ckey:
		cpi temp, 11 ;C
		brne Dkey
		ldi difficultyCount, 10
		do_lcd_show_custom 1, 0
		rjmp storeDiff
	Dkey:	
		cpi temp, 15 ;D	
		brne StarKey				
		ldi difficultyCount, 6
		do_lcd_show_custom  0, 6
		rjmp storeDiff
	StarKey:
		cpi temp, 12 ;*
		breq showScore20
		rjmp HashKey
		showScore20:	
		cpi difficultyCount, 20
		brne showScore15
			do_lcd_command 0b10001110
			lds temp, highScores
			rcall asciiconv
			rjmp performJMPtimer2End
		showScore15:
		cpi difficultyCount, 15
		brne showScore10
			do_lcd_command 0b10001110
			lds temp, highScores + 1
			rcall asciiconv
			rjmp performJMPtimer2End
		showScore10:
		cpi difficultyCount, 10
		brne showScore6
			do_lcd_command 0b10001110
			lds temp, highScores + 2
			rcall asciiconv
			rjmp performJMPtimer2End
		showScore6:
		cpi difficultyCount, 6
		breq doShowScore6
			rjmp performJMPtimer2End			
			doShowScore6:
			do_lcd_command 0b10001110
			lds temp, highScores + 3
			rcall asciiconv
			rjmp performJMPtimer2End
	HashKey:
		cpi temp, 14 ;hash key (reset highscores)
		breq doScoreClear
		rjmp performJMPtimer2End
			doScoreClear:
			ldi temp, 0
			writeToEEPROM 2, temp
			writeToEEPROM 3, temp
			writeToEEPROM 4, temp
			writeToEEPROM 5, temp
			sts highScores, temp
			sts highScores + 1, temp
			sts highScores + 2, temp
			sts highScores + 3, temp
			rjmp showScore20

	storeDiff:

		writeToEEPROM 0, difficultyCount

	performJMPtimer2End:
ret
