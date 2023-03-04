#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:02:59 2012
#
$qtype = 27 ;
$prompt = 'AB. perl code to calculate some things';
$qlab = 'QAB';
$q_label = 'AB';
undef $others;
$instr = '';
$code_block = q{
	my $when = $resp{startdate};
	$resp{vday1} = "Wednesday";
	$resp{vday2} = "Thursday";
	my $url = qq{http://www.mapquest.com/maps/map.adp?country=US&searchtype=address&address=$resp{locationaddress}&city=$resp{locationcity}&state=$resp{locationstate}};
	$url =~ s/\s+/\+/g;
	$resp{maplink} = qq{<A HREF="$url" target="_blank">Here is a map</A>};
};
@skips = ();
$grid_type = 'code';
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
