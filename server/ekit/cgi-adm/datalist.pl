#!/usr/bin/perl
#
# $Id: datalist.pl,v 1.3 2006-10-20 01:05:25 triton Exp $
#
require 'TPerl/cgi-lib.pl';
require 'TPerl/qt-libdb.pl';
use CGI::Carp qw(fatalsToBrowser);
use POSIX qw(strftime);
use strict;
#
our %input;
our %resp;
our $numq;
our $array_sep;
our %qlabels;
our $qt_root;
our @major_sections;
our %dcounts;
our %datalist;
our %listoptions = 
				(
				delete => 1,
				viewdata => 1,
				opensurvey => 1,
				document => 1,
				search => 0,
				); 

sub geturi
	{
	my $sid = shift;
	my $url = $ENV{REQUEST_URI};
	if (!($url =~ /\?/))
		{
		$url .= qq{?survey_id=$sid};
		}
	$url;
	}
#
&ReadParse(*input);
print &PrintHeader;
print <<HEAD;
<HTML>
<HEAD>
HEAD
my $error = '';
my $survey_id = $input{'survey_id'};
$error = "Missing survey ID" if ($survey_id eq '');
my $thedir = 'web';
my $show = $input{show} || 10;
my $start_at = $input{start_at} || 1;
my $stop_after = $start_at + $show - 1;
my $fam_no = $input{fam_no};
my $more = 0;
my $less = 0;
$less = ($start_at > 1);
print <<HEAD;
	<STYLE TYPE="text/css">
	.prompt {  font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 12pt; font-style: normal; font-weight: bold; }
	.qlabel { color:red; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 10pt; font-style: normal; font-weight: bold; }
	.heading { background-color: navy; color:white; font-family: Arial, Helvetica, sans-serif; font-size: 8pt; font-style: normal; font-weight: normal; }
	.subheading { background-color: royalblue; color:white; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 7pt; font-style: normal; font-weight: normal; 
				border-width:0px; border-color:black; border-style:solid;}
	.total { background-color: deepskyblue; color:#000000; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 7pt; font-style: normal; font-weight: bold; }
	.options { background-color: lightskyblue; color:#000000; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 7pt; font-style: normal;  }
	.options2 { background-color: PALETURQUOISE; color:#000000; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 7pt; font-style: normal;  }
	.instruction {  color:#0000FF; font-family: Arial, Helvetica, sans-serif; font-style: normal; font-size: 12pt; font-weight: bold; }
	.default {  }
	.links {  font-family: Arial, Helvetica, sans-serif; font-size: 10pt}
	.body { background-color: CORNFLOWER; font-family: Arial, Helvetica, sans-serif; font-size: 9pt}
	.notes { background-color: LEMONCHIFFON; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 7pt}
	.mytable { color:black; border-width:2px; border-color:BLUE; border-style:solid;}
	</STYLE>
</HEAD>
<BODY class="body">
HEAD

my @bits = split(/\//,$ENV{SCRIPT_NAME});
my $cgipath = $bits[1];
my $line;
my $dir;
my $sections = '';
if (!$error)
	{
	$line = 0;
	$dir = "${qt_root}/${survey_id}/$thedir";
	get_config($survey_id);
#	print "DELETE=$listoptions{delete}\n";
#	if (@major_sections)
#		{
		push @major_sections,"EXT";
		push @major_sections,"MASK";
		push @major_sections,"VAR";
		$sections = qq{<TD class="heading">}.join('</TD><TD class="heading">',@major_sections)."</TD>" if $listoptions{viewdata};
#		}
	}
if (!$error)
	{
	if (!-d $dir)
		{
		$error = qq{Error: Cannot find directory [$dir]};
		}
	}
if (!$error)
	{
	if ($input{delete} ne '')
		{
		my $del_file = "${qt_root}/${survey_id}/$thedir/$input{delete}";
		my $target_dir = "${qt_root}/${survey_id}/deleted";
		mkdir($target_dir) || die "Error: $! while creating directory $target_dir" if (!-d $target_dir);
		my $target_file = "$target_dir/$input{delete}";
		if (-f $del_file)
			{
			rename $del_file,$target_file;
			print qq{<font color="blue" size="-1">File moved to $target_file</FONT><HR>}
			}
		else
			{print qq{<FONT color="RED"><B>Error:</B> could not find file: $del_file</FONT><HR>};}
		}
	opendir(DDIR,$dir) || die "Error $! while scanning directory $dir\n";
	print <<SEARCH if ($listoptions{search});
<FORM action="/$cgipath/datalist.pl" method="POST">
<INPUT name="survey_id" type="hidden" value="$survey_id" >
Look for: <INPUT name="find" type="text" >
<INPUT TYPE="SUBMIT" Value="Find">
</FORM>
SEARCH
#	print "Data files in directory $dir:<BR>\n";
	my @files = grep (/^D.*?\.pl.*/,readdir(DDIR));		# Only look at D-files
	print qq{<TABLE CELLPADDING="5" CELLSPACING="0" BORDER=0 class="mytable">\n};
	my @extras = (qw{fam_no id_no int_no ver});
	my $extras_td = join("</TD><TD>",@extras);
	if (%datalist)
		{
		undef @extras;
		@extras = values %datalist;
		$extras_td = join("</TD><TD>",keys %datalist);
		}
	my $counter = 	qq{<TD>Count</TD>} if ($listoptions{viewdata});
	print qq{<tr class="heading"><TD>File</TD><TD>Modified</TD><TD>$extras_td</TD>$counter$sections</tr>};
	foreach my $dfile (@files)
		{
		if (($line >= ($start_at-1)) && ($line <= ($stop_after-1)))
			{
			$sections = '';
			my $fname = "$dir/$dfile";
			my $n = (stat($fname))[9];
			undef %resp;
			my_require($fname,1);
			next if ($fam_no ne '') && ($fam_no ne $resp{ext_fam_no});
			if ($input{find} ne '')
				{
				next if (!grep(/$input{find}/i,values %resp));
				}
			if ($input{status} ne '')
				{
				next if ($resp{status} eq '');
				next if (!grep(/$resp{status}/i,$input{status}));
				}

			my $cnt = &count_data;
	    	my $when = strftime "%x %H:%M:%S", localtime($n);
	#		my $when = localtime($n);
			next if (/^\./);
			my @extras_txt = ();
			foreach my $item (@extras)
				{
				my $val = '';
				if ($item =~ /^(\w+)\[(\w+)\]$/)
					{
					my $var = $1;
					my $ix = $2-1;			# Array starts at [1]
					my $data = $resp{$var};
					if ($data eq '')
						{
						$data = $resp{"_Q$var"};
						}
					my @bits = split(/$array_sep/,$data);
					$val = $bits[$ix];
					}
				elsif ($item =~ /^[\w-]+$/)
					{
					$val = $resp{$item};
					if ($val eq '')
						{
						$val = $resp{"_Q$item"};
						}
					$val =~ s/^"//;		# Strip off quotes
					$val =~ s/"$//;
					$val = $resp{"ext_$item"} if $val eq '';
					if ($item eq 'fam_no')
						{
						my $uri = geturi($survey_id);
						$uri =~ s/\&fam_no=\d+//i;
						$val = qq{<A HREF="$uri&fam_no=$val">$val</A>};
						}
					}
				else
					{
					$val = eval($item);
					}
				push @extras_txt,$val;
				}
			my $extras_td = join(qq{</TD><TD valign="top">},@extras_txt);
			my $uri = geturi($survey_id);
			$uri =~ s/&delete=.*?\.pl//i;
			$uri .= qq{&delete=$dfile};
			my $del_link = ($listoptions{delete}) ? qq{<A HREF="$uri"><IMG src="/admin/trash.gif" alt="Delete this file" border="0"></A>} : '';
			my @scounts = ();
			my $options = ($line % 2) ? "options" : "options2";
			my $sec;
			if (@major_sections)
				{
				foreach $sec (@major_sections)
					{
					push @scounts,qq{<A HREF="/$cgipath/datashow.pl?survey_id=$survey_id&section=$sec&file=$dfile" target="_blank">$dcounts{$sec}</a>};
					}
				$sections = qq{<TD class="$options" align="right" valign="top">}.join('</TD><TD class="$options" align="center" valign="top">',@scounts)."</TD>" if $listoptions{viewdata};
				}
			my $seq = 0;
			$seq = $1 if ($dfile =~ /^D(\d+).pl$/i);
			my $dfile_link = ($listoptions{opensurvey}) ? qq{<A HREF="/cgi-mr/godb.pl?survey_id=$survey_id&seqno=$seq&q_label=FIRST" target="_blank">$resp{seqno}</A>  } : $seq;
			my $doc_link = '';
			if ($listoptions{document})
				{
				my $docdir = "${qt_root}/${survey_id}/doc";
				if (-f "$docdir/$seq.rtf")
					{
					my $uri = qq{http://$ENV{SERVER_NAME}/cgi-mr/getdoc.pl/$seq.doc?sid=$survey_id&seqno=$seq};
					my $when = localtime((stat("$docdir/$seq.rtf"))[9]);
					$doc_link = qq{<A HREF="$uri" target="_blank"><IMG src="/admin/word.gif" alt="View document (modified $when)" border="0"></A>};
					}
				}
			my $counter = 	<<CNT if ($listoptions{viewdata});
	<TD align="right" valign="top">
		<A HREF="/$cgipath/datashow.pl?survey_id=$survey_id&section=$sec&file=$dfile" target="_blank">
		<B>$cnt<B></A></TD>
CNT
			print <<STUFF;
<tr class="$options">
	<TD valign="top">$del_link $dfile_link $doc_link</TD><TD valign="top">$when</TD><TD valign="top">$extras_td</TD>
	$counter
	$sections</tr>
STUFF
			}
		$line++;
		}
	$more = ($line > $stop_after);
	closedir(DDIR);
	print "</TABLE>\n";
	}
if ($error)
	{
	print <<STUFF;
<H2><font color="red">$error</FONT></H2><HR>
<FORM action="/$cgipath/datalist.pl" method="GET">
Survey ID: <INPUT name="survey_id" type="text"><BR>
<INPUT TYPE="SUBMIT" Value="Submit">
</FORM>
STUFF
	}		
print "<HR>\n";
if ($more || $less)
	{
	my $uri = geturi($survey_id);
	$uri =~ s/\?.*$//g;
	$uri .= '?';
	$uri .= "survey_id=$survey_id&show=$show&";
	$uri .= qq{find=$input{find}&} if ($input{find} ne '');
	print(<<BODY);
<A href="${uri}start_at=1"><IMG border="0" src="/admin/first.gif" alt="First page"></A>&nbsp;
BODY
	if ($less)
		{
		my $new_start = $start_at - $show;
		print(<<BODY);
<A href="${uri}start_at=$new_start"><IMG border="0" src="/admin/prev.gif" alt="Previous page"></A>&nbsp;
BODY
		}
	else
		{
		print(qq{<IMG border="0" src="/admin/blanknext.gif" alt="already at first page">});
		}
	if ($more)
		{
		my $new_start = $start_at + $show;
		print(<<BODY);
<A href="${uri}start_at=$new_start"><IMG border="0" src="/admin/next.gif" alt="Next page"></A>&nbsp;
BODY
		}
	else
		{
		print(qq{<IMG border="0" src="/admin/blanknext.gif" alt="already at last page">});
		}
#	$last = $#ids - ($#ids % $show_n);
	my $d_one = $start_at ;
	my $d_last = $start_at + $show -1;
	$d_last = $line if ($line < $d_last);
	my $d_tot = $line;
	my $last = $show*(int($line / $show))+1;
	print(<<BODY);
<A href="${uri}start_at=$last"><IMG border="0" src="/admin/last.gif" alt="last page"></A>
Files $d_one to $d_last of $d_tot <BR>
BODY
	}
print qq{<A HREF="/cgi-mr/godb.pl?survey_id=$survey_id&q_label=FIRST" target="_blank">NEW DFILE</A>  } if $ENV{REMOTE_USER} eq 'ac';
print <<EOF;
	</BODY>
	</HTML>
EOF

1;

