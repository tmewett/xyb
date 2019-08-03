primitive beef
	there
	$5A lda#
	$beef sta,
	jmp,

primitive a5!
	$A5 lda#
	$beef sta,
	(exit) jmp,

primitive c3!
	$C3 lda#
	$beef sta,
	(exit) jmp,

$beef iconstant beef

i: t.  beef c! ;
i: rand  beef c@ ;
i: simple  a5! c3! ;
i: retstack  2 5 >r 3 r> t. t. t. ;
i: c-fetch-store  rand t. ;
i: fetch-store  rand 2 ! 2 @ t. ;
i: arith  250 100 + 150 - t. ;

routine primtest
	i' beef  >le ldx# lda#
	(execute) jsr,

routine wordtest
	\ initialise stack pointers
	$FF lda#
	sp sta0
	$04 lda#
	sp 1+ sta0

	$7F lda#
	rsp sta0
	$04 lda#
	rsp 1+ sta0

	\ choose the word
	i' arith

	>le ldx# lda#
	(execute) jsr,
	wordtest jmp,

cr ." CURRENT IMAGE SIZE: " idp ? ." BYTES"

\ put a jump to our chosen test at the top of the image
0 idp !  wordtest jmp,

~~
image 256 dump
