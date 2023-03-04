#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_mli.pl,v 2.9 2012-04-11 12:48:08 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# This is a slave - should be called by a higher level wrapper
#
# NB Does not require things - assume that is already done !
#
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;								#perl2exe
use Date::Manip;							#perl2exe
use TPerl::Error; 							#perl2exe
use TPerl::CmdLine; 						#perl2exe
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 1;
$rolename = 'admin';
my $err = new TPerl::Error;
my $cmdl = new TPerl::CmdLine;
my $q = new TPerl::CGI;
my %input = $q->args;
#--------------------------------------------------------------------------------------------
# Subroutines
#
#--------------------------------------------------------------------------------------------
# Start of main code 
#
#&ReadParse(*input);
#
print "Content-Type: text/html\n\n";
print "<HTML>\n";
&add2hdr(qq{<link rel="stylesheet" href="/$config{case}/style.css">});
&add2hdr(<<JS);
<SCRIPT LANGUAGE="JavaScript">
function sel_all(prefix,nump)
	{
	for (i=1;i<=nump;i++)
		{
		control = document.getElementById(prefix+i);
//		alert("Name="+control.name);
		control.checked = !control.checked;
		}
	}
</SCRIPT>
JS
my @bits = split(/\//,$ENV{SCRIPT_NAME});
my $cgipath = $bits[1];
&add2body(qq{<FORM action="/$cgipath/pwikit_mli.pl" method="POST">});
&db_conn;
#
$survey_id = $config{master};			# This is a hack to use PWIKIT as the central authentication spot

if (0)
	{
	foreach my $key (keys %input)
		{
		&add2body("$key = $input{$key}<BR>\n");
		}
	}
my @ppicks = grep (/^ppick/,keys %input);
my @wspicks = grep (/^wspick/,keys %input);
my $show_ws = !(@wspicks || @ppicks);
my $show_pp = (@wspicks);

my $op = '';
my @idlist = ();
if ($input{idlist})
	{
	@idlist = split(/\W+/,$input{idlist});
	}

if (@ppicks)
	{
	foreach my $pp (@ppicks)
		{
		push @idlist,$input{$pp};
		}
	}
if (@idlist)
	{
	my $params = join (" ",@idlist);
	my $bno = nextbatch("$config{master}");
	my $mliname = "mli_$bno.bat";
	my $cmd = "perl ../scripts/map_report_data.pl -conn -batch=$mliname $params";
# A Little hack while we are in transition with the live site.
	$cmd = "perl ../scripts/map_report_data.pl -batch=$mliname $params";
	my $exec = $cmdl->execute (cmd=>$cmd);
	$op .= ($exec->success) ? "Success: " : "Failure: ";
	$op .= $exec->output;
	$op =~ s/\n/<BR>/g;
	$op .= qq{<P> Click <A href="/MAP101/admin/$mliname">here</A> to assemble MLI spreadsheets to download - (<I>Choose option to "Run this program from its current location"</i>)};
	&add2body(qq{<font color="red">$op</font><P>\n});
	$show_ws = 0;
	}

if ($show_ws)		# No workshops picked, so display them
	{
	my $sql = "SELECT COUNT(*) as NUM,LOCID,WSDATE_D from PWI_STATUS where WSDATE_D >= ? group by WSDATE_D,LOCID order by WSDATE_D,LOCID";
	my $date = UnixDate("2000-1-1","%G-%m-%d");
	my $th = &db_do($sql,$date);
		&add2body(<<LINE);
<TABLE class="mytable" cellspacing="0" border="0" cellpadding="5" width="100%">
	<TR class="heading">
		<TH>Location ID
		<TH>Workshop date
		<TH>Participants
		<TH>Select
LINE
	my $line = 1;
	while ($href = $th->fetchrow_hashref())
		{
		my $options = ($line % 2) ? "options" : "options2";
		&add2body(<<LINE);
	<TR class="$options">
		<TD align="Center">$$href{LOCID}
		<TD align="Center">$$href{WSDATE_D}
		<TD align="Center">$$href{NUM}
		<TD align="Center"><input type="checkbox" id="wspick$line" name="wspick$line" value="$$href{LOCID} $$href{WSDATE_D}"><LABEL for="wspick$line"> Select </label>
LINE
		$line++;
		}
	&add2body(<<FORM);
	<TR class="heading">
		<TD align="right" colspan="4">
			<input type="button" onclick="sel_all('wspick',$line)" value="Select all">
				&nbsp;&nbsp;&nbsp;&nbsp;
			<input type="submit" Value="  S u b m i t  ">
</TABLE>
FORM
	}
if ($show_pp)
	{
			&add2body(<<LINE);
<TABLE class="mytable" cellspacing="0" border="0" cellpadding="5" width="100%">
LINE
	my $line = 1;
	foreach my $wsp (@wspicks)
		{
#		&add2body("Checking $input{$wsp}<BR>\n");
		if (!($input{$wsp} =~ /(\w+)\s+(.*)$/))
			{&add2body("Unrecognized Workshop specifier: $input{$wsp}");}
		else
			{
			my $locid = $1;
			$wsdate_d = $2;
			if ($wsdate_d =~ /\*/)		# This code is defensive, in case the normal YYYY-MM-DD format isn't used
				{
				my @bits = split(/\//,$wsdate_d);
				$wsdate_d = "20$bits[2]-$bits[0]-$bits[1]";
				}
			&add2body(<<LINE);
	<TR class="heading">
		<TD colspan="2">Workshop: $locid $wsdate_d
LINE
			my $sql = "SELECT UID,FULLNAME,LOCID,WSDATE_D from PWI_STATUS where LOCID=? and WSDATE_D = ? and WSDATE <> 'HOLD' and WSDATE <> 'CANCEL' order by UID";
			my $th = &db_do($sql,$locid,$wsdate_d);
			&add2body(<<LINE);
	<TR class="heading">
		<TH>Participant
		<TH>Select
LINE
			while ($href = $th->fetchrow_hashref())
				{
				my $options = ($line % 2) ? "options" : "options2";
				&add2body(<<LINE);
	<TR class="$options">
		<TD align="Center">$$href{FULLNAME}
		<TD align="Center"><input type="checkbox" id="ppick$line" name="ppick$line" value="$$href{UID}"><LABEL for="ppick$line"> Select </label>
LINE
				$line++;
				}
			}
		}
	&add2body(<<FORM);
	<TR class="heading">
		<TD align="right" colspan="4">
			<input type="button" onclick="sel_all('ppick',$line)" value="Select all">
				&nbsp;&nbsp;&nbsp;&nbsp;
			<input type="submit" Value="  S u b m i t  ">
	</table>
FORM
}

&add2body(<<FORM);
<P>
	<TABLE class="mytable" cellpadding="5" cellspacing="0" border="0" width="100%">
	<TR class="heading"><TD colspan="2">MLI Spreadsheet assembly</TR>
	<TR class="options"><TD valign="top">Please enter ID's to assemble:
							<BR>(Separate by spaces or commas)
	<TD><TEXTAREA name="idlist" cols="40" rows="6"></TEXTAREA>
	<TR class="heading"><TD colspan="2" align="right"><input type="submit" Value="  S u b m i t  "></TR>
	</table>
FORM
&db_disc;
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
