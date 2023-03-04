#!/usr/bin/perl
#
use strict;
use Data::Dumper;
use TPerl::RawFile;
use TPerl::Engine;

my $e = new TPerl::Engine;
my $rf = new TPerl::RawFile(file=>'q7.raw');

while (my $t=$rf->transaction){
## $t is a hashref with the transaction in it.
#	print Dumper $t;
	my $seq = $$t{seqno};
#	print "seq=$seq\n";
	my $dfile = qq{../triton/MAP026/web/D$seq.pl};
	if (-f $dfile) {
#		print qq{Opening Dfile $dfile \n};
		if ($$t{writtenQ8} || $$t{writtenQ9}) {
			my $rr = $e->qt_read($dfile);
			$$rr{_Q7} = $$t{radioQ7} if ($$t{radioQ7} ne '');
			$$rr{_Q8} = $$t{writtenQ8} if ($$t{writtenQ8} ne '');
			$$rr{_Q9} = $$t{writtenQ9} if ($$t{writtenQ9} ne '');
			$e->qt_save($dfile,$rr);
			print "Updated $dfile\n";
		} else {
			print "$seq No written data - skipping\n";
		}
	} else {
		print qq{Dfile $dfile does not exist - skipping\n};
	}
}

