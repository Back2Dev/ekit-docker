#!/usr/bin/perl
#
#$Id: tpivot.pl,v 1.28 2012-11-07 00:20:44 triton Exp $
#
# Custom script to pivot data ready for charting
# It produces a .ini file which CeeVee will process and turn into a
# Powerpoint presentation (ie a data dump)
#
use strict;
use Getopt::Long;						#perl2exe
use Date::Manip;
use Data::Dumper;
use TPerl::DBEasy;
use TPerl::TSV;
use TPerl::TritonConfig;
use TPerl::Error;
use TPerl::Survey;
use TPerl::Dump;

our %mydata = ();
our @idlist = ();
our @titlelist = ();
our @vtrack = ();
our %vdump = ();
our $vfh;
our %keyh;		# Hash of keywords for replacement
our (%html_code);
my $vfirst = 1;
$| = 1;
my $opt_d = 0;
my $opt_vd = 0;
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_ini,$opt_monthno);
GetOptions (
			help 	=> \$opt_h,
			debug 	=> \$opt_d,
			trace 	=> \$opt_t,
			version => \$opt_v,
			'monthno=i' => \$opt_monthno,
			'ini=s' 	=> \$opt_ini,
			) or die_usage ( "Bad command line options" );

sub die_usage
	{
	my $msg = shift;
	print "Error: $msg\n" if ($msg ne '');
	print <<ERR;
Usage: $0 [-v] [-t] [-h] [-ini=ini-filename] SID
	-h 			Display help
	-v 			Display version no
	-t 			Trace mode
	-monthno=	Month to dump out for
	-ini=		Name of .ini file (default tpivot.ini, lives in \$troot/SID/config
ERR
	exit 0;
	}
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/tpivot.pl,v 1.28 2012-11-07 00:20:44 triton Exp $'."\n";
	exit 0;
	}


my @months = (qw{Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec});
our %date_extract_fmt = 
	(
 	yearof		=>	'%Y',			# 4 digit year, 0 to 9999
 	year		=>	'%Y',
 	year4		=>	'%Y',			# 2 digit year, 0 to 99
 	year2		=>	'%y',			# 2 digit year, 0 to 99
 	month		=>	'%m',			# Month of year, 01 to 12
 	monthof		=>	'%m',
 	monname		=>	'%b',			# month name abbrev. - Jan to Dec
 	monthname	=>	'%B',			# month name - January to December
 	week		=>	'%U',			# week of year, Sunday as first day of week     - 01 to 53
 	weekof		=>	'%U',
 	weekmon		=>	'%W',			# week of year, Monday as first day of week     - 01 to 53
 	weekofmon	=>	'%W',
 	weekday		=>	'%a',			# weekday abbreviation - Sun to Sat
 	day			=>	'%d',			# day of month - 01 to 31
 	dayof		=>	'%d',			# day of month - 01 to 31
 	yearday		=>	'%j',			# day of the year - 001 to 366
 	dayofweek	=>	'%w',			# day of week - 1 (Monday) to 7 (Sunday)
 	hour		=>	'%H',			# Hour of day, 00 to 23
 	hourof		=>	'%H',			# Hour of day, 00 to 23
 	minute		=>	'%M',			# Minute of hour, 00 to 59
	);

	
my $e = new TPerl::Error;
my $troot = getConfig('TritonRoot');
my $SID = shift;
$e->F("Missing SID") if ($SID eq '');
my $cfgdir = join '/',$troot,$SID,'config';
$opt_ini = "tpivot.ini" if ($opt_ini eq '');
my $inifile = qq{$cfgdir/$opt_ini};
$e->I("Reading pivot config file: $inifile");
my $ini = new Config::IniFiles (-file=>$inifile) or $e->F("Could not open '$inifile' as an ini file");

my $period = inival('main','period','YearNo(4).MonthNo(2)');
my $overall_label = inival('main','overall',qq{$SID Overall});
#
# Filename to read is stored in .ini file
#	
my $datafilename = inival('main','datafile',qq{$SID.txt});
my $datafile = join '/',$troot,$SID,'final',$datafilename;
$e->F ("Datafile '$datafile' does not exist") unless -e $datafile;
$e->I ("Opening data file '$datafile'");
my $tsv = new TPerl::TSV (file=>$datafile);
my $htmldir = join '/',$troot,$SID,'html';
my $tmp_file = qq{$htmldir/${opt_ini}.tmp};
open(OUT,">$tmp_file") || die "Error $! encountered while creating temporary file: $tmp_file \n";
print OUT qq{[main]\ntree=1\n\n};
my @measures = split(/,/,inival('main','measures'));
my @verbatims = split(/,/,inival('verbatims','verbatims'));
my @titles = split(/,/,inival('main','titles'));
my @pivots = split(/,/,inival('main','pivot'));
my @scales = ();#split(/,/,inival('main','scales'));
#for(my $i=0;$i<=$#scales;$i++)
#	{$scales[$i] =~ s/-/,/;}
my @multiplier = (); 		# split(/,/,inival('main','multiplier'));
my @trend_multiplier = ();	# split(/,/,inival('main','trend_multiplier'));
my %mtitles = ();
my %navtitles = ();
for (my $i=0;$i<=$#measures;$i++)
	{
#	$mtitles{$measures[$i]} = ($titles[$i] eq '') ? $measures[$i] : $titles[$i];
	push @multiplier,inival("measure$measures[$i]",'multiplier',1);
	push @trend_multiplier,inival("measure$measures[$i]",'trend_multiplier',1);
	$mtitles{$measures[$i]} = inival("measure$measures[$i]",'title',$measures[$i]);
	$navtitles{$measures[$i]} = inival("measure$measures[$i]",'navigate',$measures[$i]);
	push @scales,inival("measure$measures[$i]",'scale','0,5');
	}
if (@verbatims)
	{
	my $v = $opt_ini;
	$v =~ s/\.ini/_verbatims.html/ig;
	my $verbatim_file = qq{$htmldir/$v};
	open($vfh,">$verbatim_file") || die "Error $! encountered while creating file: $verbatim_file \n";
	get_html();
	my $when = localtime();
	print $vfh &merge('html_hdr',{when => $when, SID => $SID});
	}
our $level = 0;
#
# Do the trends
#
#
# Now do the pivoting of the data
#
# Get the variables or measures
#my $tsv = new TPerl::TSV (file=>$datafile);
$tsv->reset();
my $rowcnt = 0;
our ($month,$measure,$verbatim);
our $seqno = 10000;		# A high starting number to make for easy sorting
my @pwidths;
while (my $row = $tsv->row)
	{
	$rowcnt++;
#	last if (($rowcnt > 100) && $opt_d);
	print "." if (($rowcnt % 50) == 0);
	print "\n" if (($rowcnt % 4000) == 0);
	$month = calc_period($row,$period);
	next if (($opt_monthno) && ($month > $opt_monthno));
	if (($month eq '') && $opt_monthno)
		{
		$e->W("$period is missing in row $rowcnt");				# Fatal if x-dimension is NULL or missing
		next;
		}
	my $item = '$mydata';
	foreach my $pivot ('overall',@pivots)
		{
		my $ix = $row->{$pivot};
		$ix =~ s/["',]//ig;
		if (($ix eq '') && ($pivot ne 'overall'))
			{
			$ix = "Unknown $pivot";
			$e->W("Missing $pivot at line $rowcnt");
			last;
			}
		$item .= '{"'.$ix.'"}';
		foreach $measure (@measures)
			{
			my $value = $row->{$measure};
			next if ($value eq '');				# Skip this measure if it's NULL or missing
#			print "$measure Val=$value\n";
			my $trenditem = $item.'{"_trend_$measure"}{$month}';
#			print "Tallying item pivot=$pivot, ix=$ix, month=$month, item=$item\n";
			do_eval($item.'{"_cnt_$measure"}++;');
			do_eval($item.'{"_sum_$measure"} += '.$value.';');
			do_eval($trenditem.'{_cnt}++;');
			do_eval($trenditem.'{_sum} += '.$value.';');
			}
#print "item=$item\n";
		foreach $verbatim (@verbatims)
			{
			my $value = $row->{$verbatim};
			$value =~ s/Nothing//ig;
			$value =~ s/^\.$//g;
			$value =~ s/^\s+//g;
			$value =~ s/\s+$//g;
            $value =~ s/\$/\\\$/g;
            $value =~ s/\@/\\\@/g;
			next if ($value eq '');				# Skip this verbatim if it's NULL or missing

			$seqno++;
			do_eval($item.qq{{"_verbatim_\$verbatim"}{$seqno} = qq{$value};});
			}
		}
	}
print "\n";
print Dumper {%mydata} if ($opt_d);
#die "Halfway\n";
#
# Having calculated all the numbers, now we can look at dumping them out
#
$e->I("Producing pivot results");
my $title = inival('main','title',qq{$SID Overall});
our $objectid = 1;
#print "Measures=".join(",",keys %mydata)."\n";
#my @stuff = grep (!/^_/,keys %{$mydata{''}});
#my $item = $stuff[0];		# A Bit hacky to pull this element in....
#print "item=$item\n" if ($opt_d);
#our @found_months = sort {$a <=> $b} keys %{$mydata{''}{"$item"}{"_trend_$measures[0]"}};
# This is a more logical way of doing things, but it still assumes the first measure has data for every period (should be a reasonable assumption?)
our @found_months = sort {$a <=> $b} keys %{$mydata{''}{"_trend_$measures[0]"}};
print "Found months: ".join(",",@found_months)."\n" if (($opt_d));# && $opt_monthno);
recurse($measure,'',$mydata{""},$mydata{""},);
close OUT;
# 
# This little trick saves us from an empty file if something went wrong during the processing
#
my $output_file = qq{$htmldir/${opt_ini}};
print "Writing output to $output_file\n";
rename($tmp_file,$output_file) || die "Error $! encountered while creating output file: $output_file \n";

if (defined $vfh)
	{
	dump_verbatims();
	print $vfh qq{$html_code{mybottom}$html_code{rbottom}<BR>\n} if (!$vfirst);
	print $vfh $html_code{html_end};
	close $vfh;
	}
$e->I("Done.");

# ----------------------------------------------------------------------
#
# The meat of the activity is in the 'recurse' subroutine
#
# ----------------------------------------------------------------------
sub recurse
	{
	$level++;
	my $measure = shift;
	my $names = shift;
	my $data = shift;
	my $overall = shift;
	my $parent = shift;
	print "---measure=$measure---names=$names------------------\n" if ($opt_t);
	$keyh{folder} = $names;
	my $pid = ($level == 1) ? "" : "parent_id=".$idlist[$level-1];
	$idlist[$level] = $objectid;
	my $caption = qq{$names};
	$caption = $1 if ($caption =~ /^.*?,(.*?)$/);
	$titlelist[$level] = $caption;
	print OUT <<DIMENSION;

[dimension$objectid]
title=$caption
id=$objectid
$pid

DIMENSION
	$objectid++;
#
# Do a summary chart (if requested)
#
	if (inival("summary",'title'))
		{
		my $scale = inival("summary",'scale',"0,5");
		my $title = inival("summary",'title');
		my $title2 = inival("summary",'title2');
		my $latitle = inival("summary",'LeftAxisTitle');
		my $valueformat = inival("summary",'ValueFormat');
		my $navigate = inival("summary",'navigate',inival("summary",'title'));
		print OUT <<HDR;

; Summary chart
[chart$objectid]
navigate=$navigate
title=$title
title2=$title2
BottomMargin=3
scale=$scale
id=$objectid
LeftAxisTitle=$latitle
parent_id=$idlist[$level]
ValueFormat=$valueformat
HDR
		$objectid++;
		my $bxa = 0;
		my $wrap = 10;
		my @points = ();
		my @labs = ();
		my ($cnt,$avg,$sum);
		foreach my $measure (@measures)
			{
			if ($opt_monthno)
				{
				$cnt = $$data{"_trend_$measure"}{$opt_monthno}{_cnt};
				$sum = $$data{"_trend_$measure"}{$opt_monthno}{_sum};
				}
			else
				{
				$cnt = $$data{"_cnt_$measure"};
				$sum = $$data{"_sum_$measure"};
				}
			$avg = ($cnt > 0) ? $sum/$cnt : 0;
			$avg *= inival("summary",'multiplier') if (inival("summary",'multiplier') ne '');
#			print "$names / $thing avg($measure) = $avg ($sum/$cnt)\n";
			push @labs,qq{$navtitles{$measure}};
			push @points,$avg;
			}
		my $labels = join(",",@labs);
# Bottom Axis at 90 degrees if more than 5 across
		if ($#labs > 4)
			{
			$bxa = 90;
			$wrap = 0;
			}
		$labels = $overall_label if ($labels eq '');
		my $values = join(",",@points);
		my $legend = inival("summary",'title');
		print OUT <<TRACE;
wrap=$wrap
foot=$cnt responses
BottomAxisAngle=$bxa
xlabels=$labels
data1=$values
trace1=bar
legend1=$legend
TRACE
		}
#
# Do a chart for each measure listed
#
	my $im = 0;
	foreach my $measure (@measures)
		{
		my $scale = "0,5";
		$scale = $scales[$im] if ($scales[$im] ne '');
		my $bxa = 0;
		my $wrap = 10;
		my $title2 = inival("measure$measure",'title2');
		my $latitle = inival("measure$measure",'LeftAxisTitle');
		my $valueformat = inival("measure$measure",'ValueFormat');
		print OUT <<HDR;

; Measure chart for $measure
[chart$objectid]
title=$mtitles{$measure}
navigate=$navtitles{$measure}
title2=$title2
BottomMargin=3
scale=$scale
id=$objectid
LeftAxisTitle=$latitle
parent_id=$idlist[$level]
ValueFormat=$valueformat
colorfirst=$00FF8040
HDR
		$objectid++;
# ??? Gnarly one needed to pick out values for current month only
# - Month by month info is available in $$data{"_trend_$measure"}{$month}{_cnt}
		my @points = ();
		my @labs = ();
		my ($cnt,$avg,$sum);
		if ($opt_monthno)
			{
			$cnt = $$overall{"_trend_$measure"}{$opt_monthno}{_cnt};
			$sum = $$overall{"_trend_$measure"}{$opt_monthno}{_sum};
			}
		else
			{
			$cnt = $$overall{"_cnt_$measure"};
			$sum = $$overall{"_sum_$measure"};
			}
		$avg = ($cnt > 0) ? $sum/$cnt : 0;
		$avg *= $multiplier[$im] if ($multiplier[$im] ne '');
		$avg = int(1000*$avg)/1000;
		push @points,$avg;
		push @labs,"$overall_label Total ($cnt)";
		if ($opt_monthno)
			{
			$cnt = $$parent{"_trend_$measure"}{$opt_monthno}{_cnt};
			$sum = $$parent{"_trend_$measure"}{$opt_monthno}{_sum};
			}
		else
			{
			$cnt = $$parent{"_cnt_$measure"};
			$sum = $$parent{"_sum_$measure"};
			}
		if (defined $cnt)
			{
			my $name = $names;
			$name = $1 if ($name =~ /,(.*?)$/);
			push @labs,qq{$name Total ($cnt)};
			my $val = $sum/$cnt;
			$val *= $multiplier[$im] if ($multiplier[$im] ne '');
			push @points,$val;
			print OUT "colorsecond=$00FFA040\n"
			}
		foreach my $thing (sort keys %{$data})
			{
			next if ($thing =~ /^_/);		# Skip counters etc
			if ($opt_monthno)
				{
				$cnt = $$data{$thing}{"_trend_$measure"}{$opt_monthno}{_cnt};
				$sum = $$data{$thing}{"_trend_$measure"}{$opt_monthno}{_sum};
				}
			else
				{
				$cnt = $$data{$thing}{"_cnt_$measure"};
				$sum = $$data{$thing}{"_sum_$measure"};
				}
			$avg = ($cnt > 0) ? $sum/$cnt : 0;
			$avg *= $multiplier[$im] if ($multiplier[$im] ne '');
			$avg = int(1000*$avg)/1000;
	#		print "$names / $thing avg($measure) = $avg ($sum/$cnt)\n";
			push @labs,qq{$thing ($cnt)};
			push @points,$avg;
			}
		my $labels = join(",",@labs);
# Bottom Axis at 90 degrees if more than 5 across
		if ($#labs > 4)
			{
			$bxa = 90;
			$wrap = 0;
			}
		$labels = $overall_label if ($labels eq '');
		my $values = join(",",@points);
		print OUT <<TRACE;
wrap=$wrap
BottomAxisAngle=$bxa
xlabels=$labels
data1=$values
trace1=bar
legend1=$mtitles{$measure}
TRACE
		$im++;
		}
#----------------- Do the trend chart ----------------------------------
	my $trend_title = inival('trend','title',qq{Trends});
	my $title2 = inival('trend','title2',qq{Changes in satisfaction measures});
	my $tfoot = inival('trend','foot');
	my $scale = inival("trend",'scale',"0,5");
	print OUT <<HDR;

; Trend chart
[chart$objectid]
navigate=Trend
title=$trend_title
title2=$title2
BottomMargin=3
scale=$scale
BottomAxisAngle=0
id=$objectid
parent_id=$idlist[$level]
wrap=10
foot=$tfoot
ShowLegend=bottom
HDR
	$objectid++;
	my $trace = 1 ;
	my @do_months;
	if (@found_months)
		{
		foreach $month (@found_months)
			{
			my $yes = inival("trend",'all_periods',0);
			foreach my $measure (@measures)
				{
				$yes = 1 if ($$data{"_trend_$measure"}{$month}{_cnt} > 0)
				}
			push @do_months,$month if ($yes);
			}
		}

	foreach my $measure (@measures)
		{
		my @xaxis = ();
		my @values = ();
		print OUT "trace$trace=line\n";
		print OUT "legend$trace=$navtitles{$measure}\n";
		foreach $month (@do_months)
			{
			my $avg = ($$data{"_trend_$measure"}{$month}{_cnt} > 0) ? $$data{"_trend_$measure"}{$month}{_sum}/$$data{"_trend_$measure"}{$month}{_cnt} : 0;
			$avg *= $trend_multiplier[$trace-1] if ($trend_multiplier[$trace-1] ne '');
			$avg = int(1000*$avg)/1000;
# Supply a default month name:
			my $mname= $month;
# Get the format specifier
			my @fmt = split(/\s+/,inival('main','periodfmt','monname year2'));
# Reverse engineer a date
			my $up;
			foreach my $wid (@pwidths)
				{
				$up .= "a$wid";
				}
			my @date = unpack($up,$month);
			my $datestr = qq{2012/$date[0]/1};
			my @names;
			foreach (@fmt)
				{
				my $func = $date_extract_fmt{$_};		# Look up the function
				my $f = UnixDate($datestr,$func);
				print "month=$month, fmt=$_, Date=$datestr, op=$func, => $f\n" if ($opt_d);
				push @names,$f;
				}
			$mname = join(" ",@names) if ($#names != -1);
			push @xaxis,"$mname (".$$data{"_trend_$measure"}{$month}{_cnt}.")";
			push @values,$avg;
			}
		if ($trace == 1)
			{
			print OUT "xlabels=".join(",",@xaxis)."\n";
			}
		print OUT "data$trace=".join(",",@values)."\n";
		$trace++;
		}
#
# Simply stack the verbatim stuff up at this point, and we will dump it out later
# when we have the benefit of hindsight :)
# 
	foreach my $verbatim (@verbatims)
		{
		foreach my $thing (sort keys %{$data})
			{
			next if ($thing =~ /^_/);		# Skip counters etc
			next if ($level != @pivots);	# Only dump out at the lowest level
			if ($$data{$thing}{"_verbatim_$verbatim"})
				{
				my $stuff = $$data{$thing}{"_verbatim_$verbatim"};
				foreach my $ting (keys %$stuff)
					{
					$vdump{$titlelist[$level]}{$thing}{$verbatim}{$ting} = $$stuff{$ting};
					}
				}
			}
		}
		
	foreach my $thing (sort keys %{$data})
		{
		next if ($thing =~ /^_/);		# Skip counters etc
		my $n = grep (!/^_/,keys %{$$data{$thing}});
		if ($n > 0)
			{
#			print "Level $level: Recursing into $thing\n";
			my $newnames = ($names eq "") ? $thing : "$names,$thing";
			recurse($measure,$newnames,$$data{$thing},$overall,$$data{$thing});
			}
		}
	$level--;
	}
#
# Subroutine for doing en "eval" of an expression - includes error handling and trace if need be
#
sub do_eval
	{
	my $cmd = shift;
# Not sure why I have to turn this off now, because %mydata is declared with our();
#no strict;
#	print "Cmd=$cmd\n";
	eval($cmd);
#use strict;
	die "Eval error encountered: $@ while evaluating command $cmd\n" if ($@);
	}

sub inival			# Get a value from the .ini file
	{
	my $section= shift;
	my $key = shift;
	my $default = shift;
	
	my $inival = ($ini->val($section,$key) ne '') ? $ini->val($section,$key) : $default;
#	print "$key=$inival\n" if ($opt_t && ($key =~ 'title'));
	while ($inival =~ /\[\%(\w+)\%\]/)
		{
		my $token = lc($1);
		my $newting = $keyh{$token};
		$inival =~ s/\[%$token%\]/$newting/ig;
		print "Replacing \[\%$token\%\] with $newting\n" if ($opt_t);
		}
	$inival;
	}
sub merge
	{
	my $template = shift;
	my $data = shift;
#	print "Merging template: $template\n";
#	print "Merging data: $$data{title}\n";
	my $html = $html_code{$template};
#	print "html=$html\n";
	while ($html =~ /\[%(\w+)%\]/)
		{
		my $key = $1;
		my $new = $$data{$key};
#		print "Replacing $key => $new\n";
		$html =~ s/\[%$key%\]/$new/ig;
		}
	$html;
	}
sub get_html
	{
#-----------------------------------------------------------------
# HTML snippets:
#
$html_code{html_end} = <<HTML;
</form>
</BODY>
</HTML>
HTML

#-----------------------------------------------------------------
$html_code{html_hdr} = <<HTML;
<HTML>
<link rel="stylesheet" href="/themes/ekit/estyle.css">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>Verbatims Report</title>
</head>
<BODY>
Verbatims for [%SID%], generated [%when%]
HTML
#-----------------------------------------------------------------

$html_code{html_tracks} = <<HTML;
HTML
#-----------------------------------------------------------------
$html_code{mytop} = <<HTML;
<TABLE class="mytable" border="0" cellpadding=3 cellspacing=0 id="mytable[%id%]" style="display:none">
HTML
#-----------------------------------------------------------------
$html_code{mybottom} = <<HTML;
</TABLE>
HTML
#-----------------------------------------------------------------
$html_code{rtop} = <<HTML;
<TABLE class="rtable" border="0" cellpadding=5 cellspacing=0>
	<TR><TH class="boxtopleft"><IMG src="/pix/clearpixel.gif">
	<Th align=LEFT class="boxtopmiddle" onclick="document.getElementById('mytable'+[%id%]).style.display = (document.getElementById('mytable'+[%id%]).style.display == '') ? 'none' : ''">[%title%] (Click to show/hide)
	<TH class="boxtopright"><IMG src="/pix/clearpixel.gif">
<TR><TH>&nbsp;<TH>&nbsp;
HTML
#-----------------------------------------------------------------
$html_code{rbottom} = <<HTML;
	<TD>
<TR height=5><TH class="boxbottomleft" ><IMG src="/pix/clearpixel.gif">
	<TH class="boxbottommiddle"><IMG src="/pix/clearpixel.gif">
	<TH class="boxbottomright"><IMG src="/pix/clearpixel.gif">
</table>
HTML
#-----------------------------------------------------------------
$html_code{x} = <<HTML;
HTML
#-----------------------------------------------------------------

	}
	
sub dump_verbatims
	{
	my $id = 0;
#	print Dumper {%vdump} if ($opt_vd);
	my $colspan = 1;
	my $options = "options";
	my @keys = sort keys %vdump;
	foreach my $l1 (@keys)
		{
		$id++;
#		print "l1=$l1\n";
		print $vfh qq{$html_code{mybottom}$html_code{rbottom}<BR>\n} if (!$vfirst);
		print $vfh merge("rtop",{title => $l1, id => $id,}).merge("mytop",{title => $l1, id => $id,})."\n";
		$vfirst = 0;
		print $vfh qq{<tr class="heading"><TD>&nbsp;<TD>&nbsp;\n};
		foreach my $verbatim (@verbatims)
			{
			my $question = inival("measure$verbatim",'title');
#			print "  q=$question\n";
			$question = inival("measure$verbatim",'navigate');
			print $vfh qq{\t\t<TD valign="top">&nbsp;<TD valign="top"><B>$verbatim: $question</B><BR>\n};
			}
		foreach my $l2 (sort keys %{$vdump{$l1}})
			{
#			print "  l2=$l2\n";
			print $vfh qq{\t<tr class="$options"><TD colspan="$colspan" valign="top">$l1</td><TD colspan="$colspan" valign="top">$l2</td>\n};
			foreach my $verbatim (@verbatims)
				{
				my $stuff = $vdump{$l1}{$l2}{$verbatim};
#			if(0){
#					next if (!defined $stuff);
#				print Dumper {%$stuff} if ($opt_vd);
				print $vfh qq{\t\t<TD valign="top">&nbsp;<TD valign="top" width="40%">\n};
				my $ht = '';
				foreach my $ting (keys %{$stuff})
					{
					print "ting=$ting\n" if ($opt_vd);
					$ht .= qq{\t\t<P>$$stuff{$ting}\n};
					}
				print $vfh ($ht) ? $ht : '&nbsp;';
#				print "ht=$ht\n";
				}
			$options = ($options eq "options") ? "options2" : "options";
			}
		}
	}

#
# This is a reference pasted in from Date::Manip documentation, useful here when maintaining the above
#
#	 Year
#	     %y     year                     - 00 to 99
#	     %Y     year                     - 0001 to 9999
#	     %G     year                     - 0001 to 9999 (see below)
#	     %L     year                     - 0001 to 9999 (see below)
#	 Month, Week
#	     %m     month of year            - 01 to 12
#	     %f     month of year            - " 1" to "12"
#	     %b,%h  month abbreviation       - Jan to Dec
#	     %B     month name               - January to December
#	     %U     week of year, Sunday
#	            as first day of week     - 01 to 53
#	     %W     week of year, Monday
#	            as first day of week     - 01 to 53
#	 Day
#	     %j     day of the year          - 001 to 366
#	     %d     day of month             - 01 to 31
#	     %e     day of month             - " 1" to "31"
#	     %v     weekday abbreviation     - " S"," M"," T"," W","Th"," F","Sa"
#	     %a     weekday abbreviation     - Sun to Sat
#	     %A     weekday name             - Sunday to Saturday
#	     %w     day of week              - 1 (Monday) to 7 (Sunday)
#	     %E     day of month with suffix - 1st, 2nd, 3rd...
#	 Hour
#	     %H     hour                     - 00 to 23
#	     %k     hour                     - " 0" to "23"
#	     %i     hour                     - " 1" to "12"
#	     %I     hour                     - 01 to 12
#	     %p     AM or PM
#	 Minute, Second, Timezone
#	     %M     minute                   - 00 to 59
#	     %S     second                   - 00 to 59
#	     %s     seconds from 1/1/1970 GMT- negative if before 1/1/1970
#	     %o     seconds from Jan 1, 1970
#	            in the current time zone
#	     %Z     timezone                 - "EDT"
#	     %z     timezone as GMT offset   - "+0100"


sub calc_period
	{
	my $row = shift;
	my $pname = shift;
	
	my $buildw = ($#pwidths == -1);
	
	my $value = $row->{WSDate};
	print "WSDate=$value\n" if ($opt_d);	
	print Dumper $row if ($opt_d);	
	my $result = '';
	my @parts = split(/\./,$pname);
	foreach my $part (@parts)
		{
		my $res = '';
		my $wid = '';
		if ($part =~ /^(\w+)\((\w+),(\w+)\)$/)	# Does it look like a function call, ie monthof(WSDate,2) ?
			{
			my $key = $1;
			my $fld = $2;
			$wid = $3;
			my $func = $date_extract_fmt{$key};		# Look up the function
			die ("Date extraction function '$func($part)' is not supported \n") if ($func eq '');
			my $value = $row->{$fld};
			$value = qq{$1/$2/$3} if ($value =~ /^(\d\d)(\d\d)(\d\d)$/);		# Be forgiving for MAP's data entry
			$value = qq{$1/$2/$3} if ($value =~ /^(\d\d)(\d\d)(\d\d\d\d)$/);
			$res .= UnixDate($value,$func);
			}
		elsif ($part =~ /^(\w+)\((\w+)\)$/)	# Does it look like a function call, ie MonthNo(2)) ?
			{
			my $fld = $1;
			$wid = $2;
			print "fld=$fld, wid=$wid\n" if ($opt_d);
			$res = $row->{$fld};		# Must be a straight fetch of a data element
			}
		else
			{
			$res = $row->{$part};		# Must be a straight fetch of a data element
			}
		push @pwidths,($wid eq '') ? '1' : $wid if ($buildw);
		$res = sprintf("%0${wid}d", $res) if ($wid ne '');		# Now we are adding leading zeroes - what a turn around ?
#		$res =~ s/^0+([1-9])/$1/g;		# Strip away leading 0's now
		print "pname=$pname => wid=$wid, result=$res\n" if ($opt_d);
		$result .= $res;
		}
	$result = $row->{$pname} if ($result eq '');		# Get the data if nothing found
	$result;
	}
