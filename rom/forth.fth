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

$D0 constant sp \ stack pointer
$D2 constant bodyptr \ addr of last executed word's data part
$D4 constant rsp \ return sp
$DE constant temp


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
		dup >r  count \ a1 u1 a2 u2
		2over compare 0= if \ have we found the word?
			2drop r> >xt exit then \ then give xt and exit
	r> prev-word  dup 0= until \ otherwise loop again, unless no more words
	2drop drop 0
	;

: i'  bl word count  ifind ;
: [i']  i'  postpone literal ; immediate


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

: icompile, ( xt -- )  i, ;

routine push \ A=hi X=lo Y
	\ stack grows down in memory, low byte mem-below high
	0 ldy#
	sp sta(),y
	sp dec0
	txa
	sp sta(),y
	sp dec0
	rts

routine pop \ puts A=hi X=lo Y
	0 ldy#
	sp inc0
	sp lda(),y
	tax
	sp inc0
	sp lda(),y
	rts

\ pop bodyptr from return stack; push *bodyptr to stack; push bodyptr+2 to return stack
primitive (literal)
	clc
	pla
	$00 sta0
	2 adc#
	tax
	pla
	$01 sta0
	0 adc#
	pha
	txa
	pha

	(@) jsr,
	push jsr,
	(exit) jmp,

( The following definitions give us, the host, a nice syntax for compiling words
to the image. In i:, if a word starts with ^ and it is defined in the host, the
host definition is executed and nothing else is compiled. )

: iliteral  [i'] (literal) icompile,  i, ;

: >number? ( c-addr u -- [u2] f )
	\ if f is true, u2 is the given string as a number
	0 0 2swap  >number nip nip  \ u2 u'
	dup if nip then  0= ;

: host-word? ( c-addr u -- xt | 0 )
	over c@ [char] ^ = if
		find-name dup if name>int then
	else 2drop 0 then ;

: process-word ( addr u -- )
	2dup host-word? dup if execute
		else drop  2dup ifind dup if icompile,
		else drop  2dup >number? if iliteral
		else ." invalid word in i: -> " type bye
	then then then
	2drop ;

: i:
	icreate  (colon) i,
	begin \ keep reading and processing words until we see i;
		bl word count \ addr u
		2dup s" i;" compare 0<> while
		process-word
	repeat 2drop
	[i'] exit icompile, ;

: ^  ' execute ;

primitive r>
	0 ldy#
	rsp inc0
	rsp lda(),y
	tax
	rsp inc0
	rsp lda(),y
	push jsr,
	(exit) jmp,

primitive >r
	pop jsr,
	rsp sta(),y
	rsp dec0
	txa
	rsp sta(),y
	rsp dec0
	(exit) jmp,

primitive c! ( val addr -- )
	pop jsr,
	$00 stx0
	$01 sta0
	pop jsr,
	txa
	$00 sta(),y
	(exit) jmp,

primitive c@ ( addr -- val )
	pop jsr,
	$00 stx0
	$01 sta0
	$00 lda(),y
	tax
	0 lda#
	push jsr,
	(exit) jmp,

primitive !
	pop jsr,
	$00 stx0
	$01 sta0
	pop jsr,
	pha
	txa
	$00 sta(),y
	$00 inc0
	there 2 + bne, \ skip next inc if no wrap
	$01 inc0
	pla
	$00 sta(),y
	(exit) jmp,

primitive @
	pop jsr,
	$00 stx0
	$01 sta0
	(@) jsr,
	push jsr,
	(exit) jmp,

primitive + ( x y -- x+y )
	clc

	sp inc0
	0 ldy#
	sp lda(),y
	2 ldy#
	sp adc(),y
	php \ save carry
	sp sta(),y

	sp inc0
	0 ldy#
	sp lda(),y
	2 ldy#
	plp \ restore carry
	sp adc(),y
	sp sta(),y

	(exit) jmp,

primitive nand ( x y -- ~(x&y) )
	pop jsr,
	\ high byte
	2 ldy#
	sp and(),y
	$FF eor#
	sp sta(),y
	\ now low
	dey
	txa
	sp and(),y
	$FF eor#
	sp sta(),y
	(exit) jmp,

\ temporary variable in 222 = $DE
: ^temp  temp iliteral ;
i: t!  ^temp ! i;
i: t@  ^temp @ i;

include words.fth
include tests.fth

s" rom2" save-image

bye
