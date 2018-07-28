	lda #0
	ldx #0
loop
	sta $D000,X
	adc #1
	inx
	jmp loop
