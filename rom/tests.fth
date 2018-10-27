primitive beef
	there
	$5A lda#
	$beef sta,
	jmp,
exit,

routine exectest
	s" beef" ifind  >le ldx# lda#
	(execute) jsr,

\ put a jump to our chosen test at the top of the image
0 idp !  exectest jmp,
