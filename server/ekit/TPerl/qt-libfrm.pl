#!/usr/bin/perl
## $Id: qt-libfrm.pl,v 2.6 2012-08-05 11:10:15 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl frame simulator library for QT project
#
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Provide a simulated frames output
#

#----------------------------------------------------------------------------
# # # Experimental stuff to simulate frames
#----------------------------------------------------------------------------
sub dump_header
	{
	&subtrace('dump_header');
	$header = "<head>\n";	
	$header .= qq{<meta http-equiv="Content-Type" content="text/html; charset=$charset">\n} if ($charset ne '');
	$header .= qq{
$hdr
	<link rel="stylesheet" href="/themes/ekit/style.css">
</head>
};
	if ($do_body)
		{
		$header .= qq{<BODY style="margin:0;"};
		if ($load_script ne '')
			{
			if ($focus_control ne '')
				{
				$header .= qq{ onload="document.q.$focus_control.focus(); $load_script()"};
				}
			else
				{
				$header .= qq{ onload="$load_script()"};
				}
			}
		elsif ($focus_control ne '')
			{
			$header .= qq{ onload="document.q.$focus_control.focus();"};
			}
		$header .= qq{  class="body">\n};
		}	
	&dump_scripts(1);
	&endsub;
	$header;
	}
	
sub dump_body
	{
	&subtrace('dump_body');
	my $html = shift;
	my $bhtml = '';
	
#	print $html;
	$html .= "<HR>$copyright<BR>\n" if ($do_copyright);
	$html .= "</BODY>\n" if (!$simulate_frames);
	&endsub;
	$html;
	}
	
sub dump_footer
	{
	&subtrace('dump_footer');
	print "</BODY></HTML>\n";
	&endsub;
	}

sub getdblist
	{
	my %tables = (
					admin =>	{
								tablename => 'PWI_ADMIN',
								order => 'ADMIN_NAME',
								fields => 'ADMIN_KV,ADMIN_NAME',
								desc => 'Administrator name',
								},
					exec =>		{
								tablename => 'PWI_EXEC',
								order => 'EXEC_NAME',
								fields => 'EXEC_KV,EXEC_NAME',
								desc => 'Executive consultant',
								},
					workshop =>	{
								tablename => 'PWI_WORKSHOP',
								where => 'WHERE WS_STATUSREF < 3',
								order => 'WS_ID',
								fields => 'WS_KV,WS_TITLE,WS_DUEDATE',
								desc => 'Workshop',
								},
					batchno =>	{
								tablename => 'PWI_BATCH',
								where => 'WHERE BAT_STATUS < 3',
								order => 'BAT_NO',
								fields => 'BAT_KV,BAT_NAME',
								desc => 'Batch no',
								},
					);
	my $ting = shift;
	$ting =~ s/s$//;
	my $stuff = '';#"$ting LIST:<BR>";
	my $js = $jse = '';
	my @duedates = ("''");
	if ($ting eq 'workshop')
		{
		$jse = qq{onchange="document.q.duedate.value=duedates[document.q.$ting.selectedIndex]"};
		}
	$stuff .= qq{$js<SELECT name="$ting" title="$tables{$ting}{desc}" $jse>\n\t<option value="0">--SELECT --></option>\n};
	&db_conn if (!$dbh);
	my $sql = "SELECT $tables{$ting}{fields} FROM $tables{$ting}{tablename} $tables{$ting}{where} ORDER BY $tables{$ting}{order}";
	&db_do($sql);
	while (my @row = $th->fetchrow_array())
		{
#		$stuff .= "$row[0] $row[1]<BR>\n";
		$stuff .= qq{<option  value="$row[0]">$row[1]</option>\n};
		push @duedates,qq{'$row[2]'} if ($ting eq 'workshop');
		}
	$th->finish;
	$stuff .= qq{</select>\n};
	if ($ting eq 'workshop')
		{
		my $arr = "var duedates = new Array(".join(',',@duedates).");";
		$stuff .= qq{<SCRIPT LANGUAGE="JavaScript">\n$arr\n</SCRIPT>};
		}
	$stuff;
	}	
	
sub dump_html
	{
	&subtrace('dump_html');
	$header = dump_header;
	$body =	&dump_body($body);

$banner = qq{<IMG SRC="banner.gif" alt="banner goes across here.......">};

my $left = '';
my $lcrole = lc($rolename);
my $fn = qq{$qt_root/$config{case}/html/admin/left$lcrole.tt};
open (TT,"<$fn") || print "Cannot open template file: $fn\n";
while (<TT>)
	{
	chomp;
	s/\r//;
	my $loopcnt = 0;
	while (/<%(\w+)%>/)
		{
		my $thing = $1;
		my $newthing = '';
		$newthing = $ufields{$thing};
		s/<%${thing}%>/$newthing/gi;
		last if ($loopcnt++ > 10);
		}
	$left .= "$_\n";
	}
close TT;

if ($pagename ne '')
	{
	$body = '';
	my $fn = qq{$qt_root/$config{case}/html/admin/$pagename.tt};
	open (TT,"<$fn") || print "Cannot open template file: $fn\n";
	while (<TT>)
		{
		chomp;
		s/\r//;
		my $loopcnt = 0;
		debug("Line was: $_");
		while (/<%(\w+)%>/)
			{
			my $thing = $1;
			my $newthing = '';
			my $ting = lc($thing);
			if (grep(/$ting/,(qw{execs admins workshops batchno})))
				{
				$newthing = getdblist($ting);
				}
			else	
				{
				$newthing = $ufields{$ting};
				&debug("($pagename) Replacing <$thing> ($ting) with [$newthing]");
				}
			s/<%$thing%>/$newthing/ig;
			last if ($loopcnt++ > 50);		# Maximum fields per line - prevents a hard loop condition
			}
		debug("Line=$_");
		$body .= "$_\n";
		}
	close TT;
	}

my %things = (
			plist 		=> {width => "950px", title => "List of Participants"},
			mli 		=> {width => "700px", title => "MLI Assembly"},
			forms 		=> {width => "700px", title => "List of Forms"},
			formsself	=> {width => "700px", title => "List of Forms"},
			formsboss	=> {width => "700px", title => "List of Forms"},
			formspeer	=> {width => "700px", title => "Key Personnel Questionnaire"},
			formsadmin 	=> {width => "800px", title => "List of Forms (administrator)"},
			clickthru 	=> {width => "600px", title => "Welcome to MAP"},
			);
my $item = "plist";
if ($ENV{SCRIPT_NAME} !~ /listall/)
	{
	$item = ($input{admin}) ? "formsadmin" : "forms";
	}	
$item = "mli" if ($ENV{SCRIPT_NAME} =~ /mli/);
$item = "clickthru" if ($ENV{SCRIPT_NAME} =~ /clickthru/);
$resp{title} = $things{$item}->{title};
$resp{title} = $things{$item.$lcrole}->{title} if $things{$item.$lcrole}->{title};
my $twidth = $things{$item}->{width};
my %titles = (
				contact => 'Contact us',
				assist => 'Contact us',
				schedule => 'Workshop Schedule',
				copies => 'Completed / Blank Forms',
				explain => 'Instructions',
				clickthru => 'Welcome',
				);
if ($ENV{PATH_INFO} =~ /\w+_(\w+)/)
	{
	$resp{title} = $titles{$1} if ($titles{$1});	
	}

my $banner = &subst($config{banner});
print <<EOF;
$header
<TABLE border=0 cellpadding=0 cellspacing=0 width="$twidth">
<TR >
	<TD colspan=4  height="120px">$banner</TD></TR>
<TR><TD valign=top width=5px><TD valign=top width=120px>$left</TD><TD valign=top width=10px>&nbsp;</TD><TD valign=top>$body</TD></TR>
</table>
EOF


print <<EOF;
</body>
</html>
EOF
#	&dump_header;
#	$body =	&dump_body($body);
#	if ($reason ne '')
#		{
#		print "<H2>Error: $reason</H2>";
#		}
	&dump_footer;
	&endsub;
	}
#
# Replacement for standard qt-libdb function
#
sub qt_Footer
	{
	&subtrace('qt_Footer');
	&debug("showing Q$q_no");

	if ($do_footer)
		{
		if ($custom_footer ne '')
			{
			&add2body($custom_footer);
			}
		else
			{
			&add2body(<<XX);
<HR><small><IMG SRC="$virtual_root/pix/logosmall.gif" ALIGN="MIDDLE">
\&copy; Triton Information Technology 1995-2012. For more information,
please contact <A HREF="mailto:$mailto\?subject=$survey_id" TABINDEX="-1">$mailname</A></small><BR>
XX
			}
		}
	if ($form)
		{
		&add2body(qq{<INPUT NAME="survey_id" TYPE="hidden" VALUE="$resp{'survey_id'}">});
		&add2body(qq{<INPUT NAME="seqno" TYPE="hidden" VALUE="$resp{'seqno'}">});
		my $sq_no = ($realq eq '') ? $start_q_no : $realq;
		my $qq = ($one_at_a_time) ? $q_no : "${sq_no}.$q_no";
#		&add2body("<INPUT NAME="q_no" TYPE="hidden" VALUE="$qq">");
		&add2body(qq{<INPUT NAME="q_no" TYPE="hidden" VALUE="$qq">});
		&add2body(qq{<INPUT NAME="jump_to" TYPE="hidden" VALUE="">});
		if ($mike)
			{
			&add2body(qq{<FONT size="-2" color="white">$survey_id $resp{'seqno'} &nbsp; $qq</FONT>});
			}
		&add2body("</FORM>");
		}
	if (($external ne '') && !$revisit)
		{
		&dump_external($external);
		print qq{<INPUT NAME="jump_to" TYPE="hidden" VALUE="">};
		print "</FORM>\n</BODY>\n";
		&dump_footer;
		}
	else
		{
		&dump_html;
		}
	&endsub;
	}
1;
