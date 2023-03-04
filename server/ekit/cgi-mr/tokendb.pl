#!/usr/bin/perl
## $Id: tokendb.pl,v 2.12 2009-02-10 10:16:49 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
#our $copyright = "Copyright 1996 Triton Survey Systems, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# go.pl - starts off a survey
#
#
our ($survey_id,%resp,%input,$do_cookies,$open_survey);
our ($form,$data_dir);
our ($dfile,$ufile,$qt_root,%ufields,$use_q_labs,%qlabels);
our ($seqno,%dun,$prompt,$this_answer,$q_no,$q_label,$autoselect,%jumps,$qtype,$mike,$qlab);
our ($virgin,$dive_in,$plain,$numq,$allow_restart,$start_q_no,$auto_create,$allow_leading_0);
our ($no_uid);
#use strict;

# We do the parsing of the CGI request first to make sure that nothing messes with 
# our STDIN (where our precious POST requests come from)
require 'TPerl/cgi-lib.pl';
undef %input;
&ReadParse(*input);
print "Content-Type: text/html\n\n";
#
# Now we can require the other libraries, safe in the knowledge that they cannot hurt us
#
require 'TPerl/qt-libdb.pl';

use CGI::Carp qw(fatalsToBrowser);

$form = 1;
#$dbt = 1;
my $revisit = 0;
my $status;

&resetVars;
#
# Initialise the response data
#
	%resp = ('start',time(),
			 'modified',time(),
			 'status', '3',
			 'seqno','',
			 'score','0',
			 );	

sub HandleError
	{
	my ($DOING) = @_;				# String parameter explains what we were doing
	&debug("Fatal error: $DOING");
	print "<H1>Fatal Error</H1><BR>\n";
	print "Error: '$!' encountered while $DOING \n";
	&qt_Footer;
	exit;
	}
#
# Start of main code 
#
&db_conn;
#$survey_id = $input{'survey_id'};
$survey_id = &input('survey_id');
$resp{'survey_id'} = $survey_id;
my $token = uc(&input('token'));
$token =~ s/\s+//g;
$resp{'token'} = $token;

&get_config($survey_id);
my $bad = '';
my $id;
my $redirect;
if (($token eq '') && (!$open_survey))
	{
	$bad = 'Missing ID';
	$redirect = "badid.htm";
	}
else
	{
#
# Look to see if the token is present
#
	$id = &input('id');
	$id = '' unless $id;
	$resp{'id'} = $id;
#	$token = "$input{'id'}|$input{'token'}" if ($input{'id'} ne '');
#	&get_token_status(1);
	$data_dir = "$qt_root/$survey_id/web";
	$redirect = "badid.htm";
    my $validator = "$qt_root/$survey_id/config/validate_token.pl";
	if (-f $validator)
    	{
	  	my_require ($validator,0);
		$token = &validate_token($token);
		}
	if ($bad eq '')
		{
		if (($token eq '') && ($open_survey))
			{
# Nothing to do as yet for an open survey with no password supplied
			$status = 3;
			}
		else
			{
			$status = &db_get_user_status($survey_id,$id,$token,$no_uid);
			$redirect = 'main.htm';
			}
		}
	if ($status eq '')
		{
		if ($auto_create)
			{
#			&db_set_status($survey_id,$id,$token,'3',$seqno,$no_uid);
			}
		else
			{
			if ($status eq '')
				{
				$redirect = 'badid.htm';
				$bad = "ID is not on file: $token";
				}
			else
				{
#				&db_set_status($survey_id,$id,$token,'3',$seqno,$no_uid);
				}
			}
		}
	elsif (($status eq '4') || ($status eq '2') )
		{
		$redirect = 'finished.htm';
		$bad = "Survey has been completed already";
		if ($allow_restart)
			{
			$seqno = &db_get_user_seq($survey_id,$id,$token,$no_uid);
			$redirect = "../cgi-mr/godb.pl?survey_id=$survey_id&seqno=$seqno&q_label=first";
			$bad = 'Re-opening completed form';
			$input{'seqno'} = $seqno;	# Fudge the input variable to fool qt_hitme
			$bad = '';
			$revisit = 1;
			}
		}
	else		# Any other status value comes here
		{
		$seqno = &db_get_user_seq($survey_id,$id,$token,$no_uid);
		if (($seqno ne '') && ($seqno != 0) && ($allow_restart))
			{
			$input{'seqno'} = $seqno;	# Fudge the input variable to fool qt_hitme
			$revisit = 1;
			}
		}
	}
&debug("bad=$bad");
if ($bad ne '')
	{
	$bad = '?err='.$bad;
	$bad =~ s/[ \t]/_/g;
	print "<HTML>\n";
	&add2body("<META HTTP-EQUIV=\"Refresh\" CONTENT=\"0; URL=/$resp{'survey_id'}/$redirect$bad\">");
	&add2body(<<MSG);
Page moved permanently. The browser will automatically re-direct you to the first page of the
survey.
If nothing happens, please click <A HREF="/$resp{'survey_id'}/$redirect$bad">here</A>
MSG
#
# OK, we're done now, so output the standard footer :-
#
	&qt_Footer;
	}
else	
	{				
#
# Everything looks good...
#
	&debug("Token OK, revisit=$revisit, seq=$seqno proceeding...");
	$start_q_no = 1;
	$q_no = 1;
	$plain = 1;
	$virgin = 1;
	&qt_hitme($ENV{'REMOTE_ADDR'}, $input{'server_software'}, $survey_id);
	if ($revisit)
		{
		&debug("Revisit - restoring...");
		print "<Html>\n";
		&add2hdr("<link rel=\"stylesheet\" href=\"/$survey_id/style.css\">");
		$this_answer = "D$seqno.pl";	
		&my_require ("$data_dir/$this_answer",0);		# Get the old data
#
# This is a bit of defensive code, in case the dfile was not there yet, or somehow corrupt
#
		$resp{seqno} = $seqno if ($resp{seqno} eq '');
		$resp{survey_id} = $survey_id if ($resp{survey_id} eq '');
		$resp{'id'} = $id if ($resp{id} eq '');
		$resp{'token'} = $token if ($resp{token} eq '');
#
# Find the last question answered
#
		$virgin = 0;
		$q_no = 0;
		if ($use_q_labs)
			{
		    my $filename = "$qt_root/$resp{'survey_id'}/config/qlabels.pl";
		  	&my_require ($filename,1);
			for (my $qq=1;$qq<=$numq;$qq++)
				{
				my @bits = split(/\s+/,$qlabels{$qq});
				$bits[1] =~ s/^q//i;
				$q_no = $qq if ($resp{"_Q$bits[1]"} ne '');
				}
			debug("q_no=$q_no");
			}
		else
			{
			foreach my $x (keys %resp)
				{
				if ($x =~ /^(\d+)/)
					{
					$q_no = $1 if ($1 > $q_no);
					}
				}
			$q_no-- if ($q_no > 0);					# Go one previous
			}
		if (($q_no == 0) || $dive_in)			# $dive_in is a parameter that can be set in config2.pl
			{
			&qt_token_header;
			&keep_external_data;
			$dfile = "D$resp{seqno}.pl";	
			&qt_save;
			if (&qt_get_q)
				{
				&qt_Buttons;
				}
			&qt_Footer;
			}
		else
			{				# Give them the choice...
            my $filename = "$qt_root/$resp{'survey_id'}/config/q$q_no.pl";
		  	&my_require ($filename,1);
			&add2body(<<WHERE);
<H2>Welcome back !</H2>
We see that you may not have completed the questionnaire on your last visit. Where would you like to start from ? ...<BR><BR>
WHERE
			if ($token ne '9999')
				{
#				&add2body("<BLOCKQUOTE>");
				my $k;
				my $lastq = $q_no;
				my $qcnt = 0;
			&add2body(<<WHERE);
<BLOCKQUOTE>
<TABLE BORDER="0" cellspacing="0" cellpadding="3" class="mytable">
<tr class="heading"><td colspan="3">Start again</td></tr>
<tr class="options"><td colspan="3"><A HREF="/cgi-mr/godb.pl?survey_id=$survey_id&seqno=$seqno&q_label=FIRST">
&bull; From the beginning</A></td></tr>
<tr class="heading"><td colspan="3">Or from question:</td></tr>
WHERE
				if (!(%jumps))  
					{
#					&add2body(qq{<TR class="options"><TD colspan=3><FONT COLOR="RED">(Error: No jump points specified in this survey)</FONT><BR>});
					my $link = qq{<A HREF="/cgi-mr/godb.pl?survey_id=$survey_id&seqno=$seqno&q_label=LAST">};
					&add2body(qq{<TR class="options"><TD colspan=3>$link&bull; Where I left off.</A>});
					}
				else
					{
#					for ($q_no=1;$q_no<=$lastq+1;$q_no++)
					for ($q_no=1;$q_no<=$numq;$q_no++)
						{
                        my $filename = "$qt_root/$resp{'survey_id'}/config/q$q_no.pl";
					  	&my_require ($filename,1);
#					  	next if (($qtype == QTYPE_EVAL) || ($qtype == QTYPE_CODE) || ($qtype == QTYPE_PERL_CODE));
					  	if ($autoselect ne '')
					  		{
					  		undef $autoselect;
					  		next;
					  		}
					  	my $k = $q_no - 1;
					  	my $portion = $prompt;
					  	my $lab = '';
					  	$portion =~ s/<br>.*//i;
#
# It appears confusing if we substitute without data, as things may not be set yet, or may be set incorrectly
#
#					  	$portion = subst($portion);		
					  	if (length($portion) > 90)
					  		{
					  		$portion = substr($portion,0,90);
					  		$portion =~ s/\w+$//;
					  		$portion .= "...";
					  		}
					  	if ($portion =~ /^</)
					  		{
					  		$lab = $q_label;
					  		}
					  	elsif ($portion =~ /^(\w+)\.\s*(.*)/)
					  		{
					  		$lab = $1;
					  		$portion = $2;
					  		$lab =~ s/\.$//g;
					  		}
					  	elsif ($portion =~ /^(\S+)\s+(.*)/)
					  		{
					  		$lab = $1;
					  		$portion = $2;
					  		$lab =~ s/\.$//g;
					  		}
					  	$portion =~ s/<\/*SPAN//i;
					  	$portion =~ s/<\/*FONT//i;
					  	$portion =~ s/class=["']*instruction["']*//i;
					  	$portion =~ s/>//i;
#					  	next if (($jumps{uc($q_label)} == 0) && ($lastq != $q_no));
					  	my $link;
						if (($qtype == QTYPE_EVAL) || ($qtype == QTYPE_CODE) || ($qtype == QTYPE_PERL_CODE))
							{
							next;# if (!$mike);
							$link = '';
							}
						else
							{
							$link = qq{<A HREF="/cgi-mr/godb.pl?survey_id=$survey_id&seqno=$seqno&q_label=$q_label">};
							}
						my $no = '';
						$no = "<FONT size=\"-2\">$q_no</FONT>" if ($mike);
						my $style = "options";
						my $stuff;
						if ($lab =~ /^BEGIN(\w)$/i)
							{
							$style = "heading";
							$stuff = "<TD colspan=3><B>SECTION $1</tr>";
							$stuff .= qq{<TR class="heading"><TD>$no<TD><B> $link $q_label</A><TD> $portion};
							}
						elsif (get_data('','',$qlab) ne '')
							{
							$stuff = qq{<TH >&radic;</font><TH>&nbsp;&nbsp;$q_label<TD><B>$link$portion<BR></A>};
							}
						else
							{
							$stuff = "<TD>&nbsp;<TD>&nbsp;&nbsp;$q_label<TD>$link$portion</A><BR>";
							}
						&add2body(<<WHERE);		
<tr class="$style">
$stuff
</td></tr>
WHERE
						$qcnt++;
#						&add2body("<BR>") if (($qcnt % 10 ) == 0);
						}
					}
				&add2body("</TABLE>");
				&add2body(<<WHERE);
WHERE
				$q_no = $lastq;
				}
			else
				{
				&add2body(<<WHERE);
<A HREF="/cgi-mr/godb.pl?survey_id=$survey_id&seqno=$seqno&q_label=$q_label">
Resume where I left off (Question $prompt)</A><BR>

WHERE
				}
			&add2body(<<WHERE);
</BLOCKQUOTE>
<!--The tick marks show places where you have filled in information already-->
<BR><hr>
<!--
<A HREF="/cgi-mr/godb.pl?survey_id=$survey_id&q_no=0">
Start again from the beginning (FORGET MY PREVIOUS ANSWERS)</A><BR><BR>-->

WHERE
			&keep_external_data;
			$dfile = "D$resp{seqno}.pl";	
			&qt_save;
			&qt_Footer;
			}
		}
	else
		{
		&db_set_status($survey_id,$id,$token,'3',$seqno,$no_uid) if ($token ne '');
		print "Set-Cookie: $survey_id=$seqno;\n" if ($do_cookies);
		print "<Html>\n";
		$resp{seqno} = $seqno;	# Allocate a new sequence no
		$this_answer = "D$resp{seqno}.pl";	
#
# Pull in the client data (if any)
#
		$ufile = "$qt_root/$survey_id/web/u$token.pl";
		if (-f $ufile)
			{
			my_require ($ufile,0);
			foreach my $key (keys(%ufields))
				{
				$key = lc($key);
				$resp{$key} = $ufields{$key};
				}
			undef %ufields;
			}
		&keep_external_data;
		$dfile = "D$resp{seqno}.pl";	
		&qt_save;
		&qt_token_header;
		if (&qt_get_q)
			{
			&qt_Buttons;
			}
		&qt_Footer;
		}
	}
1;
