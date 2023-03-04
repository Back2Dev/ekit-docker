#!/usr/local/bin/perl
#$Id: flip.pl,v 1.3 2005-02-22 00:46:38 triton Exp $
use strict;
use Getopt::Long;
use TPerl::TritonConfig;
use File::Basename;

# Copyright 1996-99 Triton Survey Systems, all rights reserved
#
# Transpose.pl
#
# Kwik script (don't they all start that way !!) to transpose a tab-separated file, such that it is viewable in Excel
#

# Variable definitions etc
my $indent = 0;
my $fno = 1;
my $d = 0; #debug;
#-----------------------------------------------------------
#
# Subroutines start here
#
#-----------------------------------------------------------
sub dbgprint 
	{
	my $s = shift;
	my $k;
	my $in;
	$in = '';
	for ($k = 0;$k < $indent;$k++)
		{
		$in = $in.' ';
		}
	print "$in$s" if ($d);
	}

#-----------------------------------------------------------
#
# Main program starts here
#
#-----------------------------------------------------------
#
# Check the parameter (The Survey ID)
#
my $print_version;
my $ext = '';
my $help = 0;
my $spec_input_file = '';
GetOptions (
	'extension:s'=>\$ext,
	'debug+'=>\$d,
	'version+'=>\$print_version,
	'file:s'=>\$spec_input_file,
	'help+'=>\$help,
);

sub usage {
	my $msg = shift;
	print qq{$msg\nUsage: $0 [optoions] XXX123
where options include
 --extension=extract	flip XXX123_extract instead
 --file=../../another/file.txt
 --version	
 --help
 --debug
};
	exit;
}
usage (q{$Id: flip.pl,v 1.3 2005-02-22 00:46:38 triton Exp $}) if $print_version;
usage () if $help;

$ext = '_'.$ext if $ext and $ext !~ /^_/;
my $survey_id = $ARGV[0];
my $qt_root = getConfig ('TritonRoot');
my $input_file = "${qt_root}/$survey_id/final/$survey_id$ext.txt";
my $output_file = "${qt_root}/$survey_id/final/${survey_id}${ext}_flip$fno.txt";
if ($spec_input_file){
	usage ("Cannot find input file '$spec_input_file'") unless -f $spec_input_file;
	$input_file = $spec_input_file;
	my ($name,$path,$suffix) = fileparse($spec_input_file,qr{\..*$});
	$output_file = join '/',$path,"${name}_flip$fno$suffix";
}

die "Usage: $0 [-t] [-v] [-h] XXX101\n" if ($survey_id eq '');
die "Usage: $0 [-t] [-v] [-h] XXX101\n" if ($output_file eq '');

die "Cannot find directory ${qt_root}/${survey_id}\n" if (! -d "${qt_root}/${survey_id}") ;

open(IN,"<$input_file") || die "Cannot open file: $input_file for input\n";
print "Input $input_file\n" if $ext;
print "Creating file: $output_file\n";
open(OUT,">$output_file") || die "Cannot open file $output_file for output\n";
#
# Get the list of question labels from the designer
#

# mt $qfile = "$qt_root/$survey_id/config/qlabels.pl";
# &my_require("$qfile");

my @rows = ();
my @bits = ();
my $rowcnt = 0;
my $row1 = '';
my $width = 0;
my $status ;

sub max
	{
	my $v1 = shift;
	my $v2 = shift;
	($v1 > $v2) ? $v1 : $v2;
	}

sub close_file
	{
	for (my $j=0;$j <= $#rows;$j++)
		{
		my @xx = split(/\t/,$rows[$j]);
		dbgprint("Row $j: $#xx\n");
		my $row = '';
		for (my $i=0;$i<$rowcnt;$i++)
			{
			$row .= "$xx[$i]\t";
			}
#		print OUT "$rows[$j]\tNA\n";
		print OUT "${row}NA\n";
		}
	close OUT;
	}
sub new_file
	{
	&close_file;
	$fno++;
	$output_file = "${qt_root}/$survey_id/final/${survey_id}${ext}_flip$fno.txt";
	print "Creating file: $output_file\n";
	open(OUT,">$output_file") || die "Cannot open file $output_file for output\n";
	$rowcnt = 1;
	undef @bits;
	undef @rows;
	@bits = split (/\t/,$row1);
	for (my $j=0;$j <= $#bits;$j++)
		{
		$rows[$j] = "$rows[$j]$bits[$j]\t";
		}
	$width = max($width,$#bits);
	}
while (<IN>)
	{
	chomp;
	s/\r//g;
	$row1 = $_ if ($row1 eq '');			# Save it for later
	undef @bits;
	@bits = split /\t/;
	&dbgprint("#cells=$#bits, $bits[0]\t$bits[1]\t$bits[2]\n");
	$status = $bits[0];
#
# Filter out incomplete data (unless -a option is specified)
#
	if (($status eq 'Status') || ($status == 4) || $a ||$ext)
		{
		$width = max($width,$#bits);
		for (my $j=0;$j <= $width;$j++)
			{
			$rows[$j] = "$rows[$j]$bits[$j]\t";
			}
		$rowcnt++;
		&new_file if ($rowcnt >= 255);
		}
	}
&close_file;
close IN;
