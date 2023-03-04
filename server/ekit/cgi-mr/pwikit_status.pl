#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
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
require 'TPerl/cgi-lib.pl';
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
print "Content-Type: text/html\n\n";
print "<HTML>\n";
&db_conn;						# Connect to database
&db_new_survey($config{master});		# Make sure the receiving table exists
#
$do_body = 1;
$plain = 1;
$form = 0;

my @colnames = (qw{EXECNAME LOCID WSDATE DUEDATE FULLNAME ISREADY Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10A Q11 Q12 Q10 CNT});
my $cspan = $#colnames + 1;
my $tick = qq{<IMG src="/pwikit/tick.gif">};
my $btn     = qq{<IMG border=0 src="/pwikit/item.gif" ALIGN="ABSMIDDLE">};
my $btnorm  = qq{<IMG border=0 src="/pwikit/item.gif" ALIGN="ABSMIDDLE">};
my $btnplus = qq{<IMG border=0 src="/pwikit/plus.gif" ALIGN="ABSMIDDLE">};

#--------------------------------------------------------------------------------------------
# Start of main code 
#
&ReadParse(*input);
#
&add2hdr("<TITLE>$config{title} status page </TITLE>");
&add2hdr("   <META NAME=\"Triton Information Technology Software\">");
&add2hdr("   <META NAME=\"Author\" CONTENT=\"Mike King (213) 488 2811\">");
&add2hdr("   <META NAME=\"Copyright\" CONTENT=\"Triton Technology 1995-2003\">");
&add2hdr("<link rel=\"stylesheet\" href=\"/$config{case}/style.css\">");
#
&add2body(qq{<FORM name="q" action="$ENV{SCRIPT_NAME}" method="POST"><IMG SRC="/MAP001/banner600.gif">\n});
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
my $sql = "select DISTINCT LOCID FROM $config{status} ORDER BY LOCID";
my $sql = "select DISTINCT LOCID FROM PWI_LOCS ORDER BY LOCID";
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
my $sql = "select DISTINCT EXECNAME FROM $config{status} ORDER BY EXECNAME";
my $sql = "select DISTINCT EXECNAME FROM PWI_EXECS ORDER BY EXECNAME";
&db_do($sql);
while (my @row = $th->fetchrow())
	{
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
my $sql = "select DISTINCT WSDATE FROM $config{status} ORDER BY WSDATE";
my $sql = "select DISTINCT WSDATE FROM PWI_WSDATES ORDER BY WSDATE";
&db_do($sql);
while (my @row = $th->fetchrow())
	{
	my $selected = ($wsdate eq $row[0]) ? "SELECTED" : "";
	$nav .= qq{<OPTION VALUE="$row[0]" $selected>$row[0]\n} if ($row[0] ne '');
	}
$nav .= "</SELECT>\n";
$th->finish();

$nav .= qq{<INPUT TYPE="SUBMIT" VALUE="Refresh">\n};
my $sql = "select count(*) CNT,LOCID,WSDATE,LOCNAME FROM $config{status} GROUP BY LOCID,WSDATE,LOCNAME ORDER BY LOCID,WSDATE,DUEDATE";
&db_do($sql);
if ($do_tree)
	{
	$nav .= "<B>Location/Date:</B><BR>";
	my $clocid = '';
	my $cwsdate = '';
	while (my $href = $th->fetchrow_hashref)
		{
		$locid = $$href{LOCID} if ($locid eq '');
		if (lc($clocid) ne lc($$href{LOCID}))
			{
			$nav .= qq{<A HREF="$ENV{SCRIPT_NAME}?LOCID=$$href{LOCID}">$$href{LOCID} </A><BR>\n} ;
			}
		if (lc($cwsdate) ne lc($$href{WSDATE}))
			{
			$nav .= qq{&nbsp;&nbsp;&nbsp;&nbsp;<A HREF="$ENV{SCRIPT_NAME}?LOCID=$$href{LOCID}&WSDATE=$$href{WSDATE}">$$href{WSDATE} </A><BR>\n};
			}
	#	$nav .= qq{&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<A HREF="$ENV{SCRIPT_NAME}?LOCID=$$href{LOCID}&WSDATE=$$href{WSDATE}&LOCNAME=$$href{LOCNAME}">$$href{LOCNAME} ($$href{CNT})</A><BR>\n};
		$cwsdate = $$href{WSDATE};
		$clocid = $$href{LOCID};
		}
	$th->finish();
	}
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
	$main .= join("</TD><TD>",("Exec. Cons.",qw{Loc. WSDate DueDate Participant. Qualify Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10A Q11 Q12 KP Total}));
	$main .= qq{</TD></tr>\n};
	my $sql = qq{SELECT * FROM $config{status} };
	my $conjunction = "WHERE";
	my @params = ();
	if ($locid ne '')
		{
		$sql .= "$conjunction LOCID = ?";
		$conjunction = "AND";
		push @params,$locid;
		}
	if ($wsdate ne '')
		{
		$sql .= " $conjunction WSDATE = ?" ;
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
	$sql .= " ORDER BY LOCID,WSDATE,DUEDATE";
	&db_do($sql,@params);
	my $rowclass = "options";
	my $execname = '';
	my $duedate = '';
	my $wsdate = '';
	my $locid = '';
	my $separator = qq{<tr bgcolor="black" height="3"><TD colspan="$cspan"></TD></TR>\n};
	while (my $href = $th->fetchrow_hashref())
		{
		my $line = '';
		my @data = ();
		my $ix = 0;
		foreach my $col (@colnames)
			{
			my $align = ($ix > 4) ? qq{ALIGN="CENTER"} : '';
			my $val = $$href{$col};
			$val = '-' if (($col =~ /^Q/) && ($val eq ''));
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
			if ($col eq 'ISREADY')
				{
				$val = ($val eq '1') ? $tick : '&nbsp;';
				}
			if (grep(/^$col$/,qw{Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 Q10A}))
				{
				if ($val eq '1')
					{
					$val = '&radic;' ;
					}
				$val = '&nbsp;' if ($val eq '0');
				}
			if ($col eq 'FULLNAME')
				{
	#			$val = qq{<A HREF="/cgi-adm/pwikit_editp.pl?id=$$href{UID}&password=$$href{PWD}" target="_blank">$val</A>};
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

&add2body(qq{<TABLE border="0" cellpadding="3" cellspacing="0"><tr><TD valign="top">$nav</TD></tr><tr><TD valign="top">$main</TD></TR></TABLE>});
&add2body(qq{</FORM>});
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
&db_disc;
1;
