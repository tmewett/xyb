(	This file constructs the base Forth dictionary, for loading into the read-only
	memory of the XYB. It is written in standard Forth, so can be built by a previous
	version of the image.
	Points of note: Since in the bootstrap stage we are not in general using a 6502,
	the words we are defining in the image are not usable by us. And even if we were,
	all the memory address expect to be in the ROM location, not wherever it is being built.
	This means we need duplicate compiling code; one version for our use, and another in
	the image for eventual live use.
)

( Terminology:
	host - whatever is running this file
	image - the interpreter we are building
	target - whatever will run the image
	image address - address in the host of a location in the image
	target address - address to be used by the target
)

	( Image and dictionary building )

create image $1000 allot
variable idp  0 idp ! \ image data pointer; offset from image start
$F000 constant image-target

: >target ( i-addr -- t-addr )  image - image-target + ;
: >le ( u -- hi lo )  dup 8 rshift  swap $FF and ; \ to little-endian byte pair
: le> ( hi lo -- u )  swap 8 lshift  or ;
: le@ ( i-addr -- hi lo )  dup char+ c@ swap c@  le> ;

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
: >xt ( w -- xt )  count + 2 + >target ;


\ A simple postfix assembler
( [arg] opcode -- )
: asm-arg-none  ic, ;
: asm-arg-byte  ic, ic, ;
: asm-arg-word  ic, i, ;
: asm-arg-relative  ic,  there - 1+  ic, ;
include assembler.fth


	( Live-use variables )

$D2 constant bodyptr \ addr of last executed word's data part


	( Execution )

: routine  there constant ;

\ leave enough room for a jmp to be filled in
3 idp +!

\ dereferences the addr in 01 into XA
routine (@)
	0 ldy#
	$00 lda(),y
	tax
	$00 inc0
	there 2 + bne, \ skip next inc if no wrap
	$01 inc0
	$00 lda(),y
	rts

\ run-time code for words where the body is just machine code
routine (machine)
	bodyptr jmp()

\ begin sub-execution of a word with the given codeptr; the JSR of Forth words
routine (execute) \ XA=xt Y01
	\ store xt
	$00 stx0
	$01 sta0
	\ put bodyptr on return stack
	bodyptr 1+ lda0
	pha
	bodyptr lda0
	pha
	\ load xt+2 into bodyptr
	clc
	$00 lda0
	2 adc#
	bodyptr sta0
	$01 lda0
	0 adc#
	bodyptr 1+ sta0
	\ dereference xt
	(@) jsr,
	\ do code; indirect jmp to code pointer
	$00 stx0
	$01 sta0
	$0000 jmp()

\ the RTS of Forth words
routine (exit)
	\ restore bodyptr from return stack
	pla
	bodyptr sta0
	pla
	bodyptr 1+ sta0
	rts

: primitive  icreate  (machine) i, ;

primitive exit
	\ destroy 1 stack frame, from the (execute) which called us
	pla
	pla
	pla
	pla
	(exit) jmp,

: ifind ( addr u -- xt | 0 )
	img-prevword @

	begin \ addr u word-addr
		image-target - image + \ convert from eventual addr to current
		dup >r  count
		2over compare 0= if
			2drop r> >xt exit \ give xt
			then
	r> prev-word  dup 0= until \ loop again unless no more words
	;


	( Compilation )

\ run-time code for colon definitions
routine (colon)
	\ load bodyptr into 01 while incrementing it by 2
	clc
	bodyptr lda0
	$00 sta0
	2 adc#
	bodyptr sta0
	bodyptr 1+ lda0
	$01 sta0
	0 adc#
	bodyptr 1+ sta0
	\ deref and execute
	(@) jsr,
	(execute) jsr,
	\ repeat unconditionally; EXIT will return to caller
	(colon) jmp,

: icompile ( xt -- )  i, ;
: exit,  s" exit" ifind icompile ;

\ a simple routine to compile to the image
\ TODO literals
: i:
	icreate  (colon) i,
	begin \ keep reading and compiling words until we see i;
		bl word count \ addr u
		2dup s" i;" compare 0<> while
		2dup ifind
			dup if icompile 2drop
			else ." undefined word " type quit then
	repeat
	exit, ;


include tests.fth

s" rom2" save-image

bye
