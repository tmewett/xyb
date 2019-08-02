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
: >image ( t-addr -- i-addr )  image-target - image + ;
: >le ( u -- hi lo )  dup 8 rshift  swap $FF and ; \ to little-endian byte pair
: le> ( hi lo -- u )  swap 8 lshift  or ;
: le@ ( i-addr -- hi lo )  dup char+ c@ swap c@  le> ;

( for manipulating image contents. all addresses are in the host )
: ihere  idp @ image + ;
: ialigned  dup 2 mod + ;
: ialign  idp dup @  ialigned  swap ! ; \ cell-align idp
: ic,  ihere c! 1 idp +! ;
: i,  >le ic, ic, ;

: there  ihere >target ;

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

	On a real, old-school 6502, the indirect jump bug means that a dictionary entry
	with the code pointer split between pages will be broken.
)
variable ilatest  0 ilatest ! \ target addr of latest word in image
\ creates a dictionary entry, up to and including prev word addr
: icreate
	there \ to store prev word
		bl word count
		dup ic, \ write length
		ihere swap \ -- src dest len
		dup idp +! \ increment idp by read word length
		cmove \ put the name
		ilatest @ i, \ write latest (now previous) word t-addr
	ilatest ! \ store new latest word
	;

\ p is the t-addr of the word compiled previous to word at i-addr w
: >previous ( w -- p )  count + le@ ;
\ in this impl, an xt is a pointer to a word's code pointer
: >xt ( w -- xt )  count + 2 + >target ;


\ A simple postfix assembler
( [arg] opcode -- )
: asm-arg-none  ic, ;
: asm-arg-byte  ic, ic, ;
: asm-arg-word  ic, i, ;
: asm-arg-relative  ic,  ihere 2 + -  ic, ; \ add 2 because offset is from byte after branch instr
include assembler.fth

( Branching constructs
The words represent arrows; each is pointing either forward or backward, and towards or away.
The "away" words are intended for use as arguments for branch assembler words. They will
cause a branch to the next matching "towards" arrow in the specified direction. )
: |--> ( -- l 0 )  ihere  0 ;
: -->| ( l -- )  dup ihere swap - 2 -  swap 1+  c! ; \ write ihere-l-2 (offset) to l+1 (branch arg byte)
: <--| ( -- )  ;
: |<-- ( -- l )  ihere ;


	( Live-use variables )

$D0 constant sp \ stack pointer
$D2 constant bodyptr \ addr of last executed word's data part
$D4 constant rsp \ return sp


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
	|--> bne, \ skip next inc if no wrap
	$01 inc0
-->|
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

: word-match?  ( c-addr word -- f )  count rot count compare 0= ;

: ifind ( c-addr -- xt -1 | c-addr 0 )
	ilatest @

	begin
		>image
		2dup word-match? if \ have we found the word?
			\ then give xt and exit
			nip >xt -1 exit
		else
			>previous
		then
	dup 0= until \ otherwise loop again, unless no more words
	drop 0
	;

: i'  bl word  ifind  0= if ." word not found: " type cr bye then ;
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

: >number? ( c-addr u -- u2 true | c-addr u false )
	0 0 2over  >number \ c u u2 u1 c' u'
	0= >r 2drop
	r> if nip nip true else drop false then ;

: macro-find  dup find 1 = if nip -1 else drop 0 then ;

: process-word ( c-addr -- )
	macro-find if execute
	else ifind 0< if icompile,
	else count 2dup >number? if iliteral
	else abort" unknown word in meta-compilation"
	then then then ;

: i:
	icreate  (colon) i,
	begin \ keep reading and processing words until we see i;
		bl word
		dup count s" ;" compare 0<> while
		process-word
	repeat drop
	[i'] exit icompile, ;

: macro
	create  , immediate
	does> @ iliteral ;


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
	|--> bne, \ skip next inc if no wrap
	$01 inc0
-->|
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


include words.fth
include tests.fth

s" rom2" save-image

bye
