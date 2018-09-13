.include "common.inc"

.proc putc ; A Y=char
	cpy #8
	beq newline
	jsr drawc
	lda TERMCURSX
	cmp #SCREENW-1
	beq newline
	inc TERMCURSX
	rts

newline:
	lda TERMCURSY
	cmp #SCREENH-1
	beq scroll
	inc TERMCURSY
	lda #0
	sta TERMCURSX
	rts

scroll:
	memcpy SCREENSTART, SCREENSTART+SCREENW, 256
	memcpy SCREENSTART+256, SCREENSTART+256+SCREENW, 256
	memcpy SCREENSTART+512, SCREENSTART+512+SCREENW, 256-SCREENW
	lda #0
	sta TERMCURSX
	rts
.endproc
.export putc

.proc drawc ; AX0 Y=char
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
