#!/usr/bin/perl
# $Id: xlate.pl,v 1.12 2011-08-30 00:21:04 triton Exp $
# Kwik script to accept foreign language files, and then do a token2text and qfiles
#
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::CmdLine;
our ($survey_id,%resp,$do_cookies,$open_survey);
our ($form,$data_dir,$language,$charset);
our ($ufile,$qt_root,%ufields,$use_q_labs,%qlabels);
our ($seqno,%dun,$prompt,$this_answer,$q_no,$q_label,$autoselect,%jumps,$qtype,$mike,$qlab);
our ($virgin,$dive_in,$plain,$numq,$allow_restart,$start_q_no,$auto_create,$allow_leading_0);
our ($QTYPE_EVAL,$QTYPE_CODE);

require 'TPerl/qt-libdb.pl';

my $q = new TPerl::CGI;
&get_root;
print "Content-Type: Text/HTML\n\n";
my $buf = $q->param('stuff');
my $survey_id = $q->param('survey_id');
$language = uc($q->param('language'));
$charset = $q->param('charset');
my $en_survey_id = $q->param('en_survey_id');
$survey_id = $en_survey_id if ($q->param('toggle'));
my $errmsg = '';
$errmsg .= "- You must specify a survey id.\n" if ($survey_id eq '');
$errmsg .= "- You must specify an English survey id.\n" if ($en_survey_id eq '');
$errmsg .= "- Please paste in Excel file contents.\n" if ($buf eq '');
$errmsg =~ s/\n/<br>/g;
my $htdir = "$qt_root/$survey_id/html";
if (($buf eq '') || ($errmsg ne ''))
	{
	my $html_checked = (-d $htdir) ? "" : "CHECKED";
	print <<HTML;
<HTML>
<HEAD>
	<TITLE>Triton Translation tool</title>
	<link rel="stylesheet" href="style.css">
</head>
<BODY class="body">
<FONT face="arial">
<!--[if IE]>
<FONT color="red"><B>WARNING: THIS DOES NOT WORK WITH INTERNET EXPLORER - YOU NEED TO USE FireFox or Opera !!!</B></font><BR>
<style type="text/css">
.content{display:none}
</style>
<![endif]-->
<div class="content">
<FONT color="red"><B>$errmsg</B></font><BR>
<FORM action="/cgi-adm/xlate.pl" method="POST">
<table class="mytable" border=0 cellpadding=5 cellspacing=0>
<TR class="heading"><TD colspan=2>Translation tool
<tr class="options">
	<td>English Survey ID: 
	<td><INPUT TYPE="text" name="en_survey_id" value="$en_survey_id"><BR>
<tr class="options">
	<td>Translation Method: 
	<td><INPUT TYPE="radio" name="toggle" value="1" id="t1" onclick="document.getElementById('sep').style.display = 'none'" > 
					<label for="t1"  onclick="document.getElementById('sep').style.display = 'none'">Toggle</label> &nbsp;&nbsp;&nbsp;
		<INPUT TYPE="radio" name="toggle" value="0" id="t2" onclick="document.getElementById('sep').style.display = ''"      CHECKED > 
					<label for="t2" onclick="document.getElementById('sep').style.display = ''">Separate surveys</label>
<tr class="options" id="sep">
	<td>Target Survey ID: 
	<td><INPUT TYPE="text" name="survey_id" value="$survey_id"><BR>
<tr class="options">
	<td>Language (2 character code, upper case)
	<td><INPUT TYPE="text" name="language" value="$language"><BR>
<tr class="options">
	<td>Character set 
	<td><select name="charset">
		<option value="">Select --></option>
		<option value="windows-1252">Arabic (windows-1252)</option>
		<option value="cn-GB">Chinese (simplified: cn-GB)</option>
		<option value="cn-Big5">Chinese (traditional: cn:Big5)</option>
		<option value="euc-kr">Korean (euc-kr)</option>
		<option value="shift-JIS">Japanese (shift-JIS)</option>
		<option value="CP1251">Russian (CP1251)</option>
		<option value="CP1253">Greek (CP1253)</option>
	</select>
	<BR>
<tr class="options">
	<td>Run compiler too ?
	<td><INPUT TYPE="checkbox" name="compile" CHECKED value="1"><BR>
<tr class="options">
	<td>Generate HTML too (Usually needed the first time)?
	<td><INPUT TYPE="checkbox" name="html" $html_checked value="1"><BR>
<tr class="options">
	<td colspan=2>Please paste your data below: <i>(This data should be pasted from Excel file XXX101_xlate.xls, including all the headings)</i><BR>
	<TEXTAREA rows=20 cols=80 name="stuff">$buf</TEXTAREA><BR>
<tr class="options">
	<td colspan=2><CENTER><INPUT type="submit"></CENTER>
	</table>
</FORM>
</div>
</BODY>
</HTML>
HTML
	}
else
	{
	my $toggle = ($q->param('toggle')) ? "-toggle" : '';
	my $file = "$qt_root/$survey_id/config/${survey_id}_xlate.txt";
	$file = "$qt_root/$survey_id/config/${survey_id}_xlate_$language.txt" if ($toggle);
	open OUT,">$file" || die "Error $! encountered while writing to file: $file\n";
	print OUT $buf;
	close OUT;
	print "File [$file] Saved OK\n";
	print "<HR><B>Assembling survey file from data:</b><br>\n";
	my $cmd = new TPerl::CmdLine;
	my $res = $cmd->execute (cmd=>"perl ../scripts/token2text.pl -nodb -language=$language -charset='$charset' $toggle $survey_id $en_survey_id ");
	my $out = $res->output;
	$out =~ s/\n/<BR>\n/ig;
	print  "$out\n";

# Generate vertical images for rank qtypes (if present)
	my $vertsh = qq{$qt_root/$survey_id/config/verticals.sh};
	if (-f $vertsh) {
		print "<HR><B>Generating vertical images for rank questions (drag n drop) :</b><br>\n";
		my $res = $cmd->execute (cmd=>"bash $vertsh");
		my $out = $res->output;
		$out =~ s/\n/<BR>\n/ig;
		print  "$out\n";
	}

	my $compile = $q->param('compile');
	if ($compile)
		{
		print "<HR><B>Compiling file:</b><br>\n";
		my $res = $cmd->execute (cmd=>"perl ../scripts/qfiles.pl -quick $survey_id ");
		my $out = $res->output;
		$out =~ s/\n/<BR>\n/ig;
		print  "$out\n";
		}
	my $html = $q->param('html');
	if ($html)
		{
		print "<HR><B>Generating HTML files:</b><br>\n";
		mkdir $htdir unless -d $htdir;
		my $res = $cmd->execute (cmd=>"perl -s ../scripts/aspsurvey2DHTML.pl -no_wait generate $survey_id ");
		my $out = $res->output;
		$out =~ s/\n/<BR>\n/ig;
		print  "$out\n";
		}
	if ($html || $compile)
		{
		my $webdir = "$qt_root/$survey_id/web";
		mkdir $webdir unless -d $webdir;
		print qq{<P><a target="_blank" href="/cgi-mr/godb.pl?q_label=first&survey_id=$survey_id">Test</a>\n};
		}
	}
