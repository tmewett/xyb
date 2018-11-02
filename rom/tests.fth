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

i: w1  a5! c3! i;
i: w2  254 48879 c! i;

routine exectest
	s" beef" ifind  >le ldx# lda#
	(execute) jsr,

routine exittest
	s" w1" ifind  >le ldx# lda#
	(execute) jsr,
	exittest jmp,

routine store
	$FF lda#
	sp sta0
	$04 lda#
	sp 1+ sta0
	s" w2" ifind  >le ldx# lda#
	(execute) jsr,
	store jmp,

\ put a jump to our chosen test at the top of the image
0 idp !  store jmp,

~~
image 256 dump
