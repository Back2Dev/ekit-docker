#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Thu Sep  9 21:40:50 2010
#
$qtype = 27 ;
$prompt = '9A. Send the thankyou email';
$qlab = 'Q9A';
$q_label = '9A';
undef $others;
$instr = '';
$code_block = q{
	use TPerl::Email;
	my $em = new TPerl::Email(debug=>1) || die "Error $! creating new TPerl::EMail object\n";
	$resp{from_email} = 'pwisupport@mappwi.com';
	$resp{from_name} = "C. Lee Froschheiser";
	$resp{subject} = "MAP Thanks you";
	$resp{to} = $resp{email};
	print "Error sending '$template' email: ".$em->err."\n" if (!$em->send_email(
	SID=>$resp{survey_id},
	itype=>'thanks',
	uid=>'',
	pwd=>'',
	fmt=>'',                                    # Default is HTML+Text
	data => \%resp,
	));
};
@skips = ();
$grid_type = 'code';
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
