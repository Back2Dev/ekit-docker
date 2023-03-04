#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:02:57 2012
#
$qtype = 20 ;
$prompt = 'AA. ';
$qlab = 'QAA';
$q_label = 'AA';
undef $others;
$instr = '';
$code_block = <<END_OF_CODE;
	duedate=duedate
	id=id
	token=token
	returnfax=returnfax
	adminemail=adminemail
	ws_details=ws_details
	warning=warning
	qbanner=qbanner
	qscale=qscale
END_OF_CODE
@skips = ();
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
