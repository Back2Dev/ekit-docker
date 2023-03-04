#!/usr/bin/perl
#$Id: grep_raw.pl,v 2.10 2013-01-21 22:28:47 triton Exp $
# grep_raw.pl
#
# Kwik script to do a 'grep' of an input.raw file, allowing us to pull out transactions
# According to some regular expressions.
# Made a change to not use regexp by default: added -keyre -seqre  parameters to allow use of regexp's if you really want to!
#
# Copyright Triton Information Technology
#
#----------------------------------------------------------------------
use strict;
use TPerl::RawFile;
use Data::Dumper;
use TPerl::Error;
use File::Slurp;
use Getopt::Long;
use TPerl::TritonConfig;
use Data::Dump qw(dump);

my $e = new TPerl::Error;
my $usage = <<USAGE;
Usage: $0 SID [-seqno=999] [-seqnore=regex] [-key=xxx] [-keyre=regex] [-raw=regex] [-dir=web] [-format=orig|replay|default] [-url=xxx] [-help]
Where...
	-seqno=999		- Filter to show specific seqno (exact match)
	-seqnore=regex	- Regular expression filter to show specific seqno's
	-key=xxx		- Filter to show specific key (exact match)
	-keyre=regex	- Regular expression filter to show specific keys
	-raw=regex		- Regular expression filter to use on .raw file names
	-dir=web		- Read from specified sub-directory (default is logs)
	-format=orig|replay|default		- Output format
	-url			- Base web server to use for get statements (required for -format=replay option)
	-help			- Prints this message
USAGE

sub die_usage
	{
	my $msg = shift;
	print STDERR "$msg\n$usage\n";
	$e->F($msg);
	}
	

my ($seqex,$seqre) = (undef,undef);
my ($keyex,$keyre) = (undef,undef);
my $rawre = undef;
my $log_subdir = 'logs';
our %opts;
my (@getlinks,@getlogins);

GetOptions (
	'seqno:s'=>\$seqex,
	'seqnore:s'=>\$seqre,
	'key:s'=>\$keyex,
	'keyre:s'=>\$keyre,
	'raw:s'=>\$rawre,
	help => \$opts{help},
	'dir:s'=>\$log_subdir,
	'format=s'=>\$opts{format},
	'url=s'=>\$opts{url},
) or die_usage("Bad command line options");

die_usage if ($opts{help});
my $SID = shift;
die_usage("No SID on command line") if ($SID eq '');

$opts{format} = 'default' if (!$opts{format});
$opts{format} = lc($opts{format});
die_usage("Unknown format ($opts{format})") if (($opts{format} !~ /^orig/i)  && ($opts{format} !~ /^replay/i) && ($opts{default} !~ /^default/i));
die_usage("You must tell me a base url for replay") if (($opts{format} =~ /^repl/i) && !$opts{url});

my $troot = getConfig ("TritonRoot");

my $logdir = join '/',$troot,$SID,$log_subdir;
die_usage("Can't find logs dir '$logdir'") unless -d $logdir;
$e->I("Looking in $logdir for .raw files");
my @files = read_dir ($logdir);
@files = grep /\.raw$/i,@files;
if ($rawre){
	@files = grep /$rawre/,@files;
	$e->I("Filtered raw filenames with $rawre:@files");
}

# @files = ('13-MELA4.raw');
# @files = ('12-CATI012.raw');

## This is never used.
# my $qt = new TPerl::Engine;

my $conds =0;
$conds++ if $seqre;
$conds++ if $seqex;
$conds++ if $keyre;
$conds++ if $keyex;

my $prevurl;
my $found = 0;
foreach my $f (@files){
	my $found_this_file = 0;
	next if $f =~ /^\./;
	my $file = join '/',$logdir,$f;
	my $raw = new TPerl::RawFile (file=>$file);
	while (my $tr = $raw->transaction){
		my $seqno = $tr->{seqno};
		my $show = 0;
		$show++ if ($seqre && ($seqno =~ /$seqre/));
		$show++ if ($seqex && ($seqno =~ /^$seqex$/));
# This one picks up the login transaction, when the seqno is not present, but the allocated seqno appears in the BEGIN part
		$show++ if ($seqex && !$seqno && ($tr->{seq} =~ /^$seqex$/));

		if ($keyre){
			foreach my $key (keys %$tr){
				if ($key =~ /$keyre/){
					$show++;
					last;
				}
			}
		}
		if ($keyex){
			foreach my $key (keys %$tr){
				if ($key =~ /^$keyex$/){
					$show++;
					last;
				}
			}
		}
#		print STDERR "seqno=$seqno, seqre=$seqre, seqex=$seqex, show=$show, conds=$conds\n";
		if ($show >= $conds){
			$e->I("File $f") if !$found_this_file and  @files >2;
			dumpit($tr);
			$found++;
			$found_this_file++;
		}
	}
	if (my $err = $raw->err){
		$e->E("Trouble in file '$f':$err");
	}
}
my $files = @files;
$e->I("Found $found transaction(s) in $files file(s)");
my $when = localtime;
my $logins = join(",\n",map ({qq{$_}} @getlogins));
my $getlist = join(",\n",map {qq{$_}} @getlinks);
if ($opts{format} =~ /^repl/i) {
	print qq{# Created by $0 at $when , can be replayed by scripts/replay.pl
\@logins = (
	$logins
);
\@getlist = (
	$getlist
);
1;
}
}
# - - - - - - - - - - - - - - - - - 
# Subroutines start here
#
sub dumpit
	{
	my $data = shift;
#	if ($opts{orig})
	if ($opts{format} =~ /^orig/i)
		{
#		print qq{# Begin input ts=$data->{ts} seq=$data->{seqno} tnum= ip=$data->{ip} $data->{ts_s}\n};
		print $data->{hdr}."\n";
		foreach my $key (keys %$data)
			{
			next if ($key eq 'hdr');			# This comes about because TPerl/RawFile adds a parameter from the "Begin input..." line
			next if ($key eq 'seq');			# This comes about because TPerl/RawFile adds a parameter from the "Begin input..." line
			next if (grep(/^$key$/,qw[ts ts_s tnum]));
			print qq{\t$key = '$data->{$key}',\n};
			}
		print qq{#------------------ End \n};
		}
	elsif ($opts{format} =~ /^repl/i)
		{
		my $url = ($data->{id}) ? "$opts{url}/cgi-mr/tokendb.pl?seqno=$data->{seq}&" : "$opts{url}/cgi-mr/godb.pl?";
		if ($data->{q_label} ne 'first')
			{
			my @params;
#			print "# ".$data->{hdr}."\n";
			foreach my $key (keys %$data)
				{
				next if ($key eq 'hdr');			# This comes about because TPerl/RawFile adds a parameter from the "Begin input..." line
				next if ($key eq 'seq');			# This comes about because TPerl/RawFile adds a parameter from the "Begin input..." line
				next if (grep(/^$key$/,qw[ts ts_s tnum ip]));
				next if (!$data->{$key});			# Skip empty data parameters
				push @params,qq{$key=$data->{$key}};
				}
			$url .= join("&",@params);
#			print "replay $url\n" if ($url ne $prevurl);
			if ($data->{id}) {
				push @getlogins,"qq\{$url\}" if ($url ne $prevurl);
			} else {
				push @getlinks,"qq\{$url\}" if ($url ne $prevurl);
			}
				$prevurl = $url;
			}
		}
	else
		{
		delete($data->{seq});					# This comes about because TPerl/RawFile adds a parameter from the "Begin input..." line
		delete($data->{hdr});					# This comes about because TPerl/RawFile adds a parameter from the "Begin input..." line
		print dump ($data)."\n";
		}
	}
