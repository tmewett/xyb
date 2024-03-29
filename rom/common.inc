INPUTSTART = $0200
GFXSTART = $0206
TIMERSTART = $0209
SCREENSTART = $D000
COLOURSTART = SCREENSTART+768

SCREENW = 32
SCREENH = 24
SCREENLEN = SCREENW * SCREENH

TERMCURSX = GFXSTART+1
TERMCURSY = GFXSTART+2
TERMCFG = $0302 ; Lxxxxxxx
SCREENPTR = $F0
COLOURPTR = $F2
CHARIN = INPUTSTART+5
FILENO = $0301
; input line buffer for IO. first byte is length of contents
LBUFLEN = 64
LBUFOFF = $0303
LINEBUF = $0304

; copies from beginning to end, so overlapping is ok as long as it's backwards
.macro memcpym dest, src, len ; AX
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

.macro memsetm dest, len ; A=val X
.scope
	sec
	ldx #0
loop:
	sta dest,X
	cpx #len-1
	inx
	bcc loop
.endscope
.endmacro

.macro ldast16 val, addr
	lda #<val
	sta addr
	lda #>val
	sta addr+1
.endmacro

.macro inc16 addr
.scope
	inc addr
	bne skip
	inc addr+1
skip:
.endscope
.endmacro
