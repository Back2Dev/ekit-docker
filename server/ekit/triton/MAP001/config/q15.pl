#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:02:55 2012
#
$qtype = 27 ;
$prompt = 'CHECK. Check if we have enough data to allow submission of form';
$qlab = 'QCHECK';
$q_label = 'CHECK';
undef $others;
$instr = '';
$code_block = q{
	my $dcount = &count_data;
	&debug("Datacount = $dcount");
	if ($dcount>0) {$q_no = goto_qlab("LAST") - 1;}
	if ($dcount==0) {&db_conn;&db_set_status($survey_id,$resp{id},$resp{token},0,0)}
};
@skips = ();
$grid_type = 'code';
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
