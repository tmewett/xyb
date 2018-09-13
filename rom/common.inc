INPUTSTART = $0200
SCREENSTART = $D000
SCREENW = 32
SCREENH = 24
TERMCURSX = $FF
TERMCURSY = $FE

.macro memcpy dest, src, len ; AX
.scope
	sec
	ldx #0
loop:
	lda src,X
	sta dest,X
	cpx #len-1
	inx
	bcc loop
.endscope
.endmacro
