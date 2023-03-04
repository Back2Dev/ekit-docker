#!/usr/bin/perl
#$Id: filter_limit_on_column.pl,v 2.4 2005-05-06 06:31:57 triton Exp $
=head1 SYNOPSIS

This opens the first file, filters on distinct values in a columnm,
and then writes out the dest filename.

=cut

use strict;
use TPerl::TritonConfig;
use TPerl::Error;
use File::Copy;
use File::Basename;
use Getopt::Long;
use TPerl::TSV;
use Text::CSV_XS;
use Data::Dumper;

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

####### Here the businesss starts.


my $choose = 1;
my $columns = [];
my $pass_blanks = 0;

GetOptions (
	'choose:i'=>\$choose,
	'column:s'=>$columns,
	'pass_blanks!'=>\$pass_blanks,
)or $e->F("Bad Options");

push @$columns, 'email' if @$columns ==0;

$_ = uc($_) foreach @$columns;
s/\s+/_/g foreach @$columns; #This is what dbhead in tsv does....

$e->I("Limiting on column '@$columns'. Will allow $choose distinct values. Filter Blanks is ".($pass_blanks?'On':'Off'));

my $tsv = new TPerl::TSV(file=>$src_fn,nocase=>1,dbhead=>1);
my $hhash = $tsv->header_hash;
my $head = $tsv->header;

{ 	my @bad_columns = ();
	foreach (@$columns){
		push @bad_columns,$_ unless $hhash->{$_};
	}
	$e->F(sprintf "Could not find column(s) '%s' in $src_fn",join "|",@bad_columns) if @bad_columns;
}
my $rows = {};
my $blanks =[];
my $in_lines = 0;
while (my $row = $tsv->row){
	### No we build a key into the rows hash.  
	#It needs to include the field name so that a rows are different
	#Also it helps to see what is going on in debugging
	#when it was just one col, $val was just $row->{$column}...
	my $val = join ',', map qq{$_="$row->{$_}"},@$columns;

	if ($pass_blanks and $val eq ''){
		push @$blanks,$row;
	}else{
		push @{$rows->{$val}},$row;
	}
	$in_lines++;
}
my $dst_fh = new FileHandle ("> $dest_fn") or $e->F("Could not open '$dest_fn':$!");
my $orig_head = $tsv->original_header_names;
$tsv->csv->combine(map $orig_head->{$_},@$head);
print $dst_fh $tsv->csv->string()."\n";
my $out_lines=0;
foreach my $col_val (sort keys %$rows){
	my $rs = $rows->{$col_val};
	my $possible = @$rs;
	my $choices = [];
	my $already = {};
	while ( (@$choices < $choose) and (scalar keys %$already < @$rs) ){
		my $rand = int (rand($possible))+1;
		next if $already->{$rand};
		push @$choices,$rand;
		$already->{$rand}++;
	}
	$e->I("Chose (@$choices) of $possible for key '$col_val'");
	foreach my $ch (@$choices){
		my $row = $rs->[$ch-1];
		$tsv->csv->combine(map $row->{$_},@$head);
		print $dst_fh $tsv->csv->string()."\n";
		$out_lines++;
	}
}
foreach my $row (@$blanks){
	$tsv->csv->combine(map $row->{$_},@$head);
	print $dst_fh $tsv->csv->string()."\n";
	$out_lines++;
}
$e->I("Finished writing $out_lines lines of $in_lines to $dest_fn");

