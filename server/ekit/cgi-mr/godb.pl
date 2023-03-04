#!/usr/bin/perl
## $Id: godb.pl,v 2.32 2013-01-21 21:22:10 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
#our $copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# go.pl/godb.pl - starts off a survey
#
#
use strict;
our (

$ResultVar,
$SelectVar,
$age_var,
$allow_leading_0,
$allow_restart,
$array_sep,
$autoselect,
$background,
$banner_top,
$bg_color,
$block_size,
$body,
$buttons,
$can_proceed_code,
$can_refuse,
$caption,
$charset,
$chmod,

$cmdline,
$cnt_var,
$code,
$code_age_never,
$code_age_refused,
$code_block,
$code_number_never,
$code_number_refused,
$copyright,
$custom_footer,
$d,
$data_dir,
$db_isib, 
$db_odbc,
$dbh,
$dbh2,
$dbt, 
$demo,
$dfile,
$dive_in,
$dk,
$do_body,
$do_cookies,
$do_copyright,
$do_footer,
$do_logo,
$dojo,
%extras,
$dying,
$editor,
$emit_url_vars,
$eval_recurse,
$execute,
$extension,
$external,
$fb_server, 
$fixed,
$focus_control,
$focus_off,
$for_client,
$force_expand,
$force_select,
$form,
$go,
$gotoq,
$grid_exclude,
$grid_include,
$grid_type,
$gz,
$hdr,
$http_method,
$i_pos,
$ib_db_file, 
$ib_db_password, 
$ib_db_user, 
$ib_master_db_file, 
$ib_master_db_password,
$ib_master_db_user, 
$if_not_never_or_refused,
$indent,
$inline_stylesheet,
$instr,
$ivor_interview,
$javascript,
$jquery,
$language,
$last_onset_only,
$left_word,
$lhs,
$limhi,
$limlo,
$list_sep,
$load_script,
$login_page,
$logo,
$mailname,
$mailto,
$margin_notes,
$mask_exclude,
$mask_include,
$mask_local,
$mask_name,
$mask_reset,
$mask_reverse,
$mask_update,
$max_multi_per_col,
$max_select,
$max_single_per_col,
$middle,
$middle_span,
$mike,
$missing_prompt,
$my_company,
$mysql_db_file, 
$mysql_db_password, 
$mysql_db_user, 
$na,
$nest,
$nextq,
$no_bq,
$no_click_triton,
$no_copy,
$no_methods,
$no_progress_bar,
$no_recency,
$no_uid,
$no_validation,
$none,
$none_text,
$numq,
$odbc_db_file, 
$odbc_db_password, 
$odbc_db_user, 
$old_written,
$one_at_a_time,
$onset_pulldown,
$opt_in,
$optional_written,
$other_text,
$others,
$pad,
$plain,
$prompt,
$q,
$q_label,
$q_no,
$qcnt,
$qlab,
$qt_droot,
$qt_root,
$qtype,
$random_options,
$random_scale,
$rank_grid,
$rank_order,
$read_only,
$realq,
$reason,
$relative_root,
$require_file,
$required,
$resultvar,
$return_name,
$return_url,
$revisit,
$rhs,
$right_word,
$saved,
$sbasc,
$sbdesc,
$scale,
# ???
$stat,
$style,
$script,
$selectvar,
$seqno,
$show_anchors,
$show_back_button,
$show_date,
$show_scale,
$show_scale_nos,
$show_time,
$simple_back_button,
$single,
$skip_found,
$specify_n,
$sscript,
$start_q_no,
$survey_id,
$survey_name,
$t,
$tabix,
$tabiy,
$table_cellspacing,
$table_width,
$tally,
$tdo,
$tdo1,
$tdo2,
$terminate_url,
$text_size,
$text_rows,
$textcolor,
$tfile,
$th,
$th2,
$thankyou_message,
$thankyou_url,
$theme,
$thh,
$thisq,
$tight,
$total,
$trh,
$triton_demo,
$triton_home,
$tro,
$tro2,
$true_flags,
$url_pid,
$us_date,
$use_q_labs,
$use_tnum,
$validation,
$var_prefix,
$varlabel,
$virgin,
$virtual_cgi_adm,
$virtual_cgi_bin,
$virtual_root,
$vhost,				# Can get rid of this in favor of a config item.
$window_title,
$written_cols,
$written_required,
$written_rows,
%adm_ipaddr,
%adm_major_sections,
%config,
%cookies,
%dcounts,
%dun,
%email_action,
%extra_js_methods,
%input,
%jumps,
%major_sections,
%new_tokens,
%qlab2ix,
%qlabels,
%reqfile_cache,
%resp,
%script_body,
%script_lang,
%section_start,
%tokens,
%ufields,
%updated_tokens,
%valid_tokens,
@a_show,
@can_proceed,
@def_instr,
@g_show,
@jump_index,
@major_sections,
@nlist,
@onset_data,
@options,
@qlab,
@pulldown,
@scale_words,
@scores,
@sections,
@sequences,
@setvalues,
@skips,
@subnames,
@vars,
);
# We do the parsing of the CGI request first to make sure that nothing messes with 
# our STDIN (where our precious POST requests come from)
#require 'TPerl/cgi-lib.pl';
use CGI qw(:cgi-lib);

undef %input;
&ReadParse(*input);
#
# Now we can require the other libraries, safe in the knowledge that they cannot hurt us
#
require 'TPerl/qt-libdb.pl';
require 'TPerl/qt-libval.pl';
# $dbt=1;
use CGI::Carp qw(fatalsToBrowser);

$form = 1;
#$t=1;
&resetVars;
#
# This is not 'my' because an external program wants to do the saving, 
#   then update it to tell us we have dealt with it
#
our $saved = 0;

&try_me;

sub HandleError
	{
	my ($DOING) = @_;				# String parameter explains what we were doing
	&debug("Fatal error: $DOING");
	print "<H1>Fatal Error</H1><BR>\n";
	print "Error: '$!' encountered while $DOING \n";
	&qt_Footer;
	exit;
	}

sub try_me
	{
#
# Initialise the response data
#
	$form = 1;
	%resp = ('start',time(),
			 'modified',time(),
			 'status', '3',
			 'seqno','',
			 'score','0',
			 );	
		print "Content-Type: text/html\n\n";
	my $when = localtime();
		$body = '';
		$hdr = '';
		$q_no = '';
	&debugtrc("----- Go $input{survey_id}, seq=$input{seqno}, q_no=$input{q_no}, q_labs=$input{q_labs}, q_label=$input{q_label}, tnum=$input{tnum} $when -----");
	&ReadCookies if ($do_cookies);
	$survey_id = $input{'survey_id'};
#
# A Missing survey_id is pretty much fatal at this point, so we shall dump out everything we have in the hope to spot something.
#
	if ($survey_id eq '')
		{
		my $dumpfile = "$qt_droot/log/input.dmp";
		open (DUMPFILE, ">>$dumpfile") || die ("Can't write to dump file: $dumpfile\n");
		my $when = localtime();
		print DUMPFILE "\n+++ Missing survey_id dump at $when\n";
		foreach my $key (keys (%ENV))
			{
			print DUMPFILE "ENV\{$key} = $ENV{$key}\n";
			}
		foreach my $key (keys (%input))
			{
			print DUMPFILE "\$input\{$key} = $input{$key}\n";
			}
		close DUMPFILE;
		$form = 0;
		$do_body  = 1;
		print "<HTML>\n";
		&add2hdr(&subst("<TITLE>Missing form data - please go back and try again </TITLE>"));
		&add2hdr("   <META NAME=\"Triton Information Technology\">");
		&add2hdr("   <META NAME=\"Author\" CONTENT=\"Mike King\">");
		&add2hdr("   <META NAME=\"Copyright\" CONTENT=\"Triton Information Technology 1995-2001\">");
		&add_stylesheet;
		&add2body(<<FATAL);
<font face="arial" color="blue">
<Table border="0" cellpadding="5" cellspacing="0" width="400px" style="background-color: white; color:black; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: normal; border-width:2px; border-color:darkslateblue; border-style:solid;">
<TR><TH style="background-color: darkslateblue; color:yellow; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: bold;">
<H2>Missing form data</H2>
<TR><TD><P>The data from the previous page seems to be missing. 
<P>Sometimes the web browser does not send the request properly - we do not know what causes it, but we do know that a refresh of the page usually fixes it.
<P> Click this button to go back to the previous page and try again: 
<form onsubmit="return false"><input type="button" value="Go Back" onclick="window.history.go(-1)"></form>
</font></table><hr>
<font size="-1" color="brown">The code was willing,<br>
It considered your request,<br>
But the chips were weak.<br>
</font>
Barry L. Brumitt

FATAL
		&qt_Footer;
		exit;
		}

	if ($survey_id eq 'MAP026') {
		&add2hdr(&subst("<TITLE>The post workshop notification has moved </TITLE>"));
		&add2hdr("   <META NAME=\"Triton Information Technology\">");
		&add2hdr("   <META NAME=\"Copyright\" CONTENT=\"Triton Information Technology 1995-2001\">");
		&add_stylesheet;

		&add2body("<H2>Post Workshop Survey Moved</H2>");
		&qt_Footer;

	exit;
	}

	$data_dir = "$qt_droot/$survey_id/web";
	my $finish = &input('finish');
	my $www_dir = $ENV{'DOCUMENT_ROOT'};
	$demo = (-f "$www_dir/microweb.exe");
	if ($demo)
		{
		&add2body("Auto creating data directory: $data_dir");
		&force_dir($data_dir);
		}
	$theme = 'default' if (!$theme);
	$extras{dojo}{enabled} = 0;			# Turn off Dojo by default here, we'll rely on the theme to turn it on?

#
# Update the hit counter for this ip address
#
	&qt_hitme($ENV{'REMOTE_ADDR'}, $input{'server_software'}, $survey_id);
#
# Locate which survey we are dealing with :-
#
	if ($survey_id eq '')
		{
		&qt_CannaHandle("No Survey ID specified");
		&qt_Footer;
		exit;
		}
	&get_config($survey_id);
	$extras{dojo}{enabled} = $dojo if ($dojo ne '');            # Allow an override in the survey file
	$extras{jquery}{enabled} = $jquery if ($jquery ne '');          # Allow an override in the survey file
	&qt_Header;

# Make sure we know how big numq is !
    my $filename = "$qt_root/$survey_id/config/qlabels.pl";
  	&my_require ($filename,1);
#
# Check that the data directory exists :-
#
	if (opendir(DIRH, "$data_dir") == 0)
		{
		&HandleError("opening data directory: $data_dir");
		}
	else
		{
		closedir(DIRH);
		}
	my $stat = 1;
	&debug("newversion=$input{'newversion'}");
	
#
# Pull in the client data (if any)
#
	if (&input('ufile') ne '')
		{
		my $ufile = "$qt_root/$survey_id/web/u$input{ufile}.pl";
		&debug("Checking for ufile: $ufile");
		if (-f $ufile)
            {
            my_require ($ufile,0);
            foreach my $key (keys(%ufields))
                    {
                    $key = lc($key);
                    $resp{"ext_$key"} = $ufields{$key};
                    }
            undef %ufields;
            }
		}
#
# Check to see if this interview exists already:
#
	if ($ivor_interview && ($input{seqno} eq '') && ($input{fam_no}.$input{id_no} ne ''))
		{
		my $records = 0;
		my $fam_pers = $input{fam_no}.$input{id_no};
#		&add2body("Checking for existing interview for $fam_pers<BR>\n");
		&db_conn;
		&db_get_ivor_status($survey_id,$fam_pers);
		my $stuff = join("<TH>",qw{Status ID Interviewer Seqno Created Modified Version Count});
		my $hdr = qq{<H2>Duplicate ID detected</H2>It seems that this ID number has been used already.<BR>Below is a list of the interview files I can find<BR><BR>};
		$hdr .= qq{<TABLE border="0" cellpadding="8" cellspacing="0" class="mytable">\n<TR class="heading"><TD>$stuff};
		my $nv = ($th->rows > 1) ? "&newversion=1" : "";
		while (my @row = $th->fetchrow_array())
			{
			if ($hdr ne '')
				{
				add2body($hdr);
				$hdr = '';
				}
			$row[3] = qq{<A HREF="/cgi-mr/godb.pl?survey_id=$survey_id&seqno=$row[3]&q_label=FIRST$nv">$row[3]</A>};
			my $stuff = join(qq{<TD align="center">},@row);
			my $options = ($records % 2) ? "options" : "options2";
			&add2body(qq{<TR class="$options"><TD>$stuff<BR>\n});
			$records++;
			}
		$th->finish;
		&add2body(qq{</table>});
		if ($records > 0)
			{
			$stat = 99;	# This means show them a special screen instead of continuing
			add2body(qq{<HR>Click on the sequence number of the one you would like to open, or go <BUTTON onclick="window.history.go(-1)">back</BUTTON> and modify the previous page<BR><BR>\n});
			$form =0;
			}
		}
	if ($stat != 99)
		{
		if (&input('newversion'))		# Are we creating a new version ?
			{
			&qt_new_version(&input('int_no'));
			&qt_save;
			}
#
# This hash provides the target status values for transitions that come in the 'action' parameter
#

use constant KSTATUS_NO_CHANGE => 0;
use constant KSTATUS_REFUSED => 1;
use constant KSTATUS_TERMINATED => 2;
use constant KSTATUS_IN_PROGRESS => 3;
use constant KSTATUS_DNF => 3;	#Did Not Finish
use constant KSTATUS_SELF_EDIT => 4;
use constant KSTATUS_REVIEW => 5;
use constant KSTATUS_RECONTACT => 6;
use constant KSTATUS_FINISHED => 7;
use constant KSTATUS_DELETED => 8;
# First parameter means the new state to go to, and the second parameter means open it (ie continue)
my %transition = (
					edit => 		[KSTATUS_NO_CHANGE,			1],		
					abort => 		[KSTATUS_REVIEW,            0],
					close => 		[KSTATUS_SELF_EDIT,         0],
					submit => 		[KSTATUS_REVIEW,            0],
					recontact =>	[KSTATUS_IN_PROGRESS,       1],
					reopen => 		[KSTATUS_IN_PROGRESS,       1],
					finish => 		[KSTATUS_FINISHED,          0],
					delete => 		[KSTATUS_DELETED,           0],
					undelete => 	[KSTATUS_REVIEW,            0],
					askrecontact => [KSTATUS_RECONTACT,         0],
					zaurusclose	=>	[KSTATUS_REFUSED,			0],
					refused	=>		[KSTATUS_REFUSED,			0],
					dnf	=>			[KSTATUS_IN_PROGRESS,		0],			#status --> Did Not Finish
					);
		if (&input('action'))		# Are we being told to do something ?
			{
			debug("action=".&input('action').", new status=".$transition{&input('action')}[0].", continue=".$transition{&input('action')}[1]);
			if ($transition{&input('action')}[0] != KSTATUS_NO_CHANGE)
				{
				$resp{status} = $transition{&input('action')}[0];
				&update_ivor_status($resp{status}) if ($ivor_interview);
				}
			$stat = $transition{&input('action')}[1];
			}
		elsif (&input('reopen'))		# Are we re-opening the sucker ?
			{
			$resp{'status'} = KSTATUS_IN_PROGRESS;
			}
		elsif (&input('newversion'))		# Are we creating a new version ?
			{
			&qt_new_version(&input('int_no'));
			&qt_save;
			$saved = 1;
			}
		elsif (&input('close'))		# Are we closing the sucker ?
			{
			$resp{'status'} = KSTATUS_REVIEW;
			$stat = 0;				# This tells us to clean up
			}
		if ($stat == 1)
			{
			&qt_validate if (&input('q_label') eq '');
			keep_external_data();		# Make sure we hang on to extras
#
# Output the question itself
#
			$stat = &qt_get_q;
			debug("new stat=$stat");
			&qt_Buttons if ($external eq '') && ($stat == 1);
			}
		if ($stat == 0)
			{
			if ((&input('action') eq '') && ($resp{status} <= KSTATUS_SELF_EDIT))
				{
				$resp{status} = ($finish eq '0') ? KSTATUS_IN_PROGRESS : KSTATUS_SELF_EDIT;
				}
			if ($resp{ext_int_no} ne '')
				{
				&update_ivor_status($resp{status}) if ($ivor_interview);
				}
			else
				{
				&update_token_status($resp{status});
				}
			&cleanup_tfiles if ($use_tnum);
			&qt_Thankyou;
			$form = 0;		# Don't need the form any more now
#
# Should we send them a thank you email ?
#
			my $template_file = "$relative_root${qt_root}/$survey_id/templates/thanksalot.txt";
			if (-f $template_file)
				{
				open (TEMPL,"<$template_file") || print("Error [$!]: while opening file: [$template_file]!\n");
				my $em = $resp{'email'};
				$em =~ s/[';"<>\/\\=\(\)\+\!\#\$%\^\&\*\~\`]//g;		# Make sure it's clean !!
				my $ts = time();
				my $mailfile = "$relative_root${qt_root}/$survey_id/mail/ta_${ts}_$em.txt";
				open (MAIL,">$mailfile") || &my_die("Error [$!]: while opening file: [$mailfile]!\n");
				while (<TEMPL>)
					{
					chomp;
				    s/\r//;
					while (/<%(\w+)%>/)
						{
						my $thing = lc($1);
						my $newthing = eval("\$$thing");
						$newthing = $resp{$thing} if ($newthing eq '');
						s /<%$thing%>/$newthing/g;
						}
					print MAIL "$_\n";
					}
				close(TEMPL);
				close(MAIL);
				}
#
# Should we send the manager a notification email ?			# Deprecate this in favour of %email_action (see below)
#
			$template_file = "$relative_root${qt_root}/$survey_id/templates/manager.txt";
			if (-f $template_file)
				{
				open (TEMPL,"<$template_file") || print("Error [$!]: while opening file: [$template_file]!\n");
				my $em = $resp{'mgr_email'};
				$em =~ s/[';"<>\/\\=\(\)\+\!\#\$%\^\&\*\~\`]//g;		# Make sure it's clean !!
				my $ts = time();
				my $mailfile = "$relative_root${qt_root}/$survey_id/mail/sv_${ts}_$em.txt";
				open (MAIL,">$mailfile") || &my_die("Error [$!]: while opening file: [$mailfile]!\n");
				while (<TEMPL>)
					{
					chomp;
				    s/\r//;
					while (/<%(\w+)%>/)
						{
						my $thing = lc($1);
						my $newthing = eval("\$$thing");
						$newthing = $resp{$thing} if ($newthing eq '');
						s /<%$thing%>/$newthing/g;
						}
					print MAIL "$_\n";
					}
				close(TEMPL);
				close(MAIL);
				}
	
#
# Do we need to generate a results document ?
#
			$template_file = "$relative_root${qt_root}/$survey_id/templates/doctemplate.rtf";
			if (-f $template_file)
				{
				if (&count_data() > 0)
					{
					&qt_save;
					$saved = 1;
					my $cmd = "perl -s substrtf2.pl -seq=$resp{'seqno'} $survey_id";
					$cmd = "perl ../scripts/mergertf.pl -seq=$resp{'seqno'} $survey_id" if (-f qq{../scripts/mergertf.pl});
					&debug("Creating document: $cmd");
					&add2body(qq{<SPAN onclick="document.all.item('debug').style.display = ''">+</SPAN>});
					&add2body(qq{<SPAN id="debug" style="display:none"> \nExecuting system cmd: $cmd });
					my $res = `$cmd`;
					&add2body("... $res </SPAN><BR>");
					}
				else
					{
					&add2body(qq{<SPAN onclick="document.all.item('debug').style.display = ''">+</SPAN>});
					&add2body(qq{<SPAN id="debug" style="display:none"> \nNo responses found in data file</SPAN><BR>});
					}
				}
#
# Do we need to post-process the results ?
#
			if ($script ne '')
				{
				&qt_save;		# Make sure the data is on disk b4 we activate the processing script !!
				$saved = 1;
				my $cmd = "perl -s $script -seq=$resp{'seqno'} $survey_id";
				&debug("Running script: $cmd");
				&add2body(qq{<SPAN onclick="document.all.item('debug_script').style.display = ''">+</SPAN>});
				&add2body(qq{<SPAN id="debug_script" style="display:none"> \nExecuting system cmd: $cmd });
				my $res = `$cmd`;
				&add2body("... $res </SPAN><BR>");
				}
			if ($sscript ne '')
				{
				&qt_save;		# Make sure the data is on disk b4 we activate the processing script !!
				$saved = 1;
				my $cmd = "perl $sscript -seq=$resp{'seqno'} $survey_id";
				&debug("Running script: $cmd");
				&add2body(qq{<SPAN onclick="document.all.item('debug_script').style.display = ''">+</SPAN>});
				&add2body(qq{<SPAN id="debug_script" style="display:none"> \nExecuting system cmd: $cmd });
				my $res = `$cmd`;
				&add2body("... $res </SPAN><BR>");
				}
#
# Send out email messages ?
#
			foreach my $msg (keys %email_action)
				{
				my $params = $email_action{$msg};
				my @parts = split(/$array_sep/,$params);
				&add2body("<!-- \nExecuting email action: ");
	#			&add2body(" \nExecuting email action: <BR>");
				&add2body("$msg = $params\n");
				if (get_data('','',$parts[0]) ne $parts[1])			# Does the condition match ?
					{
					&add2body("Condition does not match - not sent <BR>");
					}
				else
					{
					$template_file = "$relative_root${qt_root}/$survey_id/templates/$msg.txt";
					if (!(-f $template_file))
						{
						&add2body("Template file does not exist: [$template_file] \n");
						}
					else
						{
						my $cnt = 0;
						open (TEMPL,"<$template_file") || print("Error [$!]: while opening file: [$template_file]!\n");
						my $em = $parts[2];
						if ($em =~ /^(\w+)x(\d+)/)
							{
							my $two = $2 - 1;
							$em = "$1-$two";
							}
						$em =~ s/[';"<>\/\\=\(\)\+\!\#\$%\^\&\*\~\`]//g;		# Make sure it's clean !!
						$em = get_data('','',$em) if (get_data('','',$em) =~ /\@/);				# Looks like an email address ?
						&add2body("em=$em<BR>");
						my $ts = time();
						my $mailfile = "$relative_root${qt_root}/$survey_id/mail/${msg}_${ts}_$em.txt";
						&add2body("Creating email file: [$mailfile]<BR>");
						open (MAIL,">$mailfile") || &my_die("Error [$!]: while opening file: [$mailfile]!\n");
						while (<TEMPL>)
							{
							chomp;
						    s/\r//;
							while (/<%(\w+)%>/)
								{
								my $thing = $1;
								my $lcthing = lc($thing);
								if ($lcthing =~ /^(\w+)x(\d+)/)
									{
									my $two = $2 - 1;
									$lcthing = "$1-$two";
									}
								my $newthing = get_data('','',$lcthing);
								$newthing = $resp{$lcthing} if ($newthing eq '');
								$newthing = eval("\$$lcthing") if ($newthing eq '');
								&add2body("Replacing $thing with $newthing (lcthing=$lcthing)<BR>");
								s /<%$thing%>/$newthing/g;
								}
							print MAIL "$_\n";
							$cnt++;
							}
						close(TEMPL);
						close(MAIL);
						&add2body("Created email file: [$mailfile] ($cnt lines)<BR>");
						}
					}
				&add2body("... -->");
				}
	
			}
		if ($stat == -1)		# Used to look for a value of 2 - perhaps a left over from the Newton status value ?
			{
			$resp{status} = KSTATUS_TERMINATED;
			&update_token_status($resp{status});
			&qt_Terminate;
			}
#
# Save the data collected so far to file
#
		&qt_save if (!$saved);
#
# OK, we're done now, so output the standard footer :-
#
		&qt_Footer if ($stat != 0);		# Except when we have a status of 0, which means we are done, 
										# and things like the buttons at the bottom of the page are not applicable
		}
	1;
	}
1;
