#!/usr/bin/perl
# $Id: fix.klingons.pl,v 1.1 2012-11-07 00:16:57 triton Exp $
#
# Kwik script to scan MAP d-files, and identify/fix any with missing survey_id / seqno
#
use strict;
use File::Slurp;
use TPerl::TritonConfig;
use TPerl::Engine;
use Data::Dumper;

my $e = new TPerl::Engine;

my $sid_dir = "../triton/";
opendir DDIR,$sid_dir || die "Error $! encountered while opening directory $sid_dir\n";
my @sids = grep (/^MAP/,readdir(DDIR));
closedir(DDIR);

my ($n,$warn);
foreach my $SID (@sids) {
	my $data_dir = "../triton/$SID/web";
	opendir DDIR,$data_dir || die "Error $! encountered while opening directory $data_dir\n";
	my @files = grep (/^D/,readdir(DDIR));
	closedir(DDIR);
	foreach my $f (@files) {
#		print "Reading file $f\n";
		my $d = $e->qt_read(qq{$data_dir/$f});
	#	print Dumper $d;
		if (!$$d{password}) {
			warn "Missing password in $data_dir/$f\n";
			$warn++;
		} 
		next if (($$d{survey_id} ne '') && ($$d{seqno} ne ''));
		my $seqno = $1 if ($f =~ /^D(\d+)/);
# Tell the story...
		print "  updated $data_dir/$f sid=$$d{survey_id} seqno=$$d{seqno} \n";
# Now fix it
		$$d{seqno} = $seqno;
		$$d{survey_id} = $SID;
		$e->qt_save(qq{$data_dir/$f},$d);
		$n++;
	}
}

print "Done.\n Updated $n files, $warn warnings\n";

