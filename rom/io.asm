.include "common.inc"

.proc drawc ; AXY0 Y=char
	sec
	lda TERMCURSY
	ldx #0
test:
	inx
	sbc #8
	bcs test
	; carry clear
	adc #8
	; now X=1,2,3 depending on which third of the screen the cursor is in
	; and A is the cursor Y coord offset from the top of the third

	asl
	asl
	asl
	asl
	asl
	adc TERMCURSX
	stx $00
	tax
	tya

	dec $00
	beq lines0
	dec $00
	beq lines1
	sta SCREENSTART+512,X
	rts

lines0:
	sta SCREENSTART,X
	rts

lines1:
	sta SCREENSTART+256,X
	rts
.endproc
.export drawc
