#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: pwikit_status2.pl,v 2.8 2012-10-02 23:11:25 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 2003 Triton Information Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# pwikit_status.pl - Show status page for PWI Kit
#
#
use TPerl::CGI;
use Date::Parse;
use Time::Piece;

require 'TPerl/qt-libdb.pl';
#
# Get the specific stuff we need
#
require 'TPerl/360-lib.pl';
$simulate_frames = 0;
require 'TPerl/pwikit_cfg.pl';
#
# Like it or not, this page is custom for the PWIKit, so we have no 360- equivalent to call.
# We just have to get on and cut the code for it.
#
use CGI::Carp qw(fatalsToBrowser);

# Method to spin the date format around
sub spin_date
	{
	my $in = shift;
	my @bits = split(/-/,$in);
	my $out = qq{$bits[1]-$bits[2]-$bits[0]};
	}
#
print qq{Content-Type: text/html
Pragma: no-cache
Cache-Control: no-cache
Expires: -1

<HTML>
};
&db_conn;						# Connect to database
&db_new_survey($config{master});		# Make sure the receiving table exists
#
$do_body = 1;
$plain = 1;
$form = 0;

my @colnames = (qw{EXECNAME LOCID WSDATE DUEDATE FULLNAME CMS_STATUS CMS_FLAG ISREADY SELFREADY BOSSREADY PEERREADY Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10A Q18 Q11 Q12 Q10 CNT});
my $cspan = $#colnames + 1;
my $tick = qq{<IMG src="/pwikit/tick.gif">};
my $btn     = qq{<IMG border=0 src="/pwikit/item.gif" ALIGN="ABSMIDDLE">};
my $btnorm  = qq{<IMG border=0 src="/pwikit/item.gif" ALIGN="ABSMIDDLE">};
my $btnplus = qq{<IMG border=0 src="/pwikit/plus.gif" ALIGN="ABSMIDDLE">};

#--------------------------------------------------------------------------------------------
# Start of main code 
#
#&ReadParse(*input);
our $q = new TPerl::CGI;
our %input = $q->args;

#
&add2hdr("<TITLE>$config{title} status page </TITLE>");
&add2hdr("   <META NAME=\"Triton Information Technology Software\">");
&add2hdr("   <META NAME=\"Author\" CONTENT=\"Mike King (213) 488 2811\">");
&add2hdr("   <META NAME=\"Copyright\" CONTENT=\"Triton Technology 1995-2003\">");
&add2hdr("<link rel=\"stylesheet\" href=\"/themes/ekit/style.css\">");
#
&add2body(qq{<FORM name="q" action="$ENV{SCRIPT_NAME}" method="POST">
});
my $locid = $input{LOCID};
my $wsdate = $input{WSDATE};
my $consultant = $input{CONSULTANT};
#
# Display the navigation controls
#
#$dbt = 1;
my $nav = '';
$nav .= <<NAV;
<B>Location:</B>
<select NAME="LOCID">
  <OPTION VALUE="">All
NAV
my $sql = "select DISTINCT LOC_CODE AS LOCID FROM PWI_LOCATION ORDER BY LOC_CODE";
&db_do($sql);
while (my @row = $th->fetchrow())
	{
	my $selected = ($locid eq $row[0]) ? "SELECTED" : "";
	$nav .= qq{<OPTION VALUE="$row[0]" $selected>$row[0]\n} if ($row[0] ne '');
	}
$nav .= "</SELECT>\n";
$th->finish();


$nav .= <<NAV;
<B>Consultant:</B>
<select NAME="CONSULTANT">
  <OPTION VALUE="">All
NAV
my $sql = "select DISTINCT EXEC_NAME AS EXECNAME FROM PWI_EXEC ORDER BY EXEC_NAME";
&db_do($sql);
while (my @row = $th->fetchrow())
	{
	$row[0] =~ s/^"//;
	$row[0] =~ s/"$//;
	$row[0] =~ s/""/"/g;
	my $selected = ($consultant eq $row[0]) ? "SELECTED" : "";
	$nav .= qq{<OPTION VALUE="$row[0]" $selected>$row[0]\n} if ($row[0] ne '');
	}
$nav .= "</SELECT>\n";
$th->finish();

$nav .= <<NAV;
<B>WS Date:</B>
<select NAME="WSDATE">
  <OPTION VALUE="">All
NAV
my $age = $input{AGE} || 15;
my $delta = $age*24*60*60;	# Limit selections to 30 day old workshops
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time-$delta);
$year += 1900;
$mon++;	
#$dbt=1;
my $where = qq{WHERE WS_STARTDATE >= '$year-$mon-$mday' };		# PROBLEM: WSDATE IS JUST A STRING FIELD
#print "WHERE=$where \n";
my $sql = "select DISTINCT WS_STARTDATE AS WSDATE FROM PWI_WORKSHOP $where ORDER BY WS_STARTDATE";
&db_do($sql);
while (my @row = $th->fetchrow())
	{
	my $selected = ($wsdate eq $row[0]) ? "SELECTED" : "";
	$nav .= qq{<OPTION VALUE="$row[0]" $selected>$row[0]\n} if ($row[0] ne '');
	}
$nav .= "</SELECT>\n";
$th->finish();
$nav .= <<NAV;
<B>WS Age:</B>
<input name="AGE" type="TEXT" value="$age" size=4>
NAV

$nav .= qq{<INPUT TYPE="SUBMIT" VALUE="Refresh">\n};
#
# Display the table of respondents
#
my $main = '';
if (($locid eq '') && ($wsdate eq '') && ($consultant eq ''))
	{
	$main .= "Please make one or more selections above";
	}
else
	{
	$main .= qq{<TABLE CELLPADDING="3" BORDER="0" CELLSPACING="0" class="mytable">\n<tr class="heading"><TD>};
	$main .= join("</TD><TD>",("Exec. Cons.",qw{Loc. WSDate DueDate Participant. Status Flag Qualify Self Boss KP Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10A Q18 Q11 Q12 Q10 Total}));
	$main .= qq{</TD></tr>\n};
	my $sql = qq{SELECT * FROM $config{status} };
	my $conjunction = "WHERE WSDATE_D >= '$year-$mon-$mday' AND";
	my @params = ();
	if ($locid ne '')
		{
		$sql .= "$conjunction LOCID = ?";
		$conjunction = "AND";
		push @params,$locid;
		}
	if ($wsdate ne '')
		{
		$sql .= " $conjunction WSDATE_D = ?" ;
		$conjunction = "AND";
		push @params,$wsdate;
		}
	if ($consultant ne '')
		{
		$sql .= " $conjunction EXECNAME = ?" ;
		$conjunction = "AND";
		push @params,$consultant;
		}
	#$dbt=1;
	$sql .= " ORDER BY LOCID,WSDATE_D,DUEDATE";


open my $skiphandle, '<', '/home/vhosts/ekit/htekit/surveyshutdown';
chomp(my @lines = <$skiphandle>);
close $skiphandle;

foreach (@lines) {
	@values = split(/:/,$_);
	$time2 = str2time(@values[1]);
}


	&db_do($sql,@params);
	my $rowclass = "options";
	my $execname = '';
	my $duedate = '';
	my $wsdate = '';
	my $locid = '';
	my $separator = qq{};#<tr bgcolor="black" height="1px"><TD colspan="$cspan"></TD></TR>\n};
	while (my $href = $th->fetchrow_hashref())
		{

		$found = 0;
		my $wsdate = $$href{WSDATE};

		$time = str2time($wsdate);

		if ($time2 lt $time)
		{
			$found = 1;
		}


		my $line = '';
		my @data = ();
		my $ix = 0;
		foreach my $col (@colnames)
			{
			my $align = ($ix > 4) ? qq{ALIGN="CENTER"} : '';
			my $val = $$href{$col};
			if (($col =~ /^Q/) && ($val eq ''))
				{
				$val = (grep(/^$col$/,qw{Q1 Q3 Q6 Q7 Q10A Q10 Q18})) ? '<font color="red"><B>X</B></font>' : '-';
				if (grep(/^$col$/,qw{Q11 Q12}))
					{
					$val = ($$href{NBOSS} > 0) ? '<font color="red"><B>X</B></font>' : '-';
					}
				}
			$val = '&nbsp;' if ($val eq '');
			if ($col eq 'EXECNAME')
				{
				$val = "<B>$val</B>";
				if ($execname eq $$href{EXECNAME})
					{
					$val = '&nbsp;' 
					}
				else
					{
					$duedate = '';
					$wsdate = '';
					$locid = '';
					}
				}
			$val = &spin_date($val) if ($col eq 'WSDATE');
			$val = &spin_date($val) if ($col eq 'DUEDATE');
			$val = '&nbsp;' if (($locid eq $$href{LOCID}) &&($col eq 'LOCID'));
			$val = '&nbsp;' if (($duedate eq $$href{DUEDATE}) &&($col eq 'DUEDATE'));
			$val = '&nbsp;' if (($wsdate eq $$href{WSDATE}) &&($col eq 'WSDATE'));
			if ($col =~ /READY$/i)
				{
				$val = ($val eq '1') ? $tick : '&nbsp;';
				}
			if (grep(/^$col$/,qw{Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10A Q18}))
				{
				if ($val eq '1')
					{
					$val = '<B>&radic;</B>' ;
					}
				$val = '&nbsp;' if ($val eq '0');
				}
			elsif ($col eq 'Q10')
				{
				$val = qq{$val/$$href{NPEER}};
				}
			if ($col eq 'FULLNAME')
				{
	#			$val = qq{<A HREF="/cgi-adm/pwikit_editp.pl?id=$$href{UID}&password=$$href{PWD}" target="_blank">$val</A>};
				}
			if ($col eq 'Q7' && $found == '1')
			{
				$val = '&nbsp;';
			}
			$line .= qq{<TD $align>$val</TD>};
			$ix++;
			}
		if ($execname ne $$href{EXECNAME})
			{
			$main .= $separator;
			}
		elsif ($locid ne $$href{LOCID})
			{
			$main .= $separator;
			}
		$main .= qq{<tr class="$rowclass">$line</tr>\n};
		$rowclass = ($rowclass eq "options") ? "options2" : "options";
		$execname = $$href{EXECNAME};
		$duedate = $$href{DUEDATE};
		$wsdate = $$href{WSDATE};
		$locid = $$href{LOCID};
		}
	$main .= qq{</TABLE>\n};
	}
&add2body(qq{
<table border=0 cellpadding=0 cellspacing=0 class="bannertable" style="margin:10px;" width="820px">
	<tr>
		<TD class="bannerlogo" colspan="3">&nbsp;
	<tr>
		<TD class="bluebarw" ALIGN="left"> 
		&nbsp;&nbsp; Status Page &nbsp;&nbsp;
</table>
});
&add2body(qq{<TABLE border="0" cellpadding="3" cellspacing="0"><tr><TD valign="top">$nav</TD></tr><tr><TD valign="top">$main</TD></TR></TABLE>});
&add2body(qq{</FORM>});
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
&db_disc;
1;
