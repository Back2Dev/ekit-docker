#!/usr/bin/perl
#$Id: statspage.pl,v 2.22 2006-11-10 00:54:09 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
#our $copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Andrew Creer
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# statspage.pl - Create HTML stats page(s) for display on web
#
use strict;
use TPerl::TritonConfig;
use TPerl::Survey;
use TPerl::Survey::Question;
use TPerl::Graph;
use TPerl::CGI;
use TPerl::LookFeel;
use TPerl::Dump;
use Data::Dumper;
use Getopt::Long;
use TPerl::TSV;
use TPerl::Dump;
use TPerl::StatsPage;
use TPerl::StatSplit;
use TPerl::ConfigIniFiles;
use TPerl::Recode;

#--- Need a better way to deal with this: ----------------
my $CHART_OCX_VERSION = "1,3,1,8";
#---------------------------------------------------------
my $ext = '';
my $replace = 1;
my $do_whatpage = 0;
my $do_custom = 0;
my $debug = 0;
my $out2ini = 0;
my $recode = '';
my $skip_zero = 0;

GetOptions (
	'extention:s'=>\$ext,
	'recode:s'=>\$recode,
	'replace!'=>\$replace,
	'whatpage'=>\$do_whatpage,
	'custom!'=>\$do_custom,
	'debug!'=>\$debug,
	'out2ini'=>\$out2ini,
	'skip_zero'=>\$skip_zero,
) or usage ('Bad Options');

$ext = "_$ext" if $ext and $ext !~ /^_/;

my $SID = shift || usage ("No SID sepcified");
my $e = new TPerl::Error;
my $troot = getConfig ('TritonRoot');

my $survey_file = join '/',$troot,$SID,'config',$SID."_survey.pl";
$e->F("no Survey file '$survey_file'") unless -e $survey_file;
my $s = getro TPerl::Dump ($survey_file);

my $datafile = join '/',$troot,$SID,'final',"$SID$ext.txt";
$e->F("No datafile '$datafile'") unless -e $datafile;

my $cfile = join '/',$troot,$SID,'final',$SID."_Codes_2.txt";
my $codes = {};
if (-e $cfile){
	# $e->I("Using codes from $cfile");
	$codes = getro TPerl::Dump ($cfile);
}else{
	$e->W  ("Codes file $cfile does not exist") unless -e $cfile;
}

my $sp = new TPerl::StatsPage (SID=>$SID);
my $tsv = new TPerl::TSV (file=>$datafile);
my $lf = new TPerl::LookFeel (twidth=>'95%');
my $cg = new TPerl::CGI;

my $ss = new TPerl::StatSplit(SID=>$SID);
my $custom_graphs = $ss->getCustomStats();


my $graphs_per_page = 30;

my $limit_to = undef;
if ($recode){
	my $rec = new TPerl::Recode (SID=>$SID,ext=>$recode);
	$limit_to = $rec->columns or $e->F("Could not get columns:".$rec->err());
}
if ($do_custom){
	$limit_to =  $ss->getCustomStats();
}

# Go thru questions collecting data labels
my ($n_questions,$pages,$column_names) = $sp->survey2pages (do_whatpage=>$do_whatpage,survey=>$s,
	graphs_per_page=>$graphs_per_page,limit_to=>$limit_to);
# print Dumper $pages;

my $admin = 'admin';
my $outdir = join '/',$troot,$SID,'html',$admin;
mkdir($outdir,0777) || die "Cannot create directory: $outdir\n" if (!-d $outdir);

my $rec_ext = $recode;
$rec_ext= "_$recode" if $recode;

foreach my $pidx (0..$#$pages){
	my $p = $pages->[$pidx];
	my $n_ext = '';
	my $num = $pidx+1;
	$n_ext = "_$num" if $pidx;

	my $base = $SID;
	$base = 'what' if $do_whatpage;
	$base = "custom" if $do_custom;
	my $ending = 'html';
	$ending = 'ini' if $out2ini;
	my $bfn = "$base$ext$rec_ext$n_ext.$ending";
	my $outfile = join '/',$outdir,$bfn;
	if (!$replace && -e $outfile && (stat($datafile))[9] > (stat($outfile))[9]){
		my $msg = qq{Turning on replace:Datafile '$outfile' is newer than outfile '$outfile'};
		$msg =~ s#$troot/$SID/##g;
		$e->I($msg);
		$replace=1;
	}

	if ($replace){
		$e->I("Writing stats page '$outfile'") if $debug;;
	}else{
		if (-e $outfile){
				$e->I("'$outfile' exists.  Quitting");
				exit;
		}
	}
	$p->{filename}=$outfile;
	$p->{base_fn} = $bfn;
	$p->{number} = $num;
}
if ($out2ini){
	## Make the html file that refers to the ini file.
	my $fn = join '/',$outdir,"chart$ext$rec_ext.html";
	my $fh = new FileHandle ("> $fn") or $e->F("Could not open $fn:$!");
	my $q = new TPerl::CGI ();
	my $loadme = qq{
function loadme()
    {
	document.all("x").width = document.body.clientWidth-2;
	document.all("x").height = document.body.clientHeight-2;
	}
	};
	my $fqdn = getConfig ('FQDN') or $e->F("Could not get 'FQDN' from getConfig");
	print $fh join "\n",
		$q->start_html(-title=>"Stats Charts$ext",-script=>$loadme,-onLoad=>'loadme()',
			-onResize=>'loadme()',-style=>'body{margin:1;background-color:#00ff00;}'),
		qq{
			<OBJECT
				name="x"
				classid="clsid:929FBDE9-AADB-4B16-841C-0A51DFD8D090"
				codebase="/ChartViewer.ocx#version=$CHART_OCX_VERSION"
				width=690
				height=455
				align=center
				hspace=0
				vspace=0
			>
			<PARAM NAME="database_name" Value="$SID">
			<PARAM NAME="server_address" Value="$fqdn">
			<PARAM NAME="user_name" Value="triton">
			<PARAM NAME="user_password" Value="">
			</OBJECT>
		},
		$q->end_html;

}

my $links;
if (@$pages >1)
	{
	my @out;
	foreach my $pg (@$pages)
		{
		my $lab = $pg->{first_label};
		$lab = "Q$lab" if ($lab =~ /^\d/);
		push @out,qq{<a href="$pg->{base_fn}">Page&nbsp;$pg->{number}</a>&nbsp;($lab)\n};
		}
	$links = join (' | ',@out) 
	}
my $word = 'Statistics';
$word = 'Verbatims' if $do_whatpage;
$word = 'Custom' if $do_custom;
$word .='-ini' if $out2ini;

my $link_box = join "\n",
	$lf->sbox ("$SID Online $word Page %s <BR> updated ".scalar(localtime)),
	$links,
	$lf->ebox;

$e->I(sprintf "%s $word Column names from $n_questions Questions on %s pages for $SID$ext",scalar (@$column_names),scalar(@$pages));
# trawl the data files bulding histograms of each column
unshift @$column_names,qw(Seqno Modified) if $do_whatpage;
my $data_op = 'thist';
$data_op='' if $do_whatpage;
my $data = $tsv->columns(names=>$column_names,op=>$data_op,skip_zero=>$skip_zero);
if (!$data &&  $tsv->err){
	# Only complain if there is an error.  No data going in is not really an error.
	$e->E("Trouble building histogram:".$tsv->err);
}
# $e->I("Drawing the graphs");

# print Dumper $data;

# go through the questions again, building graphs.
my $gr = new TPerl::Graph;

my $rf_code = $s->options->{rf};
my $dk_code = $s->options->{dk};
my $charset = ($s->options->{charset} ne '') ? qq{; charset=}.$s->options->{charset} : '' ;

# print "dk=$dk_code|rf=$rf_code\n";

# for ini files we only want one file, with the pages set up to be levels.
# move writing files out side the page loop for inifiles.

my $ini = new TPerl::ConfigIniFiles() if $out2ini;
my $cust_graphs = {};
if ($out2ini){
		#print Dumper $ini;
		my $opts = {
			logodimensions=>'200,70,335,75',
			sectionlogofile=>'none',
			title=>$s->options->{survey_name},
			legend=>'no',
			title2=>'Topline statistics',
			pagelogodimensions=>'30,470,60,45',
			tree=>'1',
		};
		$ini->cv_ini_section (section=>'main',opts=>$opts);
		$cust_graphs->{$_}++ foreach @$custom_graphs;
		
}

my $section_id=0;
my $parent_id=0;
my $custom_section = $out2ini && !$do_custom && (@$custom_graphs > 0);
if ($custom_section){
	$section_id++;
	$ini->cv_ini_section (section=>"dimension$section_id",opts=>{title=>'Custom Page',id=>$section_id});
	$parent_id = $section_id;
}

#my $gnum = 0;

foreach my $pidx (0..$#$pages){
	my $p = $pages->[$pidx];
	my $pnum = $pidx+1;

 	my $ofh = new FileHandle (">$p->{filename}") or $e->F("Could not write to '$p->{filename}'") unless $out2ini;

	if ($out2ini){
		$section_id++;
		my $lab = $p->{first_label};
		$lab = "Q$lab" if ($lab =~ /^\d/);
		$ini->cv_ini_section (section=>"dimension$section_id",opts=>{title=>"Page $pnum ($lab)",id=>$section_id});
		$parent_id = $section_id;
	}else{
		print $ofh join "\n",
			$cg->start_html(-title=>"$SID Online Statistics",
											-style=>{src=>"/$SID/style.css"}),
							# For some reason this doesn't work. According to the docs it should
							#       $cg->start_html(-head=>meta({-http_equiv => 'Content-Type',
							#                                    -content    => "text/html$charset"})
							#                                     ),
							# This does work though :-)
			qq{<meta http-equiv="Content-Type" content="text/html$charset">},                             
			sprintf ($link_box,$p->{number});
	}

	foreach my $q (@{$p->{questions}}){

		my $graph_list = $sp->question2graphlist (limit_to=>$limit_to,question=>$q,
			data=>$data, do_whatpage=>$do_whatpage,
			codes=>$codes,rf_code=>$rf_code,dk_code=>$dk_code);

		my $qtype= $q->qtype;
		my $graph;

		if (grep ($qtype==$_,7,5) && $do_whatpage){
			next unless @$graph_list >0;
			my $cis = $q->getDataInfo (codes=>$codes,rf_code=>$rf_code,dk_code=>$dk_code);
			foreach my $ci (@$cis){
				my $sqs = $data->{Seqno};
				my $whs = $data->{Modified};
				my $dts = $data->{$ci->{var}};
				my $rows = 0;
				$graph=$lf->stbox(['Case','When','What they said']);
				foreach my $idx (0..$#$sqs){
					next unless $dts->[$idx];
					$rows++;
                    my $ts = localtime($whs->[$idx]);
                    my $what = $dts->[$idx];
                    $what =~ s/\\n/<BR>/g;
                    $graph .= "\n".$lf->trow([$sqs->[$idx],$ts,$what]);
				}
				$graph .=$lf->etbox;
				$graph = '<blockquote class="prompt">No Data</blockquote>' unless $rows;
			}
		}elsif (@$graph_list >1){
			$graph = join "\n",map qq{<BR><BR><span class="qlabel">$_->{var}</span>&nbsp;<span class="options2">$_->{label}</span>}.
				$sp->graph_hist(graph=>$gr,err=>$e,%$_),@$graph_list;
		}else{
			my $g = $graph_list->[0];
			$graph = $sp->graph_hist(%$g,graph=>$gr,err=>$e);
		}
		
		my ($sbox,$ebox) = (undef,undef);
		($sbox,$ebox) = ($lf->sbox(),$lf->ebox()) if !$do_whatpage;
		if ($out2ini){
			foreach my $g (@{$graph_list}){
#				$gnum++;
				$section_id++;
				my ($trace,$xlabs)=$ini->hist2trace(hist=>$g->{hist},labels=>$g->{labels});
				my $var = ($g->{var} =~ /^\d/) ? "Q$g->{var}" : $g->{var};
				my $opts = {
					title=>qq{$var $g->{label}},
					BottomMargin=>10,
					BottomAxisAngle=>0,
					parent_id=>$parent_id,
					id=>$section_id,
					wrap=>10,
					xlabels=>$xlabs,
				};
				$ini->cv_ini_section(section=>"chart$section_id",opts=>$opts,traces=>[$trace]);
				if ($custom_section){
					$opts->{id}=1;
					$ini->cv_ini_section(section=>"chart${section_id}c",opts=>$opts,traces=>[$trace]) if $cust_graphs->{$g->{var}};
				}
			}
		}else{
			print $ofh join "\n",
				qq{<span class="prompt"><span class="qlabel">},
				$q->pretty_label,
				qq{</span>},
				$q->pretty_prompt,
				qq{</span>},
				$sbox,
				$graph,
				$ebox,
				'<hr>';
		}
	}
	if ($out2ini){
	}else{
		print $ofh join "\n", 
			sprintf ($link_box,$p->{number}),
			$cg->end_html;
	}
}

$ini->WriteConfig($pages->[0]->{filename}) or die "Could not write $pages->[0]->{filename}:$!" if $out2ini;

sub usage {
	my $msg = shift;
	print "$msg\n";
	exit 1;
}
