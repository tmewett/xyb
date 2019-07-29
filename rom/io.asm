.include "common.inc"

.proc putchar ; A=char XY
	cmp #8
	beq newline
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
	memcpym SCREENSTART, SCREENSTART+SCREENW, 256
	memcpym SCREENSTART+256, SCREENSTART+256+SCREENW, 256
	memcpym SCREENSTART+512, SCREENSTART+512+SCREENW, 256-SCREENW
	memcpym COLOURSTART, COLOURSTART+SCREENW, 256
	memcpym COLOURSTART+256, COLOURSTART+256+SCREENW, 256
	memcpym COLOURSTART+512, COLOURSTART+512+SCREENW, 256-SCREENW
	lda #0
	memsetm SCREENSTART+768-SCREENW, SCREENW ; clear new lines
	lda #$40
	memsetm COLOURSTART+768-SCREENW, SCREENW ; set new lines to white on black
nocolour:
	lda #0
	sta TERMCURSX
	jmp updatecurs
.endproc
.export putchar

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


; Begins line input with basic editing support.
; Input ends when the enter key is pressed. The buffer includes the newline if there is space.
.proc readline ; AX
	ldx #0
	stx LINEBUF
getc:
	lda CHARIN
	beq getc
	; deleting or printing a character?
	cmp #10 ; backspace
	bne printing

	; at beginning? do nothing
	lda LINEBUF
	beq getc

	dec LINEBUF
	; decide if we need to move cursor back up to prev line
	lda TERMCURSX
	bne sameline
	dec TERMCURSY
	lda #SCREENW ; will be decremented
	sta TERMCURSX
sameline:
	dec TERMCURSX

	jsr updatecurs
	lda #0
	ldy #0
	sta (SCREENPTR),Y
	jmp getc

printing:
	; if we're full, don't add to buffer, just check for newline
	ldx LINEBUF
	cpx #LBUFLEN-1
	beq full
	; append
	sta LINEBUF+1,X
	inc LINEBUF
	; print
	pha
	jsr putchar
	pla

full:
	cmp #8 ; line feed
	beq done
	jmp getc

done:
	rts
.endproc
.export readline


.proc getchar ; X puts A=char
	lda TERMCFG
	and #$80
	beq getc

	sec ; don't refill if offset < length
	lda LBUFOFF
	cmp LINEBUF
	bcc norefill
	jsr readline
	lda #0
	sta LBUFOFF
norefill:
	ldx LBUFOFF
	inc LBUFOFF
	lda LINEBUF+1,X
	rts

getc:
	lda CHARIN
	beq getc
	rts
.endproc
.export getchar
