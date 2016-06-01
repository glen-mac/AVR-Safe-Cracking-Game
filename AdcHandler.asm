;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;; ADC HANDLER ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;This file is for storing the MAIN code used to control the adc.
;this is the code that handles the ADC interrupts. The ADC is on free 
;running mode which means it will run a new ADC interrupt whenver the 
;last ADC conversion is complete
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

handleADC:
	push temp
	in temp, SREG
	push temp
	push rmask
	push cmask
	push temp2
	push col

	;read from ADC
	lds temp2, ADCL 
  	lds temp, ADCH

	cpii screenStageFol, stage_pot_reset
		brne checkIfPotFind
		ldi rmask, high(pot_pos_min)
		cpi temp2, low(pot_pos_min)
		cpc temp, rmask		;are we less than the min?
		brge clrRowPreEndADC
		ldi row, 1			; this means that RESET is being held
		rjmp endHandleADC
		clrRowPreEndADC:
			clr row
			rjmp endHandleADC

	checkIfPotFind: ;since we arent on reset pot screen, check if we are on pot find screen

	cpii screenStageFol, stage_pot_find  ;cmask is LOW bits, rmask is HIGH bits
		breq performPotFind
		rjmp endHandleADC

		performPotFind:

		clr col ;boolean for 'adc is higher' to check bounds so we can lose game :(

		cp temp2, cmask
		cpc temp, rmask
		brlo adcIsLower
		rjmp adcIsHigher
		adcIsLower:		;adc is higher than target
			sub cmask, temp2
			sbc rmask, temp	
			rjmp checkBelow16
		adcIsHigher:	;adc is lower than target
			sub temp2, cmask
			sbc temp, rmask
			mov cmask, temp2
			mov rmask, temp
			ldi col, 1
		checkBelow16:	;check if within 16 adc counts
			ldi temp, high(17)
			cpi cmask, low(17)
			cpc rmask, temp
			brsh checkBelow32
			ldi temp2, 0xFF
			ldi temp, 0b11	;for LED
			ldi row, 1		; this means that POSITION is being held
			rjmp endCheckIfPotFind
		checkBelow32:	;check if within 32 adc counts
			clr row		; clear flag (which says we are within 16 ADC)
			ldi temp, high(33)
			cpi cmask, low(33)
			cpc rmask, temp
			brsh checkBelow48
			ldi temp2, 0xFF
			ldi temp, 0b01
			rjmp endCheckIfPotFind
		checkBelow48:	;check if within 48 adc counts
			ldi temp, high(49)
			cpi cmask, low(49)
			cpc rmask, temp
			brsh notWithinAnyBounds
			ldi temp2, 0xFF
			ldi temp, 0b00
			rjmp endCheckIfPotFind
		notWithinAnyBounds:
			clr temp	    ;clear these values, as the LED values will be placed in them 
			clr temp2		;but they will remain blank for within the set bounds
			cpi col, 1
			brne endCheckIfPotFind
			ldii screenStage, stage_pot_reset
		endCheckIfPotFind:
			out PORTC, temp2	;put LED lights on display
			out PORTG, temp
	endHandleADC:
	pop col
	pop temp2
	pop cmask
	pop rmask
	pop temp
	out SREG, temp
	pop temp
reti
