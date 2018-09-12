.include "common.inc"

jmp drawct

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
