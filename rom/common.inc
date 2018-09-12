INPUTSTART = $0200
SCREENSTART = $D000
TERMCURSX = $FF
TERMCURSY = $FE

.macro memcpy dest, src, len ; AX
.proc
loop:
	ldx #0
	lda src,X
	sta dest,X
	inx
	cpx #len
	bne loop
.endproc
.endmacro
