#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:12:02 2012
#
$qtype = 20 ;
$prompt = 'AA. ';
$qlab = 'QAA';
$q_label = 'AA';
undef $others;
$instr = '';
$code_block = <<END_OF_CODE;
	ws_details=ws_details
	id=id
	token=token
	warning=warning
	q_label=q_label
	duedate=duedate
	story=story
	login_page=login_page
	qbanner=qbanner
	qscale=qscale
END_OF_CODE
@skips = ();
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
