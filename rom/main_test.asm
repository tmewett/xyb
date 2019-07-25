.include "common.inc"

jsr updatecurs
lda #$04
sta INPUTSTART+2
lda #$F0
sta GFXSTART

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
loop:
	lda $beef
	ldy #0
	sta (COLOURPTR),Y
	lda $beef
	jsr putchar
	jmp loop
.endproc

.proc readlt
loop:
	jsr readline
	jmp loop
.endproc

.proc cat
	lda #$80
	sta TERMCFG
loop:
	jsr getchar
	jsr putchar
	jmp loop
.endproc
