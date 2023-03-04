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
	abouthimher=abouthimher
	hisher=hisher
	fullname=fullname
	firstname=firstname
	duedate=duedate
	id=id
	token=token
	ws_details=ws_details
	warning=warning
	q_label=q_label
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
