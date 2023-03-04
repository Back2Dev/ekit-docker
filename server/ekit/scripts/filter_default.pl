#!/usr/bin/perl
#$Id: filter_default.pl,v 2.2 2005-05-06 03:55:59 triton Exp $
use strict;
use TPerl::TritonConfig;
use TPerl::Error;
use File::Copy;
use File::Basename;

die "You need at least 4 command line params" unless @ARGV >=4;

my $batchno = pop;
my $SID = pop;
my $dest_fn = pop;
my $src_fn = pop;

my $troot=getConfig("TritonRoot");
my ($name,$path,$suffix) = fileparse($0,qr{\.*$});
$name =~ s/\.pl//ig;
my $lfn = join '/',$troot,'log',"$name-$SID-$batchno";

my $e = new TPerl::Error (ts=>1);
my $lfh = new FileHandle(">> $lfn") or $e->F("Could not open logfile '$lfn':$!");
$e->fh([$lfh]);
$e->F("src '$src_fn' does not exist") unless -e $src_fn;
$e->W("dest '$dest_fn' will be overwritten");

######## The Business starts here.....

$e->I("About to copy '$src_fn' to '$dest_fn' for $SID-$batchno");
if (copy ($src_fn,$dest_fn)){
	$e->I("Success");
}else{
	$e->F("Could not copy '$src_fn' to '$dest_fn':$!")
}
