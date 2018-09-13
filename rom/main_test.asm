.include "common.inc"

jmp putct

.proc drawct
loop:
	jsr drawc
	inc TERMCURSX
	inc TERMCURSY
	iny

	lda TERMCURSY
	cmp #24
	bne loop

	lda #0
	sta TERMCURSX
	sta TERMCURSY
	jmp loop
.endproc

.proc putct
loop:
	jsr putc
	iny
	jmp loop
.endproc
