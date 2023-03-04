#!/usr/bin/perl
#$Id: aspcustomstatspage.pl,v 1.3 2004-07-12 03:46:07 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::TritonConfig;
use TPerl::MyDB;
use TPerl::StatSplit;
use Config::IniFiles;
use File::Slurp;
use TPerl::StatSplit;
use TPerl::Survey;
use TPerl::LookFeel;
use TPerl::DBEasy;
use TPerl::StatsPage;


my $q = new TPerl::CGI;
my %args = $q->args;
my $troot = getConfig('TritonRoot');
my $SID = $args{SID} ;
$q->mydie("no SID sent") unless $SID;

my $ss = new TPerl::StatSplit (SID=>$SID);
my $ini = $ss->getIni;
# $q->mydie ($ini->GetFileName());
my $vars = $args{vars} || [];
$vars=[$vars] unless ref $vars;

$vars = $ss->getCustomStats (ini=>$ini) if (@$vars==0) and !exists ($args{submit});

my $cols=3;
my $max_sel = 20;
my $max_sel_msg = undef;

if (@$vars >$max_sel){
	splice @$vars,$max_sel-1;
	$max_sel_msg = "Maximum number of graphs exceeded.  Using only the first '$max_sel' selections";
}

my $page = $args{next} if $args{submit} =~ /next/i;
$page = $args{previous} if $args{submit} =~ /prev/i;
$page = $args{page} if $args{submit} =~ /go/i;
$page ||=1;

my $sfn = survey_file TPerl::Survey ($SID);
$q->mydie("Could not open '$sfn'. Maybey you need to aspdeploy the $SID job") unless -e $sfn;
my $s = eval read_file $sfn;
$q->mydie("Eval error with '$sfn':$@") if $@;
my $lf = new TPerl::LookFeel;
my $ez = new TPerl::DBEasy;

my $qvals = [];
my $qlabs = {};

my $sp = new TPerl::StatsPage (SID=>$SID);

foreach my $q (@{$s->questions}){
	my $gl =  $sp->question2graphlist (question=>$q,data=>{});
	foreach my $g (@$gl){
		my $var = $g->{var};
		push @$qvals, $var;
		#$qlabs->{$var} = qq{<span class="qlabel">$var</span> $g->{label}};
		$qlabs->{$var} = qq{($var) $g->{label}};
	}
# 	foreach my $ci (@{$q->getDataInfo}){
# 		next unless $ci->{val_label};
# 		my $var =  $ci->{var};
# 		push @$qvals, $var;
# 		$qlabs->{$var}="<span class="qlabel">$var</span> $ci->{var_label}";
# 	}
}

my @boxes = $q->checkbox_group(-name=>'vars',-values=>$qvals,-labels=>$qlabs,-class=>'input',-defaults=>$vars);

my $sel_table = undef;

my $unsel_table;

my $big_list = \@boxes;

if (@$big_list){
	# print $q->header(-type=>'text/plain');
	# print $q->header(-type=>'text/html');
	my $limit = 10;
	my $state = {};
	$state->{$_}=1 foreach @$vars;
	my $rows = [];
	my $rcnt = 0;
	my $ccnt = 0;
	my $selects = [];
	foreach my $r (@$big_list){
		$ccnt++;
		### Dont want hidden vars that are on this page.
		my ($var) = $r =~ /value="(.*?)"/;
		my $p = int ($rcnt/$limit) +1;
		delete $state->{$var} if $p==$page;
		push @$selects,{page=>$p,var=>$var} if $r =~ /checked class="/;
		$rows->[$rcnt]->{$ccnt} = $r;
		if ($ccnt == $cols){
			$ccnt=0;
			$rcnt++;
		}
	}
	my $go_button_index = 1;
	$go_button_index =0 if $page ==1;
	my $buttons = join ' ', map $q->button(-value=>$_->{var}, -onclick=>"document.lister.page.value=$_->{page};document.lister.submit[$go_button_index].click()"),@$selects;
	my $n_sel = @$selects;
	$sel_table = qq{<table><tr><td>$n_sel Currently Selected :</td><td>$buttons</td></tr></table> };
	my $fields={};
	$fields->{$_} = {order=>$_,name=>$_} foreach (1..$cols);
	$lf->trow_properties (align=>['left','left','left']);
	my $lister = $ez->lister(rows=>$rows,fields=>$fields,page=>$page,look=>$lf,
		form=>2,form_hidden=>{vars=>[keys %$state],SID=>$SID},limit=>$limit);
	my $li = join "",@{$lister->{html}};
	my $apply = $q->button(-value=>'Apply Changes',-onclick=>"document.lister.submit[$go_button_index].click()"),
	my $fo = join "\n",@{$lister->{form}};
	$unsel_table = "$li$apply$fo";
	#### Write the selections to the ini file.
	$ss->putCustomStats(ini=>$ini,graphs=>[map $_->{var},@$selects]) or die "Could not save custom stats".$sp->err();
}


print join "\n",
	$q->header,
	$q->start_html(-style=>$q->style),
	# $q->dumper  (\%args),
	# $q->dumper ($vars),
	# "boxes=$num_boxes",
	$max_sel_msg,
	$sel_table,
	$unsel_table,
	# '<p>Not Selected</p>',
	# @not_selected,
	$q->end_html;

