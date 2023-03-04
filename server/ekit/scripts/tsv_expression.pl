#!/usr/bin/perl
#$Id: tsv_expression.pl,v 1.7 2010-03-21 22:54:45 triton Exp $
use strict;
use TPerl::Template;
use TPerl::TSV;
use Data::Dumper;
use Getopt::Long;
use TPerl::ARGV;
use Text::CSV_XS;
use TPerl::TritonConfig;
use TPerl::Error;
use Pod::Usage;

=head1 SYNOPSIS

Prints the lines in file where expression is true.  By default: only columns in
the expression are printed, as well as the row number of the file, and the
number of the output (true) line.  No logging, no diagnostics, eval errors
result in dieing.

 $tsv_expression.pl [options] file expression 
	
=head1 OPTIONS

 options include:
  -vars         prints all vars
  -row_numbers  prints the row number from the original file
  -true_number  prints count of true rows.
  -all_columns  prints all columns from file
  -vars col     prints this column also.
  -help         prints this and exit
  -exp_vars     print the vars in the expression
  -csv			force the TPerl::TSV to use csv, good if file is -

=head1 ARGUMENTS

file and expression may be reversed, as long as TPerl::ARGV does not mistake
part of your expression for a file...

=head1 EXAMPLES

 perl scripts/tsv_expression BROKERS _all [%status%] == 4
 perl scripts/tsv_expression triton/BROKERS/final/BROKERS_all.txt "'[%status%]' eq '4'"

=head1 SEE ALSO

TPerl::ARGV for how filenames are built.

TPerl::TSV for how files ( - for STDIN ) are processed 

=cut

my $print_head     = [];
my $print_row_num  = 1;
my $print_true_num = 1;
my $print_all_cols = 0;
my $print_exp_vars = 1;
my $help           = 0;
my $use_csv        = 0;

GetOptions(
    'vars:s'           => $print_head,
    'row_numbers!'     => \$print_row_num,
    'true_numbers!'    => \$print_true_num,
    'all_columns!'     => \$print_all_cols,
    'help!'            => \$help,
    'expression_vars!' => \$print_exp_vars,
    'csv!'             => \$use_csv,
) or pod2usage("Bad Options");

pod2usage( { -verbose => 2 } ) if $help;

my $argv = new TPerl::ARGV(
    troot      => getConfig('TritonRoot'),
    need_files => 1,
    # try_touching => [1]
);

# my $files = $argv->fixed_args() || die Dumper $argv;
my $files = $argv->fixed_args() || die TPerl::Error->fmterr( $argv->err );

die "Found too many files on command line" . Dumper $files if @$files > 1;

my $filename = shift @$files;
my $exp = join ' ', @ARGV;

# print "file=$filename\n";
# print "exp=$exp";
pod2usage( { -verbose => 1 } ) unless $exp and $filename;
# usage("filename '$filename' does not exist") unless -e $filename;

my $tsv = new TPerl::TSV( file => $filename, nocase => 1, csv => $use_csv );

my $head_hash = $tsv->header_hash
  or die "Could not get header from $filename:" . $tsv->err;
my $on = $tsv->original_header_names;

my $tt = new TPerl::Template( template => $exp );
# print Dumper $head_hash;
# print Dumper $tsv;

die $tt->err() unless $tt->check_subs($head_hash);

## Only print the vars in the exression.
$_ = uc($_) foreach @$print_head;
if ($print_all_cols) {
    push @$print_head, @{ $tsv->header };
} elsif ($print_exp_vars) {
    my $vars_in_exp = $tt->vars();
    foreach my $h ( @{ $tsv->header } ) {
        push @$print_head, $h if $vars_in_exp->{$h};
    }
}

my $csv = $tsv->csv || new Text::CSV_XS(
    {
        sep_char    => "\t",
        quote_char  => undef,
        escape_char => undef,
        binary      => 1
    }
);

{    # do headers
    my @bad_heads = grep !$head_hash->{$_}, @$print_head;
    die "Headers not in file:@bad_heads" if @bad_heads;

    my @combine_head = map $on->{$_}, @$print_head;
    unshift @combine_head, "Row"  if $print_row_num;
    unshift @combine_head, "True" if $print_true_num;

    $csv->combine(@combine_head) || die "Could not combine @combine_head";
    print $csv->string() . "\n";
}

my $printed = undef;

my ( $rnum, $tnum );
while ( my $row = $tsv->row() ) {
    $rnum++;
    my $to_eval = $tt->process($row) or die $tt->err;
    my $eval_result = eval $to_eval;
    die "eval error '$exp' and '$to_eval':$@" if $@;
    if ($eval_result) {
        $tnum++;
        my @row = map $row->{$_}, @$print_head;
        unshift @row, $rnum if $print_row_num;
        unshift @row, $tnum if $print_true_num;
        $csv->combine(@row) || die "Could not combine";
        print $csv->string() . "\n";
    }
}
die $tsv->err if $tsv->err;
