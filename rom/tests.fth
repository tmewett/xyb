primitive beef
	there
	$5A lda#
	$beef sta,
	jmp,
exit,

primitive beef1
	$A5 lda#
	$beef sta,
exit,

i: compiled  beef1 i;

routine exectest
	s" beef" ifind  >le ldx# lda#
	(execute) jsr,

routine exittest
	s" compiled" ifind  >le ldx# lda#
	(execute) jsr,
	exittest jmp,

\ put a jump to our chosen test at the top of the image
0 idp !  exittest jmp,

image 256 dump
