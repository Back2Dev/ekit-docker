#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:12:03 2012
#
$qtype = 27 ;
$prompt = '1A. Split names';
$qlab = 'Q1A';
$q_label = '1A';
undef $others;
$instr = '';
$code_block = q{
	require 'TPerl/360-lib.pl';
	$simulate_frames = 0;		# Prevent simulated frames from being used
	require 'TPerl/pwikit_cfg.pl';
	foreach (my $n=1;$n<=$config{npeer};$n++)
	{
	$resp{"ext_peerfirstname$n"} = $resp{"peerfirstname$n"};
	$resp{"ext_peerlastname$n"} = $resp{"peerlastname$n"};
	$resp{"ext_peeremail$n"} = $resp{"peeremail$n"};
	}
};
@skips = ();
$grid_type = 'code';
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
