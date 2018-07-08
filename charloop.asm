	lda #0
	ldx #0
loop
	sta $CF00,X
	adc #1
	inx
	jmp loop
