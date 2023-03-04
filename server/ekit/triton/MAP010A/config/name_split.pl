#!/usr/bin/perl
#
# name_split.pl
#
# Special script to pre-process MAP peer list form
#
# Assumes that it is run by the CGI script, so does not need to require any libraries
#
require 'TPerl/360-lib.pl';
$simulate_frames = 0;		# Prevent simulated frames from being used
require 'TPerl/pwikit_cfg.pl';
foreach (my $n=1;$n<=$config{npeer};$n++)
	{
	$resp{"ext_peerfirstname$n"} = $resp{"peerfirstname$n"};
	$resp{"ext_peerlastname$n"} = $resp{"peerlastname$n"};
	$resp{"ext_peeremail$n"} = $resp{"peeremail$n"};
	}
#
1;
