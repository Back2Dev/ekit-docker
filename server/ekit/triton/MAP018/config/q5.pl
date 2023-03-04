#!/usr/bin/perl
#
# Copyright 2001 Triton Survey Systems, all rights reserved
#
# Sat Dec 29 11:02:59 2012
#
$qtype = 27 ;
$prompt = '1A. Did they give me data at this point ?';
$qlab = 'Q1A';
$q_label = '1A';
undef $others;
$instr = '';
$code_block = q{
	if ($resp{ext_cardno} ne '')
	{
	$resp{ext_cardno_obscure} = $resp{ext_cardno};
	use TPerl::MAP;
	my $m = new TPerl::MAP;
	$resp{ext_cardno_enc} = $m->map_enc($resp{ext_cardno});
	$resp{ext_cardno} = '';			# Make sure we DON'T save the credit card number in the normal place !!!
	$resp{ext_cardno_obscure} =~ s/\s+//g;
	$resp{ext_cardno_obscure} =~ s/.*(....)$/XXXX XXXX XXXX $1/i;	# Be defensive here in case of dirty data
	}
	if (!$resp{ext_fax_ccno})
	{
	$q_no = &goto_qlab("3") -1;
	}
};
@skips = ();
$grid_type = 'code';
@scores = ();
@vars = ();
@setvalues = ();
# I Like the number wun
1;
