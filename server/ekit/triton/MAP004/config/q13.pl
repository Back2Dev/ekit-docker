#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:02:56 2012
#
$qtype = 20 ;
$prompt = 'BREAK. ';
$qlab = 'QBREAK';
$q_label = 'BREAK';
undef $others;
$instr = '';
$buttons = '0';
$code_block = <<END_OF_CODE;
	duedate=duedate
	id=id
	token=token
END_OF_CODE
@skips = ();
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
