\ temporary variable in 222 = $DE
$DE macro temp

i: t!  temp ! ;
i: t@  temp @ ;

i: dup  t! t@ t@ ;
i: invert  dup nand ;
i: -  invert + 1 + ;
