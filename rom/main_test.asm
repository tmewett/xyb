.include "common.inc"

jmp putct

.proc drawct
	ldy #0
loop:
	inc TERMCURSX
	inc TERMCURSY
	jsr updatecurs
	lda $00
	sta (SCREENPTR),Y
	inc $00

	lda TERMCURSY
	cmp #24
	bne loop

	lda #0
	sta TERMCURSX
	sta TERMCURSY
	jmp loop
.endproc

.proc putct
	ldy #0
loop:
	lda $beef
	sta (COLOURPTR),Y
	tay
	jsr putc
	jmp loop
.endproc
