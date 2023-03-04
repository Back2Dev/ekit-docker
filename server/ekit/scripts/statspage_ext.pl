#/usr/bin/perl
use strict;
#$Id: statspage_ext.pl,v 1.2 2004-06-03 01:42:30 triton Exp $
# This is a 'tempory' script for generating stats pages for externals.
# these bits need to be worked backin to the parser and the setDataInfo 
# methods.
#

use TPerl::TritonConfig;
use TPerl::Error;
use Getopt::Long;
use TPerl::Survey;
use File::Slurp;
use TPerl::TSV;
use TPerl::LookFeel;
use TPerl::CGI;
use Data::Dumper;
use TPerl::Graph;

my $troot = getConfig ('TritonRoot');
my $SID = shift || die ("No SID supplied");
my $e = new TPerl::Error;
my $debug = 0;

GetOptions (
	'debug!'=>\$debug,
) or die "Bad Options";

my $sfile = survey_file TPerl::Survey ($SID);
$e->F("Survey file '$sfile' does not exist") unless -e $sfile;
my $s = eval read_file $sfile;
if ($@){
 $e->F("Eval error in '$sfile':@$");
}

$e->I("Extrnal Stats Page for $SID");

my $datafn = join '/',$troot,$SID,'final',"$SID.txt";
$e->F("Data file '$datafn' does not exist") unless -e $datafn;

my $tsv = new TPerl::TSV (file=>$datafn);

my $lf = new TPerl::LookFeel (twidth=>'100%');
my $cg = new TPerl::CGI;

my $extinf_fn = join '/',$troot,$SID,'config','external_vars.txt';
$e->F("External info file '$extinf_fn' does not extis") unless -e $extinf_fn;
my $ext_inf = eval read_file $extinf_fn;
if ($@){
	$e->F("Eval error reading '$extinf_fn':$@");
}

my $statsfn = join '/',$troot,$SID,'html','admin',"$SID.html";
my $statsfh = new FileHandle ("> $statsfn") or $e->F("Could not open '$statsfn' for writing:$!");

# go through sfile looking for column headings.
my $dlabels = {}; # labels for the questions
my $column_names = []; 
my $data_cols = $tsv->header;


foreach my $q (@{$s->questions}){
	next unless my $extfn = $q->external;
	$e->I("Collecting data columns $extfn") if $debug;
	if (my $pinf = $ext_inf->{pages}->{$extfn}){
 		my $names = $pinf->{names};
		foreach my $name (@$names){
			next if $name eq 'jump_to';
			if (grep $_ eq $name ,@$column_names){
				$e->W("$name is already included");
				print Dumper $column_names;
			}else{
				my $n = "ext_$name";
				if (grep $n eq $_,@$data_cols){
					push @$column_names,$n;
					$dlabels->{$n} = $pinf->{labels}->{$name};
				}else{
					$e->W("Column '$n' on page '$extfn' is not in data file") if  $debug;
				}
			}
		}
	}else{
		$e->W("No info for $extfn");
	}
}
# print Dumper $column_names;
$e->I(scalar (@$column_names)." Column names.  Trawling data file") if $debug;
my $data = $tsv->columns(names=>$column_names,op=>'thist',ignore_missing=>1) or
    $e->E("Trouble building histogram:".$tsv->err);
# print Dumper $data;
#
my $gr = new TPerl::Graph;

$e->I("Drawing the graphs") if $debug;

print $statsfh $cg->start_html(-title=>"$SID index file",-style=>{src=>"/$SID/style.css"});
foreach my $name (@$column_names){
	my $graph = $gr->graph_hist (hist=>$data->{$name},labels=>$dlabels->{$name},err=>$e);
	my ($n) = $name =~ /ext_(.*)/;
	print $statsfh join "\n",
		$lf->sbox ($n),
		$graph,
		$lf->ebox(),
		'<hr>';
}
print $statsfh $cg->end_html if $statsfh;

