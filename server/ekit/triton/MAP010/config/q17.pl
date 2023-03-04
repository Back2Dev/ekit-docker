#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:02:57 2012
#
$qtype = 27 ;
$prompt = 'LAST1. Final reset of APPROVED flag';
$qlab = 'QLAST1';
$q_label = 'LAST1';
undef $others;
$instr = '';
$code_block = q{
	&db_conn;&db_do("UPDATE MAP010 set APPROVED=0 where PWD='$resp{token}'");
};
@skips = ();
$grid_type = 'code';
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
