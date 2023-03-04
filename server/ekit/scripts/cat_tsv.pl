#!/usr/bin/perl
#$Id: cat_tsv.pl,v 2.5 2007-03-30 02:28:44 triton Exp $
use strict;
use TPerl::TritonConfig;
use TPerl::Error;
use TPerl::TSV;
use Getopt::Long;
use TPerl::DBEasy;
use Data::Dumper;
use DirHandle;
use File::Basename;

my $dir = undef;
my $p_start = undef;
my $p_end = undef;
my $one_line_output = 0;
my $union = 1;
my $head_report=0;
my $out_filename = undef;

sub usage {
	my $msg = shift;
	print qq{$msg
 usage: $0 [options] SID file1 file2 file3 ...
  -d dir get  all files from dir
  -s start  When looking in dir use this date as a start
  -e end date	
  -o one line output only
  -h header report
};
	exit;
}


GetOptions (
	'dir:s'=>\$dir,
	'start:s'=>\$p_start,
	'end:s'=>\$p_end,
	'one_line!'=>\$one_line_output,
	'outfile:s'=>\$out_filename,
	'header_report!'=>\$head_report,

)or usage ("Bad Option");

my $SID = shift;
my @files = (@ARGV);

my $troot = getConfig('TritonRoot');

usage ("No SID supplied") unless $SID;
# usage ("At least one  file required") unless $files[0];

my $e = new TPerl::Error;
my $ez = new TPerl::DBEasy;

## Allow slackness in specifying files on command line
foreach my $f (@files){
	my $ext='';
	if ($f =~ /\//){
	}else{
		$ext = $f;
		$ext = "_$ext" unless $ext =~ /^_/;
	}
	my $trys = [$f,join ('/',$troot,$SID,$f),join ('/',$troot,$SID,'final',$f),join('/',$troot,$SID,'final',"$SID$ext")];
	# print Dumper $trys;
	my $found = undef;
	foreach my $try (@$trys){
		if (-f $try){
			$f = $try;
			$found =1;
			last;
		}
	}
	if ($found){
		$e->I("Using file '$f'") unless $one_line_output;
	}else{
		$e->E("Could not build a filename from '$f'");
	}
}

## Allow slackness in specifying dirs. Also allow dates to be specified.
if ($dir){
	my $trys = [$dir,join ('/',$troot,$SID,$dir)];
	my $found = 0;
	foreach my $try (@$trys){
		if (-d $try){
			$found=1;
			$dir = $try;
			$e->I("Looking in '$dir' for more files") unless $one_line_output;
			last;
		}
	}
	$e->F("Could not find any dirs in @$trys") unless $found;
	my ($start,$end) = (undef,undef);
	my $use_dates = 0;
	if ($p_start || $p_end){
		$use_dates = 1;
		my $defstart = 'Jan 1 1970';
		my $defend = 'Tomorrow';
		$p_start ||= $defstart;
		$p_end ||= $defend;
		if ($start = $ez->text2epoch ($p_start)){
			# $e->I("Data collected after $p_start") unless $one_line_output;
		}else{
			$e->I("Could not understand start date $p_start");
			$p_start =$defstart;
			$start = $ez->text2epoch($p_start);
			# $e->I("Data collected after $p_start");
		}
		if ($end = $ez->text2epoch ($p_end)){
			# $e->I("Data collected before $p_end") unless $one_line_output;
		}else{
			$e->I("Could not understand end date $p_end");
			$p_end =$defend;
			$end = $ez->text2epoch($p_end);
			# $e->I("Data collected before $p_end");
		}
		$e->I("cat_tsv:Files bw '$p_start' and '$p_end'") unless $one_line_output;

		
	}
	my $f = undef;
	my $dh = new DirHandle ($dir) or $e->F("Could not open dir '$dir'");
	while (defined ($f = $dh->read())){
		next if $f =~ /^\./;
		next if $f =~ /doc$|xls$/;
		my $fn = join '/',$dir,$f;
		if ($use_dates){
			my $da = (stat($fn))[9] || $e->F("Could not stat '$fn'");
			next if $da < $start;
			next if $da > $end;
		}
		$e->I("Adding '$f' to files") unless $one_line_output;
		push @files,$fn;
	}
}

my $numf = @files;
$e->I("Nothing to do with only '$numf' file(s)") unless $numf>1;

### use first file as base for the output file

my ($name,$path,$suffix) = fileparse($files[0],'.txt','.csv');
my $ext = 'cat';
$ext = "_$ext" unless $ext =~ /^_/;

$name = $out_filename if $out_filename;

my $o_base = "$name$ext.txt";
my $ofn = join '/',$path,$o_base;
my $ofh = new FileHandle ("> $ofn");

my $head_l = [];
my $head_h = {};
my $tsvs = {};

my $ol_msg = "Cat '$files[0]' and files from '$dir' between $p_start and $p_end into $o_base";
$ol_msg =~ s/$troot//g;
$e->I($ol_msg) if $one_line_output;

my $head_rep = {};
foreach my $fn (sort @files){
	my $tsv = new TPerl::TSV (file=>$fn);
	my ($name,$path,$suffix) = fileparse($fn,qr{\..*$});
	if (my $h = $tsv->header){
		$tsvs->{$fn} = $tsv;
		foreach my $f (@$h){
			my $uf = uc ($f);
			unless ($head_h->{$uf}){
				push @$head_l,$f;
				# $e->I("$f in '$name'") if $head_report;
			}
			push @{$head_rep->{$f}},$name;
			$head_h->{$uf}++;
		}
	}else{
		$e->E("Could not get header from '$fn'");
	}
}

if ($head_report){
	my $files = @files;
	foreach my $h (@$head_l){
		my $list = $head_rep->{$h};
		if (@$list != $files){
			$e->I("$h is column in @$list");
		}
	}
}

print $ofh join ("\t",@$head_l,'src_filename')."\n";

foreach my $fn (@files){
	next unless my $tsv = $tsvs->{$fn};
	my $sfn = $fn;
	my $rex = qr {$troot/$SID/};
	$sfn =~ s/$rex//i;
	while (my $r = $tsv->row){
		print $ofh join ("\t", map ($r->{$_},@$head_l),$sfn),"\n";
	}
	$e->E("tsv error with '$fn':".$tsv->err) if $tsv->err;
}
close $ofh;
$e->I("Closed combined file '$ofn'") unless $one_line_output;
