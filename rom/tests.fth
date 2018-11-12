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

: ^beef  $beef iliteral ;
i: t.  ^beef c! i;
i: rand  ^beef c@ i;
i: simple  a5! c3! i;
i: c-fetch-store  rand t. i;
i: fetch-store  rand 2 ! 2 @ t. i;
i: arith  250 100 + 150 - t. i;

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
