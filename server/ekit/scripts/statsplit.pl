#$Id: statsplit.pl,v 1.22 2004-12-09 20:47:40 triton Exp $
use strict;
use Data::Dumper;
use TPerl::Error;
use Date::Manip;
use TPerl::CmdLine;
use FileHandle;
use TPerl::CGI;
use TPerl::LookFeel;
use Getopt::Long;
use TPerl::TritonConfig;
use TPerl::StatSplit;
use File::Path;
use TPerl::PFinder;

my $current = 0;
my $summary = 0;
my $debug = 0;
my $include_status = [];

GetOptions (
	'current!'=>\$current,
	'summary!'=>\$summary,
	'debug!'=>\$debug,
	'is:i'=>$include_status,
) or usage ("Bad Options");

my $err = new TPerl::Error;
my $SID = shift || usage ('No SID supplied');
my $troot=getConfig ("TritonRoot");
my $scripts = getConfig('scriptsDir') or $err->F("Need scriptsDir from TritonConfig");
# my $cgimr = getConfig('cgimrDir') or $err->F("Need cgimrDir from TritonConfig");

my $lf = new TPerl::LookFeel (twidth=>'95%');
##Framesets only gets created if it does not exist
my $dir = join '/',$troot,$SID,'html','admin';
mkpath ($dir,1) unless -d $dir;

my $inifile = join '/',$troot,$SID,'config','statsplit.ini';
$err->I("Statsplit $SID Reading from $inifile");

my $ss = new TPerl::StatSplit ;
my $ini = $ss->getIni (file=>$inifile)
	|| $err->F($ss->err);

my $cmd = new TPerl::CmdLine;

if (my $sg = $ss->fixSplits()){
	foreach my $group ($ini->GroupMembers ($sg)){
		$err->I("$SID $sg group $group") if !$summary;
		my $pretty = $ini->val($group,'pretty');
		my $s = $ini->val($group,'start');
		my $e = $ini->val($group,'end');
		foreach ($s,$e){
			unless (ParseDate ($s)){
				my $msg = "Could not parse '$s'";
				$err->W("skipping $group:$msg");
				next;
			}
		}
		my $ext = $ini->val($group,'ext');
		
		## no need to redo old months if they exist
		my $td = ParseDate ('now');
		my $sd = ParseDate ($s);
		my $ed = ParseDate ($e) ;
		my $active = 1 if $td>$sd and $ed>$td;

		$err->D("active=$active s=$sd n=$td e=$ed") if $debug;
		
		## data stuff.
		my $norepl = '--noreplace' unless $active;
		my $nodots = '--nodots' if $summary;
		my $one_line = '--one_line' if $summary;
		my $iss = join ' ', map "-is=$_",@$include_status;
		my $ini_ipr_options =  $ini->val($group,'iprocess') || $ini->val('main','iprocess');
		my $use_recode = $ini->val($group,'recode');
		my $cat_tsv = $ini->val($group,'cat_tsv');

		my $dcmds = [qq{perl iprocess.pl $SID $iss $one_line $nodots $norepl -start='$s' -end='$e' -name_ext='$ext' $ini_ipr_options }];

		if ($cat_tsv){
			push @$dcmds, qq{perl cat_tsv.pl $SID -d=$cat_tsv --end='$e' --start="$s" $one_line $SID$ext.txt};
		}

		$ext .= '_cat' if $cat_tsv;

		push @$dcmds,qq{ perl recode.pl -ini=$use_recode -ext='$ext' $SID } if $use_recode && ($active || !$current);
		foreach my $dcmd (@$dcmds){
			$err->D($dcmd) if $debug;
			my $dexec = $cmd->execute (dir=>$scripts,cmd=>$dcmd);
			if ($dexec->success){
				print $dexec->stdout if $active || !$current;
			}else{
				print $dexec->output;
			}
		}

		## stats page.
		my $spnorep = '--noreplace' unless $active;
	
		my $do_what = $ini->val($group,'whatpage');
		my $is_cust = scalar (@{$ss->getCustomStats(ini=>$ini)});
		my $do_cust = $ini->val($group,'custom');
		my $do_ini = $ini->val($group,'out2ini');

		my $rec_cmd_mod = "--recode=$use_recode" if $use_recode;

		my $stats_cmds = [qq{perl statspage.pl $spnorep -e=$ext $rec_cmd_mod $SID}];
		push @$stats_cmds, qq{perl statspage.pl $spnorep --out2ini $rec_cmd_mod -e=$ext $SID} if $do_ini;
		push @$stats_cmds, qq{perl statspage.pl $spnorep --whatpage $rec_cmd_mod -e=$ext $SID} if $do_what;
		push @$stats_cmds,  qq{perl statspage.pl $spnorep --custom $rec_cmd_mod -e=$ext $SID} if $is_cust && $do_cust;
		## We put the custom ini stuff as another slice in main ini file.
		# push @$stats_cmds,  qq{perl statspage.pl $spnorep --custom --out2ini $rec_cmd_mod -e=$ext $SID} if $is_cust && $do_cust && $do_ini;
	
		foreach my $cmdl (@$stats_cmds){
			my $exec = $cmd->execute(dir=>$scripts,cmd=>$cmdl);
			if ($exec->sucess()){
				print $exec->output if ($active || !$current) && !$summary;
			}else{
				print $exec->output;
			}
		}
	}
	if (my $hsh = $ss->ini2menu(SID=>$SID)){
		my $q = new TPerl::CGI;
		my $fsfile = $dir.'/index.html';# the framset file...
		unless (-e $fsfile){
			$err->I("Making $fsfile because it does not exist");
			my $fsfh = new FileHandle ("> $fsfile") or $err->F("cannot open $fsfile for writing:$!");
			print $fsfh $q->frameset (title=>"$SID Online Reporting",
				left_src=>"/cgi-adm/aspcontrolpanel.pl?SID=$SID",
				noheader=>1,top_src=>"../top.htm",right_src=>$hsh->{first});
		}
		#The left frame is updated each time
		my $leftfile = $dir.'/left.html';
		my $leftfh = new FileHandle ("> $leftfile") or $err->F("Could not open $leftfile for writing:$!");
		print $leftfh qq{
<html>
<head>
<meta HTTP-EQUIV="Refresh"  CONTENT="0; URL=/cgi-adm/aspcontrolpanel.pl?SID=$SID">
<title>$SID Control Panel</title>
</head>
<body>
<center><h1>You should be dedirected to <a href="/cgi-adm/aspcontrolpanel.pl?SID=$SID/">Here</a></h1></
center>
</body>
</html>
};

	}
}else{
	$err->I("No $sg groups. Nothing to do");
}

sub usage {
	my $msg = shift;
	print join "\n",
		"Usage $0 SID",
		"$msg";
	exit;
}
