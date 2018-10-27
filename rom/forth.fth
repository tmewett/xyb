(	This file constructs the base Forth dictionary, for loading into the read-only
	memory of the XYB. It is written in standard Forth, so can be built by a previous
	version of the image.
	Points of note: Since in the bootstrap stage we are not in general using a 6502,
	the words we are defining in the image are not usable by us. And even if we were,
	all the memory address expect to be in the ROM location, not wherever it is being built.
	This means we need duplicate compiling code; one version for our use, and another in
	the image for eventual live use.
)

( Image and dictionary building )

create image $1000 allot
variable idp  0 idp ! \ image data pointer
$F000 constant image-target

: >addr ( image-addr -- eventual-addr )  image - image-target + ;
: >le ( u -- hi lo )  dup 8 rshift  swap $FF and ; \ to little-endian byte pair
: le> ( hi lo -- u )  swap 8 lshift  or ;
: le@ ( addr -- hi lo )  dup char+ c@ swap c@  le> ;

( for manipulating image contents. all addresses relative to start of image )
: ihere  idp @ ;
: ialigned  dup 2 mod + ;
: ialign  idp dup @  ialigned  swap ! ; \ cell-align idp
: ic!  image + c! ;
: ic@  image + c@ ;
: ic,  ihere ic! 1 idp +! ;
: i,  >le ic, ic, ;

: there  ihere image-target + ;

: save-image ( c-addr u -- )
	r/w create-file  0<> if exit then  >r
	image $1000 r@ write-file
	r> close-file ;


( dictionary word structure:
	length of name
	name
	addr of previous word
	run-time code pointer
	data/body ...
)
variable img-prevword  0 img-prevword !
\ creates a dictionary entry, up to and including prev word addr
: icreate
	there \ to store prev word
		bl word  dup c@ 1+  ihere image +  swap \ src dest u
		dup idp +!
		cmove \ put the name (counted string)
		img-prevword @ i,
	img-prevword ! ;

: prev-word ( w -- w->next )  count + le@ ;
\ in this impl, an xt is a pointer to a word's code pointer
: >xt ( w -- xt )  count + 2 + >addr ;


( Essential variables and primitives )

$D2 constant bodyptr \ addr of last executed word's data part

( [arg] opcode -- )
: asm-arg-none  ic, ;
: asm-arg-byte  ic, ic, ;
: asm-arg-word  ic, i, ;
: asm-arg-relative  ic,  there - 1+  ic, ;
include assembler.fth

: routine  there constant ;

\ leave enough room for a jmp to be filled in
3 idp +!

\ run-time code for words where the body is just machine code
routine (machine)
	bodyptr jmp()

\ begin sub-execution of a word with the given codeptr; the JSR of Forth words
routine (execute) \ XA=xt Y01
	\ ~ \ put bodyptr on return stack
	\ ~ bodyptr 1+ lda0
	\ ~ pha
	\ ~ bodyptr lda0
	\ ~ pha
	\ store xt
	$00 stx0
	$01 sta0
	\ load bodyptr [xt + 2]
	clc
	txa
	2 adc#
	bodyptr sta0
	$01 lda0
	0 adc#
	bodyptr 1+ sta0
	\ dereference xt
	0 ldy#
	$00 lda(),y
	$02 sta0
	$00 inc0
	there 2 + bne, \ skip next inc if no wrap
	$01 inc0
	$00 lda(),y
	$03 sta0
	\ do code; indirect jmp to code pointer
	$0002 jmp()

\ the RTS of Forth words
routine (exit)
	\ ~ \ restore bodyptr from return stack
	\ ~ pla
	\ ~ bodyptr sta0
	\ ~ pla
	\ ~ bodyptr 1+ sta0
	\ this routine must be called by jmp, so this rts goes up a level
	rts



: primitive  icreate  (machine) i, ;
: exit,  (exit) jmp, ;


: ifind ( addr u -- xt | 0 )
	img-prevword @

	begin \ addr u word-addr
		dup 0= if 2drop drop 0 exit then \ fail if lastword is null
		image-target - image + \ convert from eventual addr to current
		dup >r  count
		2over compare 0= if
			2drop r> >xt exit \ give xt
			then
	r> prev-word again
	;

include tests.fth

image 256 dump
s" rom2" save-image

bye
