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

i: simple  a5! c3! i;
i: c-fetch-store  48879 c@ 48879 c! i;
i: fetch-store  48879 c@ 2 ! 2 @ 48879 c! i;
i: arith  250 100 + 150 - 48879 c! i;

routine primtest
	i' beef  >le ldx# lda#
	(execute) jsr,

routine wordtest
	\ initialise stack pointer
	$FF lda#
	sp sta0
	$04 lda#
	sp 1+ sta0

	\ choose the word
	i' arith

	>le ldx# lda#
	(execute) jsr,
	wordtest jmp,

\ put a jump to our chosen test at the top of the image
0 idp !  wordtest jmp,

~~
image 256 dump
