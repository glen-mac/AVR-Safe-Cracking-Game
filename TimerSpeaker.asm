Timer4OVF:	;used for the speaker sounds
	push temp
	in temp, SREG
	push temp
	push temp2

	in temp, PORTB		;pull in speaker pin
	ldi temp2, 1
	eor temp, temp2		;toggle speaker pin
	out PORTB, temp	

	lds temp, speakerCounter
	inc temp
	sts speakerCounter, temp
	
	lds temp2, speakerCounterGoal ;have i reached my tone length?
	cp temp, temp2
	brne timer4Epilogue

	toggle TIMSK4, 0		;yes i have, turn me off
	clr temp
	sts speakerCounter, temp
	
	timer4Epilogue:
	pop temp2
	pop temp
	out SREG, temp
	pop temp
reti