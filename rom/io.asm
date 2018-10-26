.include "common.inc"

.proc putc ; AX Y=char
	cpy #8
	beq newline
	tya
	ldy #0
	sta (SCREENPTR),Y
	lda TERMCURSX
	cmp #SCREENW-1
	beq newline
	inc TERMCURSX
	jmp updatecurs

newline:
	lda TERMCURSY
	cmp #SCREENH-1
	beq scroll
	inc TERMCURSY
	lda #0
	sta TERMCURSX
	jmp updatecurs

scroll:
	memcpy SCREENSTART, SCREENSTART+SCREENW, 256
	memcpy SCREENSTART+256, SCREENSTART+256+SCREENW, 256
	memcpy SCREENSTART+512, SCREENSTART+512+SCREENW, 256-SCREENW
	memcpy COLOURSTART, COLOURSTART+SCREENW, 256
	memcpy COLOURSTART+256, COLOURSTART+256+SCREENW, 256
	memcpy COLOURSTART+512, COLOURSTART+512+SCREENW, 256-SCREENW
	memset COLOURSTART+768-SCREENW, $40, SCREENW ; set new lines to white on black
nocolour:
	lda #0
	sta TERMCURSX
	jmp updatecurs
.endproc
.export putc

; update the cursor pointers from the cursor X,Y coords
.proc updatecurs ; AX
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

	; assign 32*A+x to the low bytes
	asl
	asl
	asl
	asl
	asl
	adc TERMCURSX
	sta SCREENPTR
	sta COLOURPTR

	; add X-1 to the high bytes (256*(X-1) in total)
	dex
	txa
	adc #.HIBYTE(SCREENSTART)
	sta SCREENPTR+1
	txa
	adc #.HIBYTE(COLOURSTART)
	sta COLOURPTR+1

	rts
.endproc
.export updatecurs
