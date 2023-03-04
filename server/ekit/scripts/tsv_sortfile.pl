#!/usr/bin/perl
#$Id: tsv_sortfile.pl,v 1.3 2012-11-07 00:22:54 triton Exp $
#
# This file is a quick and dirty script (I bet you say that to all the girls),
# the purpose is to sort a tab separated file by a key column. This script is written 
# specifically to address a problem for MAP, but could be made more generic by allowing 
# command line parameters instead of the hard wired ones.
#
use strict;
use TPerl::Error;
use TPerl::TSV;
use Data::Dumper;
use Date::Manip;

#Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");

# Input and output filenames
my $infile = shift;
my $outfile = shift;
#
# Names of the key column and an ID column, the combination of these is unique
# (like a primary key). 
#
my $keycol = "WSDate";				# MAP data has mixed case column names. Yuk but go with it.
my $idcol = "Id";

my $dupe_action = "skip";			# Can add more verbs later
my $isdate = 1;						# Set to 1 to make date conversion and update

my $opt_t = 0;						# Trace/debug variable
#
# Let's get this party started...
#
usage ("Nothing on command line") unless $infile && $outfile;

sub usage 
	{
	my $msg = shift;
	print qq{$msg\n Usage $0 infile outfile};
	exit;
	}

my $e = new TPerl::Error;

$e->F("input file '$infile' does not exist") unless -e $infile;
my $tsv = new TPerl::TSV(file=>$infile,);# nocase=>1, dbhead=>1);
open OUT,">$outfile" || die "Error $! encountered while creating output file $outfile\n";
print OUT join("\t",@{$tsv->header})."\n";			# Does it keep the column order ?
#
# Slurp the file in, and keep in a hash
#
my %hash;
my $inlines = 0;
while (my $row = $tsv->row)
	{
	$inlines++;
	my $key = $row->{$keycol};
	if ($isdate)	# If it's a date, convert it to an ISO date string, which will sort easily/properly
		{
# ParseDate relies on US format date (mm/dd/yy) unless we do the Date_Init("DateFormat=Non-US"); as above
		my $date = &ParseDate($key);
		$key = UnixDate($date,"20%y-%m-%d");	# %m and %d both have leading zeroes, very nice of them
		$row->{$keycol} = $key;					# Have to fix the source data too, because tpivot sorts it again
												# Re-writing this could be a command line option
		}
	my $hashkey = qq{$key.$row->{$idcol}};
	print "key=$hashkey\n" if ($opt_t);
	if ($hash{$hashkey})
		{
		print "$dupe_action duplicate key for $hashkey\n" if ($opt_t);
		next if ($dupe_action eq 'skip');		# Can add more verbs later
		}
	$hash{$hashkey} = $row;		# Stack it up...
	}
#
# We read the file in, now it's a simple thing to sort and dump (without changing the contents, although we could have done that :)
#
my $lines = 0;
foreach my $key (sort keys %hash)
	{
	my $row = $hash{$key};
	my $line = join("\t",map($row->{$_},@{$tsv->header}));
	print OUT "$line\n";
#	print " $key\n";
	$lines++;
	}
close OUT;
print "Done, read $inlines lines, wrote $lines to file $outfile\n";
