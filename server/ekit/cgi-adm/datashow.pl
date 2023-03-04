#!/usr/bin/perl
# $Id: datashow.pl,v 1.1 2004-05-20 00:45:38 triton Exp $
#
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
our $opt_vars;
our @major_sections;
our %dcounts;
my $tick = qq{<IMG src="/admin/tick.gif">};

&ReadParse(*input);
print &PrintHeader;
print <<HEAD;
<HTML>
<HEAD>
HEAD
foreach my $key (keys (%input))
	{
	print "$key = $input{$key}<BR>\n" if (0);
	}
my $survey_id = $input{survey_id};
my $section = $input{section};
my $dfile = $input{file};
print <<HEAD;
<link rel="stylesheet" href="/admin/style.css">
</HEAD>
<BODY class="body">
HEAD

my $dir = "${qt_root}/${survey_id}/web";
my $file = "$dir/$dfile";
die "Error: file does not exist: $file\n" if (!-f $file);
my_require($file,1);
get_config($survey_id);
my @bits = split(/\//,$ENV{SCRIPT_NAME});
my $cgipath = $bits[1];
my $index = '';
#if (@major_sections)
#	{
	my $cnt = &count_data;
	push @major_sections,"EXT";
	push @major_sections,"MASK";
	push @major_sections,"VAR";
	$index = qq{IN\DEX: &nbsp;};
	for (my $i=0;$i<=$#major_sections;$i++)
		{
		my $sec = $major_sections[$i];
		$sec = qq{<A HREF="/$cgipath/datashow.pl?survey_id=$survey_id&section=$sec&file=$dfile"><B>$major_sections[$i]</B> <FONT size="-2">$dcounts{$sec}</FONT></A>};
		$major_sections[$i] = $sec;
		}
	$index .= join(' &nbsp; ',@major_sections);
	$index .= qq{<hr>};
#	}
my $qlabfile = "$qt_root/$survey_id/config/qlabels.pl";
&my_require ($qlabfile,1);
print <<STUFF;
	$index
<TABLE class="mytable" cellspacing="1" cellpadding="4">
<tr CLASS="heading">
	<TD colspan="3">fam_no=$resp{ext_fam_no} id=$resp{ext_id_no}, file=$dfile, version=$resp{ver}, modified=$resp{modified_s}:</TD>
</tr>
STUFF
my $csect = '';
our $prompt;
my $sofar = '';
for (my $n=1;$n<=$numq;$n++)
	{
	my @bits = split(/\s+/,$qlabels{$n});
	next if (grep(/$bits[1]/i,[qw{box begin end}]));
	next if (grep(/^$bits[0]$/i,[qw{7 8 20 27 28}]));
	if ($bits[1] =~ /^$section/i)
		{
		my $var = lc("vq$bits[1]");
		$resp{$var} =~ s/^"//;
		$resp{$var} =~ s/"$//;
		my $data = $resp{"_Q$bits[1]"};
		$data =~ s/$array_sep/,/g;
		if (($resp{$var} ne '') || ($data ne ''))
			{
			if ($csect ne substr("$bits[1]",0,1))
				{
					my $newc = substr("$bits[1]",0,1);
				print qq{<tr class="heading"><TD colspan="3" ALIGN="CENTER" ><FONT size="+1">\[_______________<U> S E C T I O N  &nbsp; $newc </U>_______________]</FONT></tr>};
				print qq{<tr class="heading"><TD>QUESTION<TD>NUMERIC DATA<TD>TEXT VERSION OF DATA</tr>};
				}
#			print qq{<tr$bits[1]=$resp{$var}<BR>};
			my $stuff = '';
			$stuff .= qq{RF } if ($resp{"rf_Q$bits[1]"} ne '');
			$stuff .= qq{DK } if ($resp{"dk_Q$bits[1]"} ne '');
			if ($resp{"mn_Q$bits[1]"} ne '')
				{
				my $mn = $resp{"mn_Q$bits[1]"};
				$mn =~ s/\\n/<BR>/g;
				$stuff .= qq{[$mn]};
				}
			$stuff = qq{<BR><font size="-1" color="red">$stuff</FONT>} if ($stuff ne '');
			my $qfile = "$qt_root/$survey_id/config/q$n.pl";
			&my_require ($qfile,1);
			$prompt =~ s/^.*?\.\s//g;
			$prompt =~ s/<.*?>//g;
			$prompt = substr($prompt,0,40);
			print qq{<tr class="options"><TD><B>$bits[1].</B> $prompt<TD>$data$stuff<TD>$resp{$var}</tr>};
			$csect = substr("$bits[1]",0,1);
			}		
		}
	}

if ($section eq 'EXT')
	{
	my $x = "X";
	print qq{<tr class="heading"><TD colspan="3" ALIGN="CENTER" ><FONT size="+1">\[_______________<U> E $x T E R N A L  &nbsp;   D A T A  </U>_______________]</FONT></tr>};
	print qq{<tr class="heading"><TD>QUESTION<TD colspan="2">NUMERIC DATA</tr>};
	foreach my $ext (sort grep(/^ext_/,keys %resp))
		{
		$resp{$ext} =~ s/^"//;
		$resp{$ext} =~ s/"$//;
		my $data = $resp{$ext};
		$data =~ s/$array_sep/,/g;
		if ($data ne '')
			{
			print qq{<tr class="options"><TD>$ext<TD colspan="2">$data</tr>};
			}		
		}
	}

if ($section eq 'VAR')
	{
	print qq{<tr class="heading"><TD colspan="3" ALIGN="CENTER" ><FONT size="+1">\[_______________<U> I N T E R N A L  &nbsp;  V A R I A B L E S  </U>_______________]</FONT></tr>};
	print qq{<tr class="heading"><TD>QUESTION<TD colspan="2">DATA</tr>};
	foreach my $ext (sort grep(/^v/,keys %resp))
		{
		next if ($ext =~ /^vscore/i);
		$resp{$ext} =~ s/^"//;
		$resp{$ext} =~ s/"$//;
		my $data = $resp{$ext};
		$data =~ s/$array_sep/,/g;
		if ($data ne '')
			{
			print qq{<tr class="options"><TD>$ext<TD colspan=2>$data</tr>};
			}		
		}
	}

if ($section eq 'MASK')
	{
	my $m = "M"; # Ultra-edit glitch with language keywords
	print qq{<tr class="heading"><TD colspan="3" ALIGN="CENTER" ><FONT size="+1">\[_______________<U> I N T E R N A L  &nbsp;  $m A S K S  </U>_______________]</FONT></tr>};
	print qq{<tr class="heading"><TD>QUESTION<TD colspan="2">MASK DATA</tr>};
	foreach my $ext (sort grep(/^mask_/,keys %resp))
		{
		$resp{$ext} =~ s/^"//;
		$resp{$ext} =~ s/"$//;
		my $data = $resp{$ext};
		my @data = split($array_sep,$resp{$ext});
		my $ext_t = $ext;
		$ext_t =~ s/mask_/maskt_/;
		my @text = split($array_sep,$resp{$ext_t});
		print qq{<tr class="options"><TD>$ext<TD colspan="2"><TABLE BORDER=0>};
		foreach (my $i=0;$i<=$#data;$i++)
			{
			my $val = ($data[$i]) ? $tick : '&nbsp;x';
			print qq{<TR><TD>$val<TD>$text[$i]</tr>};
			}
		print "</TABLE></TR>\n";
		}
	}
print <<EOF;
	</TABLE>
	<HR>
	</BODY>
	</HTML>
EOF
1;

