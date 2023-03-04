#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:02:56 2012
#
$qtype = 27 ;
$prompt = '1A. ';
$qlab = 'Q1A';
$q_label = '1A';
undef $others;
$instr = '';
$code_block = q{
	use Time::Local;
	$resp{status} = 4;
	&update_token_status(4);
};
@skips = ();
$grid_type = 'code';
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
