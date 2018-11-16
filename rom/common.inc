INPUTSTART = $0200
SCREENSTART = $D000
COLOURSTART = SCREENSTART+768
SCREENW = 32
SCREENH = 24
TERMCURSX = $0300
TERMCURSY = $0301
TERMCFG = $0302 ; Lxxxxxxx
SCREENPTR = $F0
COLOURPTR = $F2
CHARIN = INPUTSTART+5
LINEBUF = $A0
LBUFLEN = 47
LBUFOFF = $0303

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

.macro memset dest, val, len ; AX
.scope
	sec
	ldx #0
	lda #val
loop:
	sta dest,X
	cpx #len-1
	inx
	bcc loop
.endscope
.endmacro
