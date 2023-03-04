#!/usr/bin/perl
## $Id: qt-libdb.pl,v 2.128 2012-11-29 18:54:07 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
# TAKEN THIS OUT FOR EXPEDIENCE, AS Storable.pm was not standard kit in the version of ActiveState Perl we are using
#
####use Storable qw(store retrieve freeze thaw dclone);
#
use Compress::Zlib;
use HTML::Entities;
use File::Slurp;
use Template;
use JSON::Parse 'json_to_perl';
use Data::Dumper;

my $redirect;

$copyright = qq{&copy; Copyright 1995... Triton Technology, all rights reserved};
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
require "TPerl/ntstuff.pl";
require "TPerl/qt-db.pl";
require "TPerl/qt-libemit.pl";
#
# ---- Configuration parameters ----
#
# File system locations
#
	&get_root;								# Read directory informatika
	$go = 'godb';							# THIS IS THE DATABASE VERSION !!!
#
# URL's
#
	$do_cookies = 0;
	$virtual_root = "/triton";				# relative to www...
	$virtual_cgi_bin = "/cgi-mr/" if ($virtual_cgi_bin eq '');			# cgi-bin directory
	$virtual_cgi_adm = "/cgi-adm/" if ($virtual_cgi_adm eq '');			# cgi-adm directory (for admin)
	$thankyou_url = "thankyou.htm";			# 
	$triton_home = '/triton/index.html';	# used if no $thankyou_url defined
	$triton_demo = '/triton/demos.html';	#  -- " " --
	$mailto = 'info@market-research.com';
	$mailname = 'info@market-research.com';
	$my_company = 'Triton Information Technology';
	$array_sep = '===';
	$text_size = 30;						# Default text field width
#	$do_body = 0;
#
	$one_at_a_time = 1;						# Ask only one question at a time
#	$one_at_a_time = 0;						# Ask only one question at a time
	$block_size = 999;						# Applies if above is zero,
#	$block_size = 5;						# Applies if above is zero,
											# max no of questions per page
	$do_footer = 0;
	$do_logo = 0;
	$do_copyright = 0;
	$bg_color = '#EEEEEE';
	$textcolor = '#000000';
	$background = '';				
	$return_url = 'http://www.triton-tech.com/';
	$return_name = "$my_company web site";
	$max_multi_per_col = 10;
	$max_single_per_col = 10;
	$html_alignment = "";		# Global alignment for HTML display (left justified is default). Can change to 'right-justified' for Arabic + others
	$css_alignment = "";		# css alignment fix for right justified languages - progress bar table
	$http_method = "POST";
#
# ---- End of Configurable items ----
#

#
# ---- CONSTANTS -----
#
	$skip_found = 0;

use constant QTYPE_NUMBER			=> 1;
use constant QTYPE_MULTI			=> 2;
use constant QTYPE_ONE_ONLY			=> 3;
use constant QTYPE_YESNO			=> 4;
use constant QTYPE_WRITTEN			=> 5;
use constant QTYPE_PERCENT			=> 6;
use constant QTYPE_INSTRUCT			=> 7;
use constant QTYPE_EVAL				=> 8;
use constant QTYPE_DOLLAR			=> 9;
use constant QTYPE_RATING			=> 10;
use constant QTYPE_UNKNOWN			=> 11;
use constant QTYPE_FIRSTM			=> 12;
use constant QTYPE_COMPARE			=> 13;
use constant QTYPE_GRID				=> 14;		# Regular grid
use constant QTYPE_OPENS			=> 15;
use constant QTYPE_DATE				=> 16;
use constant QTYPE_YESNOWHICH		=> 17;
use constant QTYPE_WEIGHT			=> 18;
use constant QTYPE_AGEONSET			=> 19;
use constant QTYPE_CODE				=> 20;
use constant QTYPE_TALLY			=> 21;
use constant QTYPE_CLUSTER			=> 22;
use constant QTYPE_TALLY_MULTI		=> 23;
use constant QTYPE_GRID_TEXT		=> 24;
use constant QTYPE_GRID_MULTI		=> 25;
use constant QTYPE_GRID_PULLDOWN	=> 26;
use constant QTYPE_PERL_CODE		=> 27;
use constant QTYPE_REPEATER			=> 28;
use constant QTYPE_GRID_NUMBER		=> 29;
use constant QTYPE_SLIDER			=> 30;
use constant QTYPE_RANK				=> 31;
	
#
#
# Default instruction strings...
#
	require 'TPerl/strings-en.pl';				# English (default)
	&my_require ('TPerl/strings-en-local.pl',0);	# Pull in locally defined strings (if any);


#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# Subroutines start here :-
#
#------------------------------------------------------------------------------
# Generate funky random password:
#------------------------------------------------------------------------------
sub pw_generate 
	{
    my(@passset, $rnd_passwd, $randum_num);
    my $i;
    
    # Since '1' is like 'l' and '0' is like 'O', don't generate passwords with them.
    # Also I,J,L,O,Q,V
    # This will just confuse people using ugly fonts.
    #
    my @passset = ('A'..'H','K','M','N','P','R'..'U','X'..'Z');#, 'A'..'N', 'P'..'Z', '2'..'9');
    my $rnd_passwd = "";
    my $i = 0;
    my $lastwun = '';
    while ($i < 8)
    	{
        my $randum_num = int(rand($#passset + 1));
        my $this = $passset[$randum_num];
        if ($this ne $lastwun)
        	{
	        $rnd_passwd .= $this;
	        $lastwun = $this;
	        $i++;
	        }
    	}
    return $rnd_passwd;
	}
#
# Force directories to exist
#
sub force_dir
	{
	my $path = shift;
	$path =~ s/\\/\//g;
	my @parts = split(/\//,$path);
	my $allpath = '';
	foreach my $dir (@parts)
		{
		$allpath .= "$dir/";
		if (!-d $allpath)
			{
			mkdir($allpath,0777) || die "Cannot create directory: $allpath\n";
			}
		}
	}
#
# Now pull in the survey specific configuration items
#
sub get_config
	{
	&subtrace('get_config');
	my $id = shift;
	die (<<FATAL) if (! -d qq{$qt_root/$id/config});
FATAL ERROR: DIRECTORY $qt_root/$id/config does not exist !
(Perhaps the survey $id does not exist on this virtual server ?)
<form onsubmit="return false"><input type="button" value="Go Back" onclick="window.history.go(-1)"></form>
FATAL
	my $filename = "$qt_root/$id/config/config.pl";
	if (-f $filename)
		{
		&my_require ($filename,1);
		}
	else
		{
		&debug("File does not exist: $filename");
		my_die("File does not exist: $filename\n");
		}
	$filename = "$qt_root/$id/config/config2.pl";
	if (-f $filename)
		{
		&my_require ($filename,0);	# File is not mandatory
		}
	#
	# Pull in language specific strings now:
	#
# Need to look at the language input parameter quickly here first 
	$resp{ext_language} = lc($input{language}) if (defined $input{language});
	$language = $resp{ext_language} if ($resp{ext_language} ne '');
	my %langcodes = (
					en => 'en',			# English
					fr => 'fr',			# French
					fi => 'fi',			# Finnish
					it => 'it',			# Italian
					br => 'br',			# Brazilian (Portuguese)
					po => 'br',			# Portuguese
					de => 'de',			# German
					da => 'da',			# Danish
					sp => 'sp',			# Spanish
					es => 'sp',			# Spanish
					sw => 'sw',			# Swedish
					sv => 'sw',			# Swedish
					nl => 'nl',			# Dutch (Netherlands)
					no => 'no',			# Norwegian
					po => 'pl',			# Polish
					pl => 'pl',			# Polish
					pt => 'pt',			# Portuguese
# Asian/Unicode languages
					th => 'th',			# Thai
					jp => 'jp',			# Japanese
					ja => 'jp',			# Japanese					
					kr => 'kr',			# Korean
					ko => 'kr',			# Korean
					ru => 'ru',			# Russian
					hi => 'hi',			# Hindi
					ch => 'ch',			# Chinese
					zh => 'ch',			# Chinese (Taiwan, Hong Kong)
					gb-zh => 'gb_zh',	# Chinese Simplified (Mainland China)
					gb_zh => 'gb_zh',	# Chinese Simplified (Mainland China)
					ar => 'ar',			# Arabic
					in => 'in',			# Indonesian
					ms => 'ms',			# Malaysian
					);
	my $code = $langcodes{lc($language)} || 'en';
	&my_require (qq{TPerl/strings-$code.pl},1);	# Pull in locally defined strings (if any);
	if ($code eq 'ar') {
		$html_alignment = qq{ DIR="RTL"};
		$css_alignment = qq{ style="float: left;"};
	}
	my $themecfg = qq{$ENV{DOCUMENT_ROOT}/themes/$theme/config.js};
	if ($theme && -f $themecfg)
		{
		&my_read_js ($themecfg,1);	# File is mandatory, reads contents of .js file into %extras hash
		}
	&endsub;
	}
#
# Run an external program/command line
#
sub run_shell_cmd
	{
	my $cmd = shift;
	&qt_save;		# Make sure the data is on disk b4 we activate the processing script !!
	$saved = 1;
	&debug("Running script: $cmd");
	my $res = `$cmd`;
	&debug("Output is: $res");
	$res
	}
#
#	Get valid tokens from file
#
sub get_valid_tokens
	{
	my $force = shift;
    my $filename = "$data_dir/valid_tokens.pl";
  	my_require ($filename,$force);
	}
#
#	Get token status from file
#
sub get_token_status
	{
	undef %tokens;
	my $force = shift;
    my $filename = "$data_dir/tokens.pl";
  	my_require ($filename,$force);
	}
#
# Read in response to open-ended question
#
sub get_written
	{
	my $save = $_;
	my $q = shift;
	my $sq = shift;
	&subtrace($q,$sq);
	my $buf = '';
	my $wfile = "$data_dir/W${q}_${sq}.txt";
#	print "Checking for file $wfile\n" if ($d);
	if (-f $wfile)
		{
		print "   ==> Opening $wfile\n" if ($d);
		open(WR,"< $wfile") || die "Error $! reading file $wfile\n";
		while (<WR>)
			{
			$buf .= $_;
			}
		close(WR);
		}
#	print "written data is: [$buf]\n" if ($d);
	&endsub($buf);
	$_ = $save;		# Preserve current pattern space
	$buf;
	}

sub get_data
	{
	my $q = shift;
	my $key = shift;
	my $label = uc(shift);
	my $result = $resp{'_'.$label};
	&debug("get_data($label)=$result");
	$result;
	}

sub set_data
	{
	my $q = shift;
	my $key = shift;
	my $label = uc(shift);
	my $data = shift;
	$resp{'_'.$label} = $data;
	}
#
# Update status of token
#
sub update_token_status
	{
	my $status = shift;
  	$status = 3 if (($resp{'token'} =~ /^123/) || ($resp{'token'} eq '9999'));
  	if ($resp{token} ne '')		# Don't go to the DB if they never logged in !
  		{
		&db_conn;
		&db_set_status($survey_id,$resp{id},$resp{token},$status,$resp{seqno},$no_uid);
		}
	}
#
# Update status of CASE for Ivor
#
sub update_ivor_status
	{
	my $status = shift;
	&subtrace($status);
	&db_conn;
	&db_set_ivor_status($survey_id,$resp{seqno},$status);
	&endsub;
	}
#
#
#
sub cleanup_tfiles
	{
	&subtrace;
	opendir(DDIR,$data_dir) || die "Error $! encountered while reading directory $data_dir\n";
	$use_tnum = 0;	# Turn off this feature for now to stop them being written by qt_save
	my @files = grep(/T$resp{seqno}/,readdir(DDIR));
	&debug("Deleting files:".join(",",@files));
	foreach my $file (@files)
		{
		&debug("Removing file: $data_dir/$file");
		unlink "$data_dir/$file";
		}
	closedir DDIR;
	&endsub;
	}
#
# Method to count data in a D_File.
# - also updates a dcounts hash
#
sub count_data
	{
	undef %dcounts;
	my $dcount = 0;
	foreach my $key (grep (/^_Q/,keys %resp))
		{
		my $val = $resp{$key};
		$val =~ s/$array_sep//g;
		$val =~ s/^\s+//g;
		if ($val ne '')
			{
			my $sect = $key;
			$sect =~ s/^_Q//i;
			$sect =~ s/(.).*/$1/i;
			$dcounts{$sect}++ if ($sect =~ /^[a-z]/i);
			$dcount++;
			}
		}
	foreach my $key (grep (/^ext_/,keys %resp))
		{
		next if ($key eq 'ext_seqno');
		next if ($key eq 'ext_BACK2');
		next if ($key eq 'ext_btn_submit');
		next if ($key eq 'ext_session');
		my $val = $resp{$key};
		$val =~ s/$array_sep//g;
		$val =~ s/^\s+//g;
		if ($val ne '')
			{
			next if ($key eq 'ext_married');
			$dcounts{EXT}++;
			$dcount++;
			}
		}
	foreach my $key (grep (/^mask_/,keys %resp))
		{
		my $val = $resp{$key};
		$val =~ s/$array_sep//g;
		$val =~ s/^\s+//g;
		if ($val ne '')
			{
			$dcounts{MASK}++;
			}
		}
	foreach my $key (grep (/^v/,keys %resp))
		{
		my $val = $resp{$key};
		$val =~ s/$array_sep//g;
		$val =~ s/^\s+//g;
		if ($val ne '')
			{
			$dcounts{VAR}++;
			}
		}
	$resp{dcount} = $dcount;		# Save count for diagnostic purposes
	$dcount;
	}
#
# Indent/Undent
#
sub indentme
	{
	my $bq = '';
	$bq = '<BLOCKQUOTE>' if ((!$no_bq));# && (!$margin_notes));
	$bq;
	}
sub undentme
	{
	my $bq = '';
	$bq = '</BLOCKQUOTE>' if ((!$no_bq));# && (!$margin_notes));
	$bq;
	}
#
# Trim leading and trailing whitespace
#
sub trim
	{
	my $thing = shift;
	$thing =~ s/^\s+//;
	$thing =~ s/\s+$//;
	$thing;
	}	

sub get_progress_html
	{
	my ($perc,$width,$height,$leftstyle,$rightstyle) = @_;
	if ($percent_complete && $percent_complete > 0) {
		$perc = $percent_complete;
	}
	my $leftw = "&nbsp;";
	my $rightw = "&nbsp;";
	if ($tight)
		{
		$leftstyle = 'prog1' if ($leftstyle eq '');
		$rightstyle = 'prog2' if ($rightstyle eq '');
		}
	else
		{
		$leftstyle = 'heading' if ($leftstyle eq '');
		$rightstyle = 'options' if ($rightstyle eq '');
		}
	$height = 15 if ($height eq '');
	$width = 100 if ($width eq '');
	if ($perc > 45)
		{
		$leftw = "$perc\%";
		}
	else
		{
		$rightw = "$perc\%";
		}
	$perc = 1 if ($perc <= 0);
	if ($leftw =~ m/nbsp/) {
		$leftw = "";
	}
	my $html = <<PERC;
	<table class="progress_bar" $css_alignment>
	  <tr> 
	    <td height="$height" width="${perc}%" align="center" class="progress_fill" valign="middle"> 
	      $leftw $rightw
	    </td>
	    <td height="$height" align="Center" class="progress">
	      <!-- $rightw --> &nbsp;
	    </td>
	  </tr>
	</table>
PERC
	$html;
	}

sub get_thing
	{
	my $lcname = lc(shift);
	my $newthing = '';
	my $done = 0;
	if ($lcname =~ /^(\d+)x(\d+)/)
		{
		my $two = $2 - 1;
		$lcname = "$1-$two";
		}
# Try to get a user variable
	if ($newthing eq '')
		{
		$newthing = getvar($lcname);
		$done = 1 if ($newthing eq '""');					# It's there, but blank
		$newthing =~ s/^"//;				# Automatically strip off quotes from variables
		$newthing =~ s/"$//;
		}
# Try for regular data item 
	if (!$done)
		{
		if ($newthing eq '')
			{
			$newthing = get_data($q,$lcname,$lcname);
			}
	# Now try to evaluate a global Perl variable by that name
		if ($newthing eq '')
			{
			$newthing = eval("\$$lcname");
			}
		}
	$newthing;				# Return the goods now
	}
#
# Substitute other responses...
#
sub subst
	{
	my $thing = shift;
#	&subtrace($thing);
	my $fini = 0;
	my $dd;
	$thing =~ s/\\n/<br>/ig;
	while (!$fini)
		{
		$fini = 1;
		if ($thing =~ /\$\$([\w_]+)\[(\d+)\]/)			# Indexed mask element
			{
			$fini = 0;
			$dd = 1;
			my $name = $1;
			my $index = $2;
			my $newthing = maskstr($name,$index);		# Simply find the new value
			$thing =~ s/\$\$$name\[$index\]/$newthing/i;
			}
		elsif ($thing =~ /\$\$([\w_]+)/)				
			{
			$fini = 0;
			my $name = $1;
			my $newthing = get_thing($name);		# Simply find the new value
			$newthing = qq{<SPAN class="qlabel">$newthing.</SPAN>} if ($name eq "q_label");
			$newthing = qq{<SPAN class="instruction">$instr</SPAN>} if ($name eq "instr");
			$thing =~ s/\$\$$name/$newthing/i;
			}
		if ($thing =~ /[<\[]+%([\w_]+)\[(\d+)\]%[>\]]+/)			# Indexed mask element
			{
			$fini = 0;
			$dd = 1;
			my $name = $1;
			my $index = $2;
			my $newthing = maskstr($name,$index);		# Simply find the new value
			$thing =~ s/[<\[]%$name\[$index\]%[>\]]/$newthing/i;
			}
		elsif ($thing =~ /[\[<]+%([\w_]+)%[\]>]+/)
			{
			$fini = 0;
			my $name = $1;
			my $newthing = get_thing($name);		# Simply find the new value
			$newthing = qq{<SPAN class="qlabel">$newthing.</SPAN>} if ($name eq "q_label");
			$newthing = qq{<SPAN class="instruction">$instr</SPAN>} if ($name eq "instr");
			$newthing =~ s/\\n/\n/g;
			$thing =~ s/[\[<]%$name%[\]>]/$newthing/i ;
			}
		}
#	&endsub($thing);
	$thing;
	}
	
####### Subroutines used by code block, could be deemed as UDF's
#
sub max
    {
	my $a = shift;
	$a = getvar($a) if ($a =~ /^[a-z]/);
	my $b = shift;
	$b = getvar($b) if ($b =~ /^[a-z]/);
	while ($b ne '')
		{
		$a = ($a>$b) ? $a : $b;
		$b = shift;
		}
	$a;
	}

sub streq
	{
	my $a = lc(shift);
	my $b = lc(shift);
	($a eq $b);
	}

sub ismask
	{
	my $maskname = shift;
	my $index = shift;
	$index = getvar($index) if ($index =~ /^[a-z]/);
	my $mask_name = &qt_get_mask($maskname);
	my (@mask) = split(/$array_sep/,$resp{$mask_name});
	$mask[$index];
	}

sub maskstr
	{
	my $maskname = shift;
	my $index = shift;
	$index = getvar($index) if ($index =~ /^[a-z]/);
	my $maskt_name = &qt_get_maskt($maskname);
	my (@maskt) = split(/$array_sep/,$resp{$maskt_name});
	$maskt[$index];
	}
	
sub min
    {
	my $a = shift;
	$a = getvar($a) if ($a =~ /^[a-z]/);
	my $b = shift;
	$b = getvar($b) if ($b =~ /^[a-z]/);
	while ($b ne '')
		{
		$a = ($a<$b) ? $a : $b;
		$b = shift;
		}
	$a;
	}

sub get_gpdata
	{
	my $ql = shift;
	my $ix1 = shift;
	$ix1 = getvar($ix1) if ($ix1 =~ /^[a-z]/);
	my $ix2 = shift;
	$ix2 = getvar($ix2) if ($ix2 =~ /^[a-z]/);
	my $qn = goto_qlab($ql);		# Work out the question no
    my $filename = "$qt_root/$resp{'survey_id'}/config/q$qn.pl";
  	&my_require ($filename,1);
	my $data = get_data('','',$ql);		# Get the data
	my @stuff = split(/$array_sep/,$data);
	my $ix = ($scale*$ix1) + $ix2;
	debug("Retrieving value data($data) from index $ix");
	$stuff[$ix];
	}
#
####### END OF Subroutines used by code block

sub commify                # $ret = commify ($purenumber) - put commas in a numeric string, eg 1,000,000
	{
    my $x = shift;
	return $x if ($x =~tr/0-9/0-9/ < 4); 
	1 while $x =~ s/^\s*(-?\d+)(\d{3})/$1,$2/;
	return $x;
	}


sub check_email
	{
# Initialize local email variable with input to subroutine.              #
	my $email = shift;

# If the e-mail address contains:                                        #
    if ($email =~ /(@.*@)|(\.\.)|(@\.)|(\.@)|(^\.)/ ||

        # the e-mail address contains an invalid syntax.  Or, if the         #
        # syntax does not match the following regular expression pattern     #
        # it fails basic syntax verification.                                #

        $email !~ /^.+\@(\[?)[a-zA-Z0-9\-\.]+\.([a-zA-Z]{2,3}|[0-9]{1,3})(\]?)$/) 
        {

        # Basic syntax requires:  one or more characters before the @ sign,  #
        # followed by an optional '[', then any number of letters, numbers,  #
        # dashes or periods (valid domain/IP characters) ending in a period  #
        # and then 2 or 3 letters (for domain suffixes) or 1 to 3 numbers    #
        # (for IP addresses).  An ending bracket is also allowed as it is    #
        # valid syntax to have an email address like: user@[255.255.255.0]   #

        # Return a false value, since the e-mail address did not pass valid  #
        # syntax.                                                            #
        return 0;
    	}

    else 
    	{

        # Return a true value, e-mail verification passed.                   #
        return 1;
    	}
	}
	
sub input
	{
	my $param = shift;
	$dun{$param}++;
	$input{$param};
	}

#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Read Cookie environment variable, and split into values
sub ReadCookies
	{
	undef %cookies;
	my $c;
	my $dough = $ENV{'HTTP_COOKIE'};
	&debug("Cookies=$dough");
	if ($dough ne '')
		{
		my @mix = split('; ',$dough);
		foreach $c (@mix)
			{
			my @bits = split('=',$c);
			&debug("Cookie: $bits[0] = $bits[1]");
			$cookies{$bits[0]} = $bits[1];
			}
		}
	}
	
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Initialise Variables for the collation of information 
#	until we are ready to dump it out to the HTML file
# 	**Note the use of undef to clear out variables when used
#		in persistent mode with PerlEx or Mod_Perl
#
sub resetVars
	{
	undef $display_label;
	undef $grid_type;
	$body = '';
	$single = '';
	$hdr = '';
	$list_sep = ", ";			# Used when assembling human-readable list (for document merge)
	undef %script_body;			# Make sure that they are cleaned out OK.
	undef %script_lang;
	%script_body = ();
	%script_lang = ();
	undef @options ;			# Make sure that they are cleaned out OK.
	undef $javascript;
	undef $others;
	undef @skips;
	undef $buttons;
	undef %dun;
	$skip_found = 0;
	undef $none;
	undef $required;
	undef $autoselect;
	undef $specify_n;
	undef $grid_include;
	undef $grid_exclude;
	undef $rank_grid;
	undef $mask_local;
	undef $indent;
	undef $no_recency;
	undef @can_proceed;
	$table_cellspacing=0;
	$nest = 0;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
sub add_script
	{
	my ($name, $language, $theCode) = @_;
	&subtrace('add_script',$name);
	# Commented out by AC for the nokia
	# &add2body("Warning: replacing script [$name]\n") if (($script_body{$name} ne '') && ($one_at_a_time));
	$script_body{$name} = ($name eq '') ? $script_body{$name}."\n$theCode" : $theCode;
	$script_lang{$name} = ($language ne '') ? $language : "JavaScript";
	&endsub;
	}

sub append2script
	{
	my ($name, $language, $theCode) = @_;
	&subtrace('append2script',$name,$theCode);
#	&add2body("Warning: Appending to empty script [$name]\n") 
	if ($script_body{$name} eq '')
		{
		$script_lang{$name} = ($language ne '') ? $language : "JavaScript";
		}
	$script_body{$name} .= "\n$theCode";
	&endsub;
	}

sub add2body
	{
	my ($html) = shift;
	$body = $body."$html\n";
	}
	
sub add2single
	{
	my ($html) = shift;
	$single = $single."$html\n";
	}
	
sub add2hdr
	{
	my ($html) = shift;
	$hdr = $hdr."$html\n";
	}
	
sub dump_scripts
	{
	&subtrace();
	my $doit = shift;
	$doit = 1 if ($doit eq '');
	my $js = 0;
	my $vs = 0;
	my $jc = '';
	my $vc = '';
	my $end_script = "</SCRIPT>\n";
	if (0)#($no_validation == 1)
		{
		$jc = '<SCRIPT TYPE="text/JavaScript">'."\n";
		$jc .= "function QValid()\n\t{ return true;}\n";
		print "$jc \n$end_script\n";
		}
	if ($no_validation == 1)		# If validation is turned off, just nuke the QValid method, as we may want the other javascript to be there
		{
		if ($buttons ne '0')
			{
			my $uni_msg = subst_errmsg($sysmsg{BTN_SUBMITTING});
			$script_body{QValid} = <<QVALID;
//
// OK, we have passed all the checks and are about to allow the form to be submitted. 
// So we gray it out to make sure it cannot be clicked again
//
//???	document.q.btn_submit.value = "$uni_msg";
	if (document.getElementById('status'))
		document.getElementById('status').innerHTML = "$uni_msg";
//	document.q.btn_submit.disabled = true;
QVALID
			}
		$script_body{QValid} .= qq{	return true;\n};
		}
#	else
#		{
	my %extras_vb = ();
	my %extras_js = ();
	foreach my $subroutine (sort (keys %script_lang))
		{
		$js++ if ($script_lang{$subroutine} =~ /JavaScript/i);
		$vs++ if ($script_lang{$subroutine} =~ /VBScript/i);
		}
	$jc = '<SCRIPT type="text/JavaScript">'."\n" if ($js && $doit);
	$vc = '<SCRIPT type="text/VBScript">'."\n" if ($vs && $doit);
	if ($script_lang{'global()'} ne '')
		{
		$jc .= qq{// GLOBAL CODE: \n$script_body{'global()'}\n};
		}
	foreach my $subroutine (sort (keys %script_lang))
		{
		&debug("$script_lang{$subroutine}: $subroutine");
		next if ($subroutine eq 'global()');
		if ($script_lang{$subroutine} eq "JavaScript")
			{
			if ($subroutine eq '')
				{
				$jc .="$script_body{$subroutine}\n";
				}
			else
				{
				if ($subroutine =~ /^src_(.*)/)
					{
					my $name = $1;
					$extras_js{$name} = $script_body{$subroutine};
					}
				else
					{
					if ($subroutine =~ /\(/)
						{
						$jc .= "function $subroutine\n\t{\n";
						}
					else
						{
						$jc .= "function $subroutine()\n\t{\n";
						}
					$jc .= $script_body{$subroutine};
					$jc .= "\t}\n";
					}
				}
			}
		elsif ($script_lang{$subroutine} eq "VBScript")
			{
			if ($subroutine =~ /^src_(.*)/)
				{
				$extras_vb{$1} = $script_body{$subroutine};
				}
			else
				{
				$vc .= "Sub $subroutine()\n";
				$vc .= $script_body{$subroutine};
				$vc .= "End Sub\n\n";
				}
			}
		else
			{
			print "Script language unknown for $subroutine: ($script_lang{$subroutine})\n";
			}
		}
	if ($js && $doit)
		{
		print "$jc \n";
		print "$end_script\n";
		foreach my $x (sort keys %extras_js)
			{
			&debug("JavaScript Extras: $x");
			print qq{<SCRIPT type="text/JavaScript" SRC="/$survey_id/$extras_js{$x}">\n};
			print "$end_script\n";
			}
		}
	if ($vs && $doit)
		{
		print "$vc \n";
		print "$end_script\n";
		foreach my $x (sort keys %extras_vb)
			{
			&debug("VBScript Extras: $x");
			print qq{<SCRIPT type="text/VBScript" SRC="/$survey_id/$extras_vb{$x}">\n};
			print "$end_script\n";
			}
		}
#		}
	print qq{<script type="text/javascript" src="/includes/triton.js"></script> <!-- Triton utility scripts -->\n};

	if ($extras{dojo}{enabled}) {
		print qq{
<!-- required: dojo.js -->
<script type="text/javascript" src="/dojo/dojo/dojo.js"
	djConfig="isDebug: false, parseOnLoad: true"></script>
<script type="text/javascript">
	dojo.require("dijit.dijit"); // optimize: load dijit layer
	dojo.require("dijit.form.Form");
		};
	foreach my $dijit (keys %{$extras{dojo}{modules}}) {
		print qq{	dojo.require("dijit.form.$dijit");\n};
	}
		print qq{
	dojo.require("dojox.timing");
	dojo.require("dojo.parser");	// scan page for widgets and instantiate them

	dojo.ready(setupSendForm);		// This looks after auto-save and stopping user leaving form
</script>
		};
	}
	&endsub;
	}
	
sub dump_header
	{
	&subtrace('dump_header');
	my $ext_pid = "";
	my $seq_number = "";
	my $survey_id = "";
	if ($url_pid) {
		$pid_name = "ext_" . $url_pid;
		$ext_pid = $resp{$pid_name};
	} else {
		$ext_pid = $resp{"ext_PID"};
	}
	$seq_number = $resp{"seqno"};
	$survey_id = $resp{"survey_id"};
	print qq{<head>\n};	
	#ICRA no longer exists  -- print qq{<meta http-equiv="pics-label" content='(pics-1.1 "http://www.icra.org/ratingsv02.html" comment "ICRAonline v2.0" l gen true for "http://$ENV{SERVER_NAME}/"  r (nz 1 vz 1 lz 1 oz 1 cz 1) "http://www.rsac.org/ratingsv01.html" l gen true for "http://$ENV{SERVER_NAME}/"  r (n 0 s 0 v 0 l 0))'>\n};	
	print qq{<meta http-equiv="Content-Type" content="text/html; charset=$charset">\n} if ($charset ne '');
# More meta tags in $hdr (see qt_mymeta)
	print "$hdr\n";
	if ($extras{dojo}{enabled}) {
		print qq{<link id="themeStyles" rel="stylesheet" href="/dojo/dijit/themes/soria/soria.css">\n};
	}
	if ($extras{jquery}{modules}{spellchecker}) {		# Using the jquery spellchecker?
		print qq{
<!--[if IE]>
	<link rel="stylesheet" type="text/css" media="screen" href="/spell/css/spellchecker.css" />
	<style type="text/css">
		textarea {
			font-size: 90%;
			margin-bottom:10px;
			padding: 5px;
			border: 1px solid #999999;
			border-color: #888888 #CCCCCC #CCCCCC #888888;
			border-style: solid;
			height: 20em;
			width: 550px;
		}
		.status {
			padding: 0.5em 8px;
			font-size: small;
			color: #a0a0a0;
		}
// This one limits the width of the box with the list of badly spelt words
		.writtenbox {
		width: 610px;
		}
	</style>
<![endif]-->
};}
	print qq{</head>\n};
	&dump_scripts(1);
	&endsub;
	}
	
sub dump_body
	{
###
#
# NEED WORK HERE ORIGINAL CODE LEFT FOR EXAMINATION! DOESN't WORK - LEAVES BUTTONS AS ENCODE &#1234
#
# 955 sub dump_body
# 956     {
# 957     &subtrace('dump_body');
# 958     my $html = shift;
# 959     if ($do_body)
# 960         {
# 961         my %parts;
# 962         $parts{focus} = qq{document.q.$focus_control.focus();} if (($focus_control ne '') && !$focus_off);
# 963         $parts{onload} = qq{$parts{focus} $load_script; loadme();};
# 964         print qq{<BODY class="body" onload="$parts{onload}">};
# 965         }
# 966     print $html;
# 967     print "<HR>$copyright<BR>\n" if ($do_copyright);
# 968     print qq{
# 969 	<br><br><br><br>
# 970 	</BODY>
# 971 	};
# 972  &endsub;
# 973 }
###		

	&subtrace('dump_body');
	my $html = shift;
	if ($do_body)
		{
		my $bhtml = "";
		if ($q_style) {
			$bhtml = "<style>$q_style</style>\n";	
		}
		$bhtml .= "<BODY ";
		if ($load_script ne '')
			{
			if (($focus_control ne '') && !$focus_off)
				{
				$bhtml = $bhtml.qq{ onload="document.q.$focus_control.focus(); $load_script()"};
				}
			else
				{
				$bhtml = $bhtml.qq{ onload="$load_script()"};
				}
			}
		elsif (($focus_control ne '') && !$focus_off)
			{
			$bhtml = $bhtml.qq{ onload="document.q.$focus_control.focus();"};
			}
#		$bhtml .= qq{ onkeypress="keyme()" };
		my $bodyclass = ($extras{dojo}{enabled}) ? " soria " : "body";
		$bhtml = $bhtml.qq{  class="$bodyclass" >\n};
		print $bhtml;
		}	
	print $html;
	print "<HR>$copyright<BR>\n" if ($do_copyright);
	#my $noscript = qt_noscript();
	print qq{
<br><br><br><br>
</BODY>
};
	&endsub;
	}

#	
# This was so trivial I nuked it !!!!!!
#
#sub dump_footer
#	{
#	&subtrace('dump_footer');
#	print "</HTML>\n";
#	&endsub;
#	}
	
sub dump_html
	{
	&subtrace('dump_html');
	&dump_header;
	&dump_body($body);
	if ($reason ne '')
		{
		print "<H2>Error: $reason</H2>";
		}
	print qq{</HTML>};
	&endsub;
	}

sub dump_single
	{
	&subtrace('dump_single');
	&dump_body($single);
	print qq{</HTML>};
	&endsub;
	}

sub dump_external
	{
	my $extname = shift;
	my $do_hidden = shift;
	my %need_these = (jump_to => 0,session => 0);
	if ($extname =~ /<%(\w+)%>/)
		{
		my $thing = $1;
		my $newthing = get_thing($thing);
		$extname =~ s/<%$thing%>/$newthing/gi;
		}
#	my $file = "$www_dir/$survey_id/$extname";
	my $file = "$qt_root/$resp{'survey_id'}/html/$extname";
	my $file = "$qt_root/$survey_id/html/$extname";
	&subtrace($file,$do_hidden);
#	print "Reading file: $file<BR>\n";
	if (!open (SRC,"<$file"))
		{
		&qt_CannaHandle("<B><I>Error: [$!] reading external html file: $file</B></I>"); 
		die;
		};
	my $selecting = 0;
	my $selval = -1;
	while (<SRC>)
		{
		chomp;
		s/\r//g;
		s/<html>//i;
		if (/<body/i) 		# Tweak the body statement to call the onload function
			{
			my %parts;
			$parts{focus} =	qq{document.q.$focus_control.focus();} if (($focus_control ne '') && !$focus_off);
			if (/onload="(.+?)"/i)
				{
				$load_script = $1 if (!$load_script);
				}
			$parts{onload} = qq{$parts{focus} $load_script; loadme();};
			my $bodyclass = ($extras{dojo}{enabled}) ? " soria " : "body";
			my $newbody = qq{<BODY class="$bodyclass" onload="$parts{onload}">};
			s/<body.*>/$newbody/i;
			}
		if (/name="seqno"/i)
			{
			&debug("Found seqno: setting seqno=$resp{seqno}");
			s/value=""/VALUE="$resp{seqno}"/i;
			&debug($_);
			}
		if (/tabindex=["']*(\d+)["']*/i)	# Is there a TABINDEX in there ?
			{
			$tabix = $1 + 1;		# Bump us to the next one on
			}
		if (/<input/i)				# Is there an input field ?
			{
			my $name = "Bogus";
			if (/name=['"]*(\w+)["']*/i)				# Is there an input field ?
				{
				$name = $1;
				}
			if (/type=["']radio/i)		# Radio field ?
				{
				if (/value=["'](.+?)["']/i)
					{
					my $val = $1;
					&debug("Looking for external data matching [$val] for radio button $name");
					if ($val eq $resp{"ext_$name"})
						{
						s/value=["'].+?["']/VALUE="$val" CHECKED/i;
						}
					}
				}
			if (/type=["']checkbox/i)		# Checkbox field ?
				{
				if (/value=["'](.+?)["']/)
					{
					my $val = $1;
					&debug("Looking for external data matching [$val] for checkbox $name");
					if ($val eq $resp{"ext_$name"})
						{
						s/value=["'].+?["']/VALUE="$val" CHECKED/i;
						}
					}
				}
			if (/type=["']*text/i)		# Text field ?
				{
				&debug("Looking for external data for text $name");
				my $val = $resp{"ext_$name"};
				s/name=["'](\w+)["']/NAME="$name" VALUE="$val"/i if ($val ne '');
				}
			if (/type=["']*hidden/i)		# Hidden field ?
				{
				if (! grep (/$name/,qw{seqno q_labs q_no jump_to survey_id}))
					{
					debug("Looking for internal data for text $name");
					my $val = $resp{"$name"};
					s/name=["'](\w+)["']/NAME="$name" VALUE="$val"/i if ($val ne '');
					}
				$need_these{$name} = 1 if (grep(/^$name$/i, (keys %need_these)));
				}
			}
		if (/<textarea/i)				# Is there an open-ended field ?
			{
			my $name = "Bogus";
			if (/name=['"]*(\w+)["']*/i)				# Is there an input field ?
				{
				$name = $1;
				}
			&debug("Looking for external data for open-end $name");
			my $val = $resp{"ext_$name"};
			$val =~ s/\\n/\n/g;
			s/<\/TEXTAREA>/$val<\/TEXTAREA>/i;
			}
		if (/<\/select/i)				# Is the end of a pull-down field ?
			{
			$selecting = 0;
			}
		if (/<select/i)				# Is there an pull-down field ?
			{
			my $name = "Bogus";
			if (/name=['"]*(\w+)["']*/i)				# Is there an input field ?
				{
				$name = $1;
				$selecting = 1;
				}
			&debug("Looking for external data for pulldown $name");
			$selval = $resp{"ext_$name"};
			}
		if (/<option/i)				# Is there an pull-down item ?
			{
#			&debug("Pulldown found");
			if (/value=['"](.+?)["']/i)
				{
#			&debug("Value retrieved($1)");
				my $val = $1;
				if ($selecting and ($val eq $selval))
					{
#			&debug("Pulldown item found");
					s/<OPTION/<OPTION SELECTED/i;
					}
				}
			}
		s/action=['"]['"]/action="${vhost}${virtual_cgi_bin}$go.$extension"/i;
		last if (/<\/form>/i);
		my $loopcnt = 0;
		while (/<%(\w+)%>/)
			{
			my $thing = $1;
			my $newthing = '';
			if (($thing eq 'q_no'))# && (!$one_at_a_time))
				{
				my $qq = $q_no;
				my $sq_no = ($realq eq '') ? $start_q_no : $realq;
				$newthing = "$sq_no\.$qq";
				}
			elsif (($thing eq 'q_labs'))# && (!$one_at_a_time))
				{
				my $sq_no = ($realq eq '') ? $start_q_no : $realq;
				$newthing = &goto_q_no($sq_no).".".&goto_q_no($q_no);
				$newthing =~ s/^q(\w+)\.q(\w+)/$1.$2/i;
				}
			else
				{				
				$newthing = get_thing($thing);
				}
#			&debug("<%$thing%> ==> $newthing");
			s/<%${thing}%>/$newthing/gi;
			last if ($loopcnt++ > 10);
			}
		$loopcnt = 0;
		while (/\$\$(\w+)/)
			{
			my $thing = $1;
			my $newthing = '';
			if (($thing eq 'q_no'))# && (!$one_at_a_time))
				{
				my $qq = $q_no;
				my $sq_no = ($realq eq '') ? $start_q_no : $realq;
				$newthing = "$sq_no\.$qq";
				}
			elsif (($thing eq 'q_labs'))# && (!$one_at_a_time))
				{
				my $sq_no = ($realq eq '') ? $start_q_no : $realq;
				$newthing = &goto_q_no($sq_no).".".&goto_q_no($q_no);
				$newthing =~ s/^q(\w+)\.q(\w+)/$1.$2/i;
				}
			else
				{				
				$newthing = get_thing($thing);
				}
#			&debug("\$\$$thing ==> $newthing");
			s/\$\$${thing}/$newthing/i;
			last if ($loopcnt++ > 10);
			}
		print "$_\n";
		}
#
# Do margin notes
#
	if ($margin_notes)
		{
		my $html = '';
		my $val = $resp{"mn_$qlab"};
		$val =~ s/\\n/\n/g;
		$val =~ s/\r//g;
		$val =~ s/&/&amp;/g;

		$val =~ s/</&lt;/g;
		$val =~ s/>/&gt;/g;
		$html .= qq{$sysmsg{TXT_NOTES}<BR> <TEXTAREA ROWS="4" COLS="50" TABINDEX="-1" class="notes" name="mn_$qlab" WRAP="PHYSICAL">};
		$html .= qq{$val</TEXTAREA>\n};
		my $js1 = qq{onclick="if (this.checked) {document.q.savejs = document.q.onsubmit; document.q.onsubmit='';} else { if(document.q.savejs != null) document.q.onsubmit = document.q.savejs;}"};
		my $checked = $resp{"rf_$qlab"} eq '' ? '' : 'CHECKED';
		$html .= qq{<INPUT TYPE="CHECKBOX" NAME="rf_$qlab" VALUE="1" ID="rf_$qlab" $checked TABINDEX="-1" $js1><LABEL FOR="rf_$qlab" class="notes">$sysmsg{BTN_REFUSED}</LABEL>&nbsp;\n};
		$checked = $resp{"dk_$qlab"} eq '' ? '' : 'CHECKED';
		$html .= qq{<INPUT TYPE="CHECKBOX" NAME="dk_$qlab" VALUE="1" ID="dk_$qlab" $checked TABINDEX="-1" $js1><LABEL FOR="dk_$qlab" class="notes">$sysmsg{BTN_DK}</LABEL>\n};
		print $html;
		}
#
# Make sure we have some important hidden fields if we didn't find them already...
#
	foreach my $h (keys %need_these)
		{
		print qq{<INPUT NAME="$h" TYPE="hidden" VALUE="">\n} if (!$need_these{$h});
		}
	print &get_buttons;
	close (SRC);
	&endsub;
	}

sub serve_page
	{
#	my $file = "$www_dir/$survey_id/".shift;
	my $file = "$qt_root/$resp{'survey_id'}/html/".shift;
	&subtrace('serve_page',$file);
#	print "Reading file: $file<BR>\n";
	if (!open (SRC,"<$file"))
		{
		&qt_CannaHandle("<B><I>Error: [$!] reading external html file: $file</B></I>"); 
		die;
		};
	while (<SRC>)
		{
		chomp;
		s/<html>//i;
		while (/[\[<]%([\w_]+)%[\]>]/)		# Square or angle brackets work here
			{
			my $thing = $1;
			my $newthing = get_thing($thing);
			&debug("<%$thing%> ==> $newthing\n");
			s /[<\[]%$thing%[>\]]/$newthing/gi;
			}
		while (/\$\$([\w_]+)/)				# $$token works here 2
			{
			my $thing = $1;
			my $newthing = get_thing($thing);
			&debug("<%$thing%> ==> $newthing\n");
			s /\$\$$thing/$newthing/gi;
			}
		print "$_\n";
		}
	close (SRC);
	&endsub;
	}
	
sub alert
	{
	my $errmsg = shift;
	my $nolab = shift;			# If this is set, it means we have no question label at this point
	my $msg = '';
	$msg .= "$qlab. [q$q_no.pl] Configuration Error: " if (!$nolab);
	$msg .= $errmsg;
	$msg =~ s/\n/\\n/g;
	$msg =~ s/'/\\'/g;
	&add_script("","JavaScript","alert('$msg')");
	}
	
sub debug
	{
	my ($i,$str);
	if ($t)
		{
		open (DEBUG_FILE, ">>$qt_root/log/triton.log");
		$str = '';
		for (my $i = 0; $i < $nest; $i++)
			{
			$str = "$str\t";
			}
#		print DEBUG_FILE "$str$sub: @_\n";
		my $mysub = (caller(1))[3];
		$mysub = (caller(0))[3] if ($mysub eq '');
		$mysub =~ s/main:://;
		print DEBUG_FILE "$str$mysub: @_\n";
		close (DEBUG_FILE);
		}
	}
	
sub debugtrc
	{
	my ($i,$str);
	if ($t)
		{
		open (DEBUG_FILE, ">>$qt_root/log/triton.log");
		$str = '';
		for (my $i = 0; $i < $nest; $i++)
			{
			$str = "$str\t";
			}
#		print DEBUG_FILE "$str$sub: @_\n";
		my $mysub = (caller(2))[3];
		$mysub = (caller(1))[3] if ($mysub eq '');
		$mysub =~ s/main:://;
		print DEBUG_FILE "$str$mysub: @_\n";
		close (DEBUG_FILE);
		}
	}
	
sub subtrace
	{
	my $params = join(",",@_);
	$nest++;
	&debugtrc("($params)") if ($t);
	}
	
sub endsub
	{
	my $ret = $_[0];
	&debugtrc("=$ret") if ($t);
	$nest-- if ($nest >= 0);
	}

sub my_die
	{
	my $err = shift;
	die $err if ($dying);
	print "Content-Type: text/html\n\n";
#	print &PrintHeader;				# Early on in the piece so that we can see debug output
# It's a good idea to put out an official DTD, so IE doesn't go anal on us :)
	#print qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">\n<HTML>\n};
	print qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">\n};
	print "<html" . $html_alignment . ">\n";
	$dying++;
	&add2body("<B> Fatal Error: $err </B>");
	&qt_Footer;
	exit(1);						# May need to check if we are CGI or cmd line here !
#	die $err;
	}
	
sub my_warn
	{
	my $msg = shift;
	if ($cmdline)
		{
		print STDERR "$msg\n";
		}
	else
		{
		&add2body("$msg<BR>");
		}
	}

sub my_unrequire
	{
	my $file = shift;
	$file = $relative_root.$file if ($cmdline);
	$reqfile_cache{$file} = '';
	}
	
sub my_read_js
	{
	my ($file,$fail) = @_;
	my $ok = 1;
	&subtrace($file);
#	print "Reading file: $file\n";
	my $json = read_file($file);
	my $jdata = json_to_perl($json);
	foreach my $key (keys %$jdata){
		$extras{$key} = $$jdata{$key};
	}
#	print Dumper \%extras;
#	print "dojo enabled=$extras{dojo}{enabled}\n";
#	print "jquery enabled=$extras{jquery}{enabled}\n";
    &endsub;
    $ok;
	}

sub my_require
	{
	my ($file,$fail) = @_;
	my $ok = 1;
	&subtrace($file);
	undef $require_file;
	$file = $relative_root.$file if ($cmdline);
	if ($reqfile_cache{$file} ne '')
		{
		&debugtrc("File is in require cache: $file");
		my $cmd = $reqfile_cache{$file};
#		no strict "vars";	# In case there are gremlins in that file
		eval($cmd);
#	  	use strict;
		&my_warn("REQUIRE FAILURE in file $file: $@") if $@;
		}
	else
		{
		&debugtrc("Requiring file: $file");
		if ((!(open (RQ, "<$file"))) && ($fail))
			{
			&my_warn("$! while reading file: $file\n");
			}
		my $cmd = '';
		my @checks;
		while (my $line = <RQ>)
			{
			if (/^##DFILE_CHK:/)
				{
				@checks = ($1,$2,$3,$4,$5) if ($line =~ /^##DFILE_CHK: nkeys=(\d+) checksum_keys=(\d+) checksum_data=(\d+) seq=(\d+) ts=(\d+)/);
				}
			$cmd = $cmd.$line;
			}
		close(RQ);
		$reqfile_cache{$file} = $cmd;
#		no strict "vars";	# In case there are gremlins in that file
		eval($cmd);
#	  	use strict;
		if ($@)
			{
			&my_warn("REQUIRE FAILURE in file $file: $@");
			$ok = 0;
			}
		elsif ($#checks != -1)
			{
			&debug("Checksum values=".join(",",@checks));
			my $nkeys = scalar keys %resp;
			my $checksum_keys = unpack("%32C*",join('',keys %resp)) % 65535;
			my $checksum_data = unpack("%32C*",join('',values %resp)) % 65535;
# ???
# Omit the checksum on the data itself until I can sort that out
#
			if (($nkeys != $checks[0]) || ($checksum_keys != $checks[1]) )# || ($checksum_data != $checks[2]))
				{
				my $explain = qq{nkeys=($nkeys,$checks[0]) cs_keys=($checksum_keys,$checks[1]) cs_data=($checksum_data,$checks[2])};
				warn("Checksum mismatch in data file: $file \n$explain\n"); 
				}
			}
		}
	if ($require_file ne '')
		{
	    my $filename = "$qt_root/$resp{'survey_id'}/config/$require_file";
		&debug("Pulling in file: $filename");
#	    undef $require_file;
	    &my_require($filename,$fail);
#	    &debug("grid_type=$grid_type");
	    }
    &endsub;
    $ok;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Cannot handle it !
#
sub qt_CannaHandle
	{
	$reason = shift;
	&subtrace('qt_CannaHandle',$reason);
	print "<H2> Mr Spock ! Are you there ? ($reason)</H2>\n";
	print "It seems that the Klingons have intercepted the transporter beam and ";
	print "I find myself inside their cargo hold. Beam me back quick";
	print " before I am discovered. Quickly Spock !<BR>\n";
	print "<H3> But seriously...</H3>\n";
	print "I am sorry, but what you have done is not supported ";
	print "(like save a bookmark and go back to it, or coming back after a very long break)\n";
	print " Please start another survey...<BR><BR>\n";
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Start a new survey
#
sub qt_new
	{
	my $sid = shift;
	&subtrace($sid);
	$seqno = 100;
	&nextseq($sid);
    my ($wkstid,$wkstid2) = GetWKSTID();
	$resp{'wkstid'} = $wkstid;			# Get the workstation id
	$resp{'ver'} = 1;					# Assume it's version 1 at this point !
	$resp{tnum} = 1;					# First t-file too !
	$seqno = $wkstid.sprintf("%06d",$seqno) if ($wkstid ne '');
	$tfile = '';
	$dfile = "D$seqno.pl";
	$dfile .= "z" if ($gz);
	$tfile = "T$seqno.$resp{tnum}.pl" if ($use_tnum);
	$tfile .= "z" if ($use_tnum && $gz);
	if ($#sequences != -1)
		{
		$resp{'random_seq'} = int(rand($#sequences )+0.5);
		$resp{'random_ix'} = 0;			# First q has been done already
		&debug("Selecting random sequence ($resp{'random_seq'})");
		}
	&debug("Data file set to $dfile, $tfile");
	&endsub;
	return $seqno;
	}

#
# Start a new version of survey
#
sub qt_new_version
	{
	&subtrace;
	my $int_no = shift;
	&nextseq($survey_id);
    my ($wkstid,$wkstid2) = GetWKSTID();
	$resp{'wkstid'} = $wkstid;			# Get the workstation id
	$resp{ext_int_no} = $int_no if ($int_no ne '');
	$resp{'ver'}++;						# Increment the version now
	$resp{tnum} = 1;					# First t-file in this invocation !
	$seqno = $wkstid.sprintf("%06d",$seqno) if ($wkstid ne '');
	$tfile = '';
	$dfile = "D$seqno.pl";
	$dfile .= "z" if ($gz);
	$tfile = "T$seqno.$resp{tnum}.pl" if ($use_tnum);
	$tfile .= "z" if ($use_tnum);
	$resp{seqno} = $seqno;
	&debug("Data file set to $dfile, $tfile");
	&endsub;
	return $seqno;
	}
#
# This one returns the q_no when supplied with a q_label
# special values for the return value are 0 (next q) and -1=terminate
#
sub goto_qlab
	{
	my $label = uc(shift);
	&subtrace($label);
#	$label = "Q$label" if ($label =~ /^[^q]/i);
	$label =~ s/^q//i;
	$label = "Q$label" if ($label =~ /^\d/);
	if ($label == -1){
		endsub (-1);
		return -1;
	}
	my $gotoq = 0;
    my $filename = "$qt_root/$resp{'survey_id'}/config/qlabels.pl";
#  	&my_require ($filename,1);
# Doing a straight require gives us a performance boost... especially with larger files
  	require $filename;
  	my $k = 0;
	debug("label=$label");
    if ($qlab2ix{-1} != -1)		# Is the new index defined ?
        {
        for (my $k=1;$k<=$numq;$k++)
            {
            my @qlab = split(/\s+/,uc($qlabels{$k}));
            if ($qlab[1] eq $label)
                {
                $gotoq = $k;
                last;
                }
            }
        }
    else # Try out a new way of doing this which might be quicker
        {
        $gotoq = $qlab2ix{$label} if ($qlab2ix{$label} ne '');
        }
	if ((!$gotoq) && ($label ne '-1'))
		{
		my $msg = "Could not find question label: $label";
		&alert($msg);
		&debug("Error: $msg");
		}
	&endsub($gotoq);
	$gotoq;
	}

#
# This one returns the q_label when supplied with a q_no
#
sub goto_q_no
	{
	my $target = shift;
	&subtrace($target);
	my $goto_q_no = 'UNKNOWN';
    my $filename = "$qt_root/$resp{'survey_id'}/config/qlabels.pl";
#  	&my_require ($filename,1);
# Doing a straight require gives us a performance boost... especially with larger files
  	require $filename;
	my @qlab = split(/\s+/,$qlabels{$target});
	$goto_q_no = $qlab[1];
	if (($goto_q_no eq '') && ($target ne '-1') && ($target ne ''))
		{
		my $msg = "Could not find question label for q_no=$target";
		&alert($msg);
		&debug("Error: $msg");
		}
	&endsub($goto_q_no);
	"Q$goto_q_no";
	}

use Mail::Sender;

sub send_email
	{
	my ($sid, $itype, $id, $password, $email,$cc,$fmt,$from_email,$from_name,$subject) = @_;
	debug("send_email(".join(",",@_));
	my_die("FATAL ERRROR: SID not supplied to send_email() routine\n") if ($sid eq '');
	my_die("FATAL ERRROR: itype (invite type) not supplied to send_email() routine\n") if ($sid eq '');
	my_die("FATAL ERRROR: To address not supplied to send_email() routine\n") if ($email eq '');
	my_die("FATAL ERRROR: From EMAIL not supplied to send_email() routine\n") if ($from_email eq '');
	my_die("FATAL ERRROR: From NAME not supplied to send_email() routine\n") if ($from_name eq '');
	my_die("FATAL ERRROR: SUBJECT not supplied to send_email() routine\n") if ($subject eq '');
	$itype= lc($itype);
	my $survey_id = $sid;
	my %temp = ();
	$temp{password} = $password;
#	$email =~ s/'/\\'/g;
	$temp{email} = $email;
#	print join(",",@_)."<B>\n";

	my $smtp_host = getConfig('smtp_host') or  my_die("FATAL ERRROR: Could not get smtp_host");
	my $cfg_dir = "${qt_root}/$sid/config";
# Do some nasty hunting for backward compatibility reasons to look for a template thru the versions of template names that have evolved...
	my @tried = ();
	my $fn = "$cfg_dir/$itype.txt";
	push @tried,$fn;
	if (!-f $fn)
		{
		$fn = "$cfg_dir/$itype-plain";
		push @tried,$fn;
		if (!-f $fn)
			{
			$fn = "$cfg_dir/$itype";
			$fn =~ s/(\d)$/-plain$1/;
			push @tried,$fn;
			}
		}
	&my_die("Error $!: Cannot open email template file: ".join(" or ",@tried)."\n") if (!(-f $fn) && ($fmt != 1));
	my $tbuf = '';
	if (-f $fn)	
		{
		open (TXT,"<$fn") || &my_die("Error $!: Cannot open email template file: $fn\n");
		debug("Reading TEXT file: $fn");
		while (<TXT>)
			{
	#		chomp;
			s/\r//g;
			while (/<%(\w+)%>/)
				{
				my  $thing = $1;
				my $val = '';
				$val = $temp{$thing} if ($val eq '');			# Temp stuff overrides
				$val = $ufields{$thing} if ($val eq '');		# This is where we expect to get it
				$val = $resp{$thing} if ($val eq '');			# It might come from the collected data (Peer List)
				$val = eval("\$$thing") if ($val eq '');		# This is a last ditch and is deprecated
				s/<%$thing%>/$val/ig;
				}
			$tbuf .= "$_";#\r\n";
			}
		close TXT;
		}
	my @tried = ();
	my $fn = "$cfg_dir/$itype.htm";
# Do some nasty hunting for backward compatibility reasons to look for a template thru the versions of template names that have evolved...
	push @tried,$fn;
	if (!-f $fn)
		{
		$fn = "$cfg_dir/$itype-html";
		push @tried,$fn;
		if (!-f $fn)
			{
			$fn = "$cfg_dir/$itype";
			$fn =~ s/(\d)$/-html$1/ ;
			push @tried,$fn;
			}
		}
	&my_die("Error $!: Cannot open email template file: ".join(" or ",@tried)."\n") if (!(-f $fn) && ($fmt != 2));
	my $hbuf = '';
	if (-f $fn)	
		{
		open (HTM,"<$fn") ;
		debug("Reading HTML file: $fn");
		while (<HTM>)
			{
	#		chomp;
			s/\r//g;
			while (/<%(\w+)%>/)
				{
				my  $thing = $1;
				my $val = '';
				$val = $temp{$thing} if ($val eq '');			# Temp stuff overrides
				$val = $ufields{$thing} if ($val eq '');		# This is where we expect to get it
				$val = $resp{$thing} if ($val eq '');			# It might come from the collected data (Peer List)
				$val = eval("\$$thing") if ($val eq '');		# This is a last ditch and is deprecated
	#			print qq{s/<%$thing%>/$val/g;\n};
				s/<%$thing%>/$val/ig;
				}
			$hbuf .= "$_";#\r\n";
			}
		close HTM;
		}
# we need only create one Mail::Sender.  do it here.
	$from_name = $config{from_name} if ($config{from_name} ne '');
	$from_name = $config{emails}{$itype}{from_name} if ($config{emails}{$itype}{from_name} ne '');
#	print "from_name=$from_name (for $itype)\n";
	my $loop = 0;
	if ($from_name =~ /^\$\$(\w+)/)
		{
		my $tok = $1;
		my $newtok = '???';
#		print "Looking up $tok = $ufields{$tok}\n";
		$newtok = $ufields{$tok} if ($ufields{$tok} ne '');
		$newtok = $temp{$tok} if (($temp{$tok} ne '') && ($ufields{$tok} eq ''));
		$newtok = $resp{$tok} if (($resp{$tok} ne '') && ($temp{$tok} eq '') && ($ufields{$tok} eq ''));
		$from_name =~ s/\$\$($tok)/$newtok/gi;
		last if $loop > 10;
		$loop++;
		}

	$loop = 0;
	while ($from_email =~ /^\$\$(\w+)/)
		{
		my $tok = $1;
		my $newtok = '???';
#		print "Looking up $tok = $ufields{$tok}\n";
		$newtok = $ufields{$tok} if ($ufields{$tok} ne '');
		$newtok = $temp{$tok} if (($temp{$tok} ne '') && ($ufields{$tok} eq ''));
		$newtok = $resp{$tok} if (($resp{$tok} ne '') && ($temp{$tok} eq '') && ($ufields{$tok} eq ''));
		$from_email =~ s/\$\$($tok)/$newtok/gi;
		last if $loop > 10;
		$loop++;
		}
	$loop = 0;
	while ($subject =~ /\$\$(\w+)/)
		{
		my $tok = $1;
		my $newtok = 'TEAM MEMBER';
#		print "Looking up $tok = $ufields{$tok}\n";
		$newtok = $ufields{$tok} if ($ufields{$tok} ne '');
		$newtok = $temp{$tok} if (($temp{$tok} ne '') && ($ufields{$tok} eq ''));
		$newtok = $resp{$tok} if (($resp{$tok} ne '') && ($temp{$tok} eq '') && ($ufields{$tok} eq ''));
		$subject =~ s/\$\$($tok)/$newtok/gi;
		last if $loop > 10;
		$loop++;
		}
	my $ret = 0;
	if ($fmt == 1)	# HTML only
		{
		debug("Sending HTML only message to $email, subject=$subject, password=$password, from=$from_name <$from_email>");
		$ret = (new Mail::Sender)->MailMsg({smtp => $smtp_host,
									to=>$email,
									from=>qq{$from_name <$from_email>},
									cc=>$cc,
					                subject=> $subject,
									headers=>"X_TID: ${sid}-${password}-I\r\nX-Mailer: Triton Survey System",
									msg=>$hbuf,
									} ) or &my_die($Mail::Sender::Error);
		}
	elsif ($fmt == 2)	# Text only
		{
		debug("Sending PLAIN text only message to $email, subject=$subject, password=$password, from=$from_name <$from_email>");
		$ret = (new Mail::Sender)->MailMsg({smtp => $smtp_host,
									to=>$email,
									from=>qq{$from_name <$from_email>},
									cc=>$cc,
					                subject=> $subject,
									headers=>"X_TID: ${sid}-${password}-I\r\nX-Mailer: Triton Survey System",
									msg=>$tbuf,
									} ) or &my_die($Mail::Sender::Error);
		}
	else	# 2-part message, HTML+Text
		{
		my $sender = new Mail::Sender	 (	{from=>qq{$from_name <$from_email>},
											smtp=>$smtp_host,
											});
		&my_die ("Could not make a Mail::Sender : " . $Mail::Sender::Error ) unless ref $sender;
		$Mail::Sender::NO_X_MAILER = 1;
		debug("Opening multipart message to $email, subject=$config{email_subject}, password=$password, from=$from_name <$from_email>");
		$sender->OpenMultipart ( {		to=>$email,
										cc=>$cc,
										boundary=>'-triton-lib-2011--',
						                subtype => 'alternative',
						                subject=> $subject,
										headers=>"X_TID: ${sid}-${password}-I\r\nX-Mailer: Triton Survey System",
										} ) or &my_die($Mail::Sender::Error);
		debug("Plain part: ".substr($tbuf,0,80)."...");
		$sender->Part ( {ctype=>"text/plain; charset=us-ascii",
						encoding => '7bit',
						disposition => 'NONE' });
		$sender->SendEnc($tbuf);
#		print "Sending HTML...\n";
		debug("HTML part: ".substr($hbuf,0,80)."...");
		$sender->Part( { ctype => "text/html; charset=us-ascii",
				encoding => '7bit',
				disposition => 'NONE' });
		$sender->SendEnc($hbuf);
		my $ret = $sender->Close ;
		&my_die($Mail::Sender::Error) if $ret < 0;
		}
	my $mail_status = "Sending $itype email to $email: <BR>&nbsp;&nbsp;&nbsp;";
	$mail_status .= ($Mail::Sender::Error eq '') ? qq{<FONT color="green">OK</font>} : qq{<FONT color="red">$ret: $Mail::Sender::Error</font>};
	debug($mail_status);
# Return mail status
	$mail_status;
	}

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Execute a code block (as supplied)
#
sub execute_perl_codeblock
	{
	my $pcode = shift;
	my $tmp = $pcode;
	$tmp =~ s/\n/\nC\t\t/ig;
	&subtrace("\n(PERL CODE FOLLOWS)\nC\t\t$tmp\n(END OF CODE BLOCK)");
	debug("Evaluating $tmp");
	my $result = eval "$pcode";
	if ($@)
		{
		my $msg = $@;
		$msg =~ s/\\\\/\\/g;
		&debug( qq{Error $msg while evaluating expression:\n [$pcode]\n});
		&alert( qq{Error $msg while evaluating expression:\n [$pcode]\n});
		}
	&endsub($result);							# Don't think we need to return anything
	$result;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Execute a code block (as supplied)
#
sub execute_codeblock
	{
	my $code = shift;
	my $tmp = $code;
	$tmp =~ s/\n/\nC\t\t/ig;
	&subtrace("\n(CODE FOLLOWS)\nC\t\t$tmp\n(END OF CODE BLOCK)");

	my $gotoq = 0;
	my @lines = split (/\n/,$code);
	for (my $k=0;$k<$#lines;$k++)
		{
		$lines[$k] = &subst($lines[$k]);
		} 
	my $doing = 1;							# We are executing things
	my $cblock = 0;
	my $done = 0;
	my %set_stack;
#
# Make a pass to look for assignments (used by the CLEAR instruction)
#
	for (my $ix=0;$ix<=$#lines;$ix++)
		{
# Strip leading spaces:
		$lines[$ix] =~ s/^\s*//g;
		next if ($lines[$ix] =~ /^#/);
		next if (length($lines[$ix]) == 0);
		next if ($lines[$ix] =~ /^\s*if\s*\((.*?)\)\s*goto\s+(\w+)/i);

		if ($lines[$ix] =~ /^\s*if\s*\((.*?)\)\s*(\w+)\s*=\s*(.*)/i)			# NB regexp's match those below
			{
			$set_stack{$2}++;
			}
		next if ($lines[$ix] =~ /\s*if\s*\((.*)\)/i);
		if ($lines[$ix] =~ /^\s*(\w+)\s*=\s*(.*)/)
			{
			$set_stack{$1}++;
			}
		}
	for (my $ix=0;$ix<=$#lines;$ix++)
		{
# Strip leading spaces:
		$lines[$ix] =~ s/^\s*//g;
		next if ($lines[$ix] =~ /^#/);
		next if (length($lines[$ix]) == 0);
		&debug( " ===> Processing line:[$lines[$ix]]");
		if ($lines[$ix] =~ /\s*if\s*\((.*?)\)\s*goto\s+([-]*\w+)/i)		# IF () GOTO - One liner ?
			{
			&debug( "\tIF ($1) GOTO $2");
			if (&eval_expr($1))
				{
				&debug( "\t TRUE => GOTO $2");
				$gotoq = &goto_qlab($2);
				last;
				$done = 1;
				}
			next;
			}
		if ($lines[$ix] =~ /^\s*clear\s*$/i)						# CLEAR ?
			{
			foreach my $key (keys %set_stack)
				{
				&debug( "CLR $key (was '".&getvar($key)."')");
				&setvar($key,'');
				}
			}
		if ($lines[$ix] =~ /^\s*if\s*\((.*?)\)\s*(\w+)\s*=\s*(.*)/i)	# IF () ASSIGNMENT - One liner ?
			{
			&debug( "\tIF ($1) SET $2 = $3");
			if (&eval_expr($1) && !$done)
				{
				&debug( "\t TRUE => SET $2 = $3");
				my $name = $2;
				my $val = $3;
				if  ($val =~ /["]/) 	# Looks like a quoted string ?
					{
					&setvar($name,$val);
					}
				elsif ($val =~ /[\(\+\-\*\/]/)	# Looks like an expression ?
					{
					&setvar($name,&eval_expr($val));
					}
				else
					{
					if ($val =~ /^\d+/)			# Looks like a number
						{						
						&setvar($name,$val);
						}
					else
						{
						&setvar($name,&getvar($val)) if ($name ne $val);	# Don't do it if we are just fooling the compiler
						}
					}
				}
			next;
			}
		if ($lines[$ix] =~ /^\s*if\s*\((.*)\)/i)					# IF () ?
			{
			&debug( "\tIF ($1)...");
			$doing = 0;
			if (&eval_expr($1) && !$done)
				{
				&debug( "\t TRUE ");
				$doing = 1;
				}
			next;
			}
		if (($lines[$ix] =~ /^\s*begin\s*$/i) || ($lines[$ix] =~ /^\s*\{\s*$/))						# BEGIN ?
			{
			&debug( "\tBEGIN") if ($doing && !$done);
			$cblock = 1;
			next;
			}
		if (($lines[$ix] =~ /^\s*end\s*$/i) || ($lines[$ix] =~ /^\s*\}\s*$/))							# END ?
			{
			&debug( "\tEND") if ($doing && !$done);
			$cblock = 0;
			$doing = 1;
			next;
			}
		if ($lines[$ix] =~ /^\s*goto\s+([-]*\w+)/i)						# GOTO ?				
			{
			if ($doing && !$done)
				{
				&debug( "\tGOTO $1"); 
				$gotoq = &goto_qlab($1);
				last;
				$done = 1;
				}
			next;
			}
		if ($lines[$ix] =~ /^\s*mask\s*\(\s*(\w+)\s*\)\s*=\s*mask\s*\((\w+)\s*\)\s*\+\s*\s*mask\s*\((\w+)\s*\)/ )					# MASK ADDITION ?
			{
			if ($doing && !$done)
				{
				my $target = $1;
				$lines[$ix] =~ s/\s*//g;
				my $tmp = $lines[$ix];
				my @src = ();
				$tmp =~ s/^mask\((\w+)\)=//;	# Get rid of the LHS
				&debug("Processing $tmp");
				my $loopcnt = 0;			
				while ($tmp =~ /^mask\((\w+)\)[\+]*/)
					{
					&debug("Adding mask $1");
					push(@src,$1);
					$tmp =~ s/^mask\((\w+)\)[\+]*//;
					$loopcnt++;
					if ($loopcnt > 20)
						{
						&alert("mask addition: Error: Loopcnt exceeded");
						&debug("Error: Loopcnt exceeded");
						last;
						}
					}
				&debug( "\tMASK ADD $target = ".join(" + ",@src));
				&qt_mask_add_many($target,@src);
				}
			next;
			}
		if ($lines[$ix] =~ /^\s*mask\s*\(\s*(\w+)\s*\)\s*=\s*mask\s*\((\w+)\s*\)\s*\-\s*\s*mask\s*\((\w+)\s*\)/ )		# MASK SUBTRACTION ?
			{
			if ($doing && !$done)
				{
				my $target = $1;
				my $maska = $2;
				my $maskb = $3;
				my $tmp = $lines[$ix];
				&debug( "\tMASK SUBTRACT $target = $maska - $maskb");
				&qt_mask_subtract($target,$maska,$maskb);
				}
				next;
			}
		if ($lines[$ix] =~ /^\s*mask\(\s*(\w+)\s*\)\s*(=+)\s*mask\((\w+)\s*\)/)					# MASK ASSIGNMENT ?
			{
			if ($doing && !$done)
				{
					my $exact = ($2 eq '==');					# Exact copy does not compact the mask
					&debug( "\tMASK COPY $1 = $3 (exact=$exact)");
					&qt_mask_copy($1,$3,$exact);
				}
				next;
			}
		if ($lines[$ix] =~ /^\s*(\w+)\s*=\s*mask\((\w+)(.*?)\)/)					# MASK NAMES ASSIGNMENT ?
			{

			if ($doing && !$done)
				{
				my $varname = $1;
				my $maskname = $2;
				my $rest = $3;
				my $delim = ",";
				$delim = $1 if ($rest =~ /\s*,\s*["'](.*?)['"]/);
				&debug( "\tSET $varname = MASK NAMES($maskname,$delim)");
				&setvar($varname,&qt_mask_names($maskname,$delim));
				}
			next;
			}
		if ($lines[$ix] =~ /^\s*(\w+)\s*=\s*mask_count\((\w+)(.*?)\)/)					# MASK COUNT ASSIGNMENT ?
			{
			if ($doing && !$done)
				{
				my $varname = $1;
				my $maskname = $2;
				&debug( "\tSET $varname = MASK COUNT($maskname)");
				&setvar($varname,&qt_mask_count($maskname));
				}
			next;
			}
		if ($lines[$ix] =~ /^\s*(\w+)\s*=\s*(.*)/)					# ASSIGNMENT ?
			{
			if ($doing && !$done)
				{
				&debug( "\tSET $1 = $2");
				my $name = $1;
				my $val = $2;
#				if (($val =~ /[\(\+\-\*\/]/) && !($val =~ /^["]/)) 	# Looks like an expression ?
				if  ($val =~ /["]/) 	# Looks like a quoted string ?
					{
					&setvar($name,$val);
					}
				elsif ($val =~ /[\(\+\-\*\/]/)	# Looks like an expression ?
					{
					&setvar($name,&eval_expr($val));
					}
				else
					{
					if ($val =~ /^\d+/)			# Looks like a number
						{						
						&setvar($name,$val);
						}
					else
						{
						&setvar($name,&getvar($val)) if ($name ne $val);
						}
					}
				}
			next;
			}
		if ($lines[$ix] =~ /^\s*(set_data)/)					# Call to set_data
			{
			if ($doing && !$done)
				{
				eval_expr ($lines[$ix]);
				}
			next;
			}
		}
	&endsub($gotoq);
	$gotoq;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Evaluate an expression
#
sub eval_expr
	{
	my $result;
	my $expr = shift;
	if ($expr =~ /^"/)
		{
		$result = $expr;
		$result =~ s/^"//;
		$result =~ s/"$//;
		}
	else
		{
		my %reserved = (
				'max' => '1',
				'min' => '1',
				'sin' => '1',
				'streq' => '1',
				'ismask' => '1',
				'get_gpdata' => '1',
				'set_data' =>1,
				'get_data' =>1,
				);
		my $strstuff = 0;
		my $thing = " ".$expr." ";
		my $orig = $thing;
		&subtrace($thing);
		$eval_recurse++;
		if ($eval_recurse >= 10)
			{
			&debug('Evaluator recursion too deep - aborting');
			&endsub(-1);
			return 0;
			}
	
		$thing =~ s/([^=])=([^=])/$1==$2/g;
		$thing =~ s/>==/>=/g;
		$thing =~ s/<==/<=/g;
		$thing =~ s/([^&])&([^&])/$1&&$2/g;
		$thing =~ s/([0-9\W])or(\W)/$1||$2/gi;
		$thing =~ s/([0-9\W])and(\W)/$1&&$2/gi;
		$thing =~ s/(\W)not\s+equal(\W)/$1!=$2/gi;
		$thing =~ s/(\W)equal(\W)/$1==$2/gi;
		$thing =~ s/\W0+([1-9]+)/$1/g;			# Make sure we kill octal numbers
		$thing =~ s/\<\>/\!=/g;	
		$thing =~ s/[\[{]/\(/g;	
		$thing =~ s/[\]}]/\)/g;	
		&debug( "Expression=$thing");
		my $loopcnt = 0;
		while ($thing =~ /[^\w^"^']([a-z][\w]*)[^\w^"^']/i)			# Try and preserve quoted strings
			{
			my $name = $1;
			if ($reserved{lc($name)})
				{
				$thing =~ s/$name/0$name/gi;		# Push the function call aside for the moment
				&debug( "Shifted $name [$thing]");
				$strstuff = 1;
				next;
				}
	#		&debug( "Evaluating \$\{$name\}");
			my $token = &getvar($name);			#	eval("\$\{$name\}");
			if ($@ || ($token eq ''))
				{
				&debug( " ==> Error: could not find variable: $name");
				$token = 0;		# Try and stop a syntax error
				}
			if (($token =~ /^"/) && !$strstuff)			# Don't warn about strings if special functions are involved
				{
				&debug( "String found in variable: $name ($token)");
				&alert( "String found in variable: $name ($token)");
				$token = 0;
				}
			&debug( "name=$1, value=$token");
			$thing =~ s/$name/$token/;
			if (++$loopcnt > 100)			# This limit might seem high, but NAGS pushes it ! (was 50 before)
				{
				&debug( "Looping error while substituting: $orig");
				&alert( "Looping error while substituting: $orig");
				last;
				}
			}
		foreach my $func (keys %reserved)
			{
			$thing =~ s/0$func/$func/gi;
			}
		$result = eval "$thing";
		if ($@)
			{
			my $msg = $@;
			&debug( qq{Error $msg while evaluating expression:\n [$orig]\n after variable substitution is:\n [$thing]});
			&alert( qq{Error $msg while evaluating expression:\n [$orig]\n after variable substitution is:\n [$thing]});
			}
		$result = 0 if ($result eq '');
		&endsub( "'$result' expr=($thing)");
		$eval_recurse--;
		}
	$result;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Set a variable (name supplied without the 'v')
#
sub setvar
	{
	my ($varname) = lc(shift);
	if ($varname ne '')
		{
		my ($val) = shift;
		my $myname = $varname;
		$myname = "v$varname"  if !($varname =~ /^ext_/i);		# Don't make variables of externals !!
		&subtrace("$myname=$val");
		$resp{$myname} = $val;		!
		&endsub;
		}
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Set a string variable (name supplied without the 'v')
#
sub setvar_str
	{
	my ($varname) = lc(shift);
	if ($varname ne '')
		{
		my ($val) = shift;
		$val = $1 if ($val =~ /^\"(.*?)\"$/);	# Strip quotes if already present
		my $myname = $varname;
		$myname = "v$varname"  if !($varname =~ /^ext_/i);		# Don't make variables of externals !!
		&subtrace("$myname=$val");
		$resp{$myname} = qq{"$val"};
		&endsub;
		}
	}


#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Get a variable value (name supplied without the 'v')
#
sub getvar
	{
	my ($varname) = lc(shift);
	my $val = '';
	if ($varname ne '')
		{
		&subtrace("v$varname");
		$val = $resp{'v'.$varname};
		$val = $resp{$varname} if ($val eq '');
		&endsub($val);
		}
#	$val =~ s/^"//;
#	$val =~ s/"$//;
	$val;
	}

#
# Get a variable value as a string(name supplied without the 'v')
#
sub getvar_str
	{
	my ($varname) = lc(shift);
	my $val = '';
	if ($varname ne '')
		{
		&subtrace("v$varname");
		$val = $resp{'v'.$varname};
		$val = $resp{$varname} if ($val eq '');
		$val =~ s/^"//;
		$val =~ s/"$//;
		&endsub($val);
		}
	$val;
	}

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Un-Set values
#
sub unsetvalue
	{
	my ($stuff) = shift;
	my %hash = ();
	&split_values($stuff,\%hash);
	foreach my $key (keys %hash)
		{
		$resp{"v$key"} = '';
		}
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Set values
#
sub setvalue
	{
	my ($stuff) = shift;
	my %hash = ();
	&split_values($stuff,\%hash);
	foreach my $key (keys %hash)
		{
		&debug("setvalue $key=$hash{$key}");
		$resp{"v$key"} = qq{"$hash{$key}"};
		}
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Split up value assignments
#
sub split_values
	{
	my $in = shift;
	my $href = shift;
	my $done = 0;
 	&subtrace($in);
#	if ($in =~ /([a-zA-Z][\w\.]*)=/)
#		{
#		print "var=[$1], $value=[$2]\n";
#		}
	my $loopcnt = 0;
	while (!$done)
		{
		if ($in =~ /\s*([a-zA-Z][\w\.]*)\s*=\s*\"(.*?)\"/)
			{
			my $name = $1;
			my $val = $2;
			$$href{$name} = $val;
			my $bit = qq{$name="$val"};
			my $len = length($bit);
			my $rest = substr($in,$len);
			$rest =~ s/^\s+\,//;		# Trim leading whitespace
			$in = $rest;
			print "$bit\n" if ($d);
			}
		$done = 1 if (length($in) == 0);
		$loopcnt++;
		if ($loopcnt > 20)
			{
			last;
			&debug("Error: Loopcnt exceeded");
			}
		}
	&endsub;
	}	
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Get the side of the argument
#
sub qt_get_side
	{
	my ($side) = lc(shift);
 	&subtrace("qt_get_side($side)");
	$side = 0 if ($side eq '');
#
# The 'v' is there to ensure that internal namespaces 
# are not violated by user-defined variable names
#
	if ($side =~ /^\D/)		# Starts with a non-numeric ?
		{
	    $side = $resp{'v'.$side} if ($resp{'v'.$side} ne '');
#
# If not found, check to see if it's a normal data point
#
	    if ($side eq '')
	    	{
	    	$side = $resp{$side} if ($resp{$side} =~ /^\D/);
	    	}
	    }
	&endsub;
	return $side; 
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Get the variable name
#
sub qt_get_var
	{
	my ($in) = lc(shift);
	&debug($in);
#
# The 'v' is there to ensure that internal namespaces 
# are not violated by user-defined variable names
#
	return (($in eq '') ? '' : 'v'.$in);
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Get the mask name
#
sub qt_get_mask
	{
	my ($in) = @_;
	&subtrace($in);
#
# The 'mask_' is there to ensure that internal namespaces 
# are not violated by user-defined variable names
#
	&endsub;
	return (($in eq '') ? '' : 'mask_'.$in);
	}

sub qt_get_maskt
	{
	my ($in) = @_;
	&subtrace($in);
#
# The 'mask_' is there to ensure that internal namespaces 
# are not violated by user-defined variable names
#
	&endsub;
	return (($in eq '') ? '' : 'maskt_'.$in);
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Update mask values - multi select question only
#
sub qt_update_mask
	{
	my ($name,@values) = @_;
	&subtrace($name,join(",",@values));
	my @mask = @values;
	my @maskt = ();
	my $nopt = $#options + $others;

	if ($name ne '')
		{
		my $mask_name = &qt_get_mask($name);
		my $maskt_name = &qt_get_maskt($name);
		&debug ("Updating mask $mask_name (".join(",",@values).")");
#
# Read the masks into arrays
#
		if ($resp{$mask_name} eq '')
			{
			&debug("Building new mask for $mask_name");
			my $i = 0;
			foreach (@mask)
				{
				$mask[$i] = ($mask_reverse) ? !$values[$i] : $values[$i];
				my $j = $i - $#options - 1;
				$maskt[$i] = ($i <= $#options) ? $options[$i] : get_data($q,"$q_no-$j","$qlab-$j");
				&debug("mask[$i] = $mask[$i] ($maskt[$i])");
				$i++;
				}
			}
		else
			{
			&debug("Updating mask for $mask_name, currently=[$resp{$mask_name}]");
			@mask = split(/$array_sep/,$resp{$mask_name});
			@maskt = split(/$array_sep/,$resp{$maskt_name});
			for(my $i=0;$i<=$nopt;$i++)
				{
				my $j = $i - $#options - 1;
				my $x = ($i <= $#options) ? &subst($options[$i]) : get_data($q,"$q_no-$j","$qlab-$j");
				if ($specify_n ne '')
					{
					my $ix = $#options - $i + 1;
					if ($ix <= $specify_n)
						{
						$x = get_data($q,"$q_no-$i","$qlab-$i");
						}
					}
				$maskt[$i] = $x if (($x ne '') && ($mask_local || ($mask_reset ne '')));
				$maskt[$i] = $x if (($x ne '') && ($maskt[$i] eq ''));		# Grab it anyway if it's blank
				if ($values[$i])
					{
					$mask[$i] = ($mask_reverse) ? !$values[$i] : $values[$i];
					}
				&debug("mask[$i] = $mask[$i] ($maskt[$i])");
				}
			}
		$resp{$mask_name} = join ($array_sep,@mask);
		$resp{$maskt_name} = join ($array_sep,@maskt);
		}
	&endsub;
	}
#
# Update the mask for a grid question type
#	
sub qt_update_mask_grid()
	{
	my ($name,@values) = @_;
	&subtrace($name,join(",",@values));
	my @mask = @values;
	my @maskt;
	my @flags = split(/,/,$true_flags);
	my $nopt = $#options + $others;
	my ($mask_name,$maskt_name);
	if ($name ne '')
		{
		$mask_name = &qt_get_mask($name);
		$maskt_name = &qt_get_maskt($name);
		&debug ("Updating mask $mask_name with: (".join(",",@values).")");
#
# Read the masks into arrays
#
		if ($resp{$mask_name} eq '')
			{
			&debug("Building new mask for $mask_name");
			my $i = 0;
			foreach (@mask)
				{
				$mask[$i] = ($mask_reverse) ? !$values[$i] : $values[$i];
				if ($#flags != -1)
					{
					$mask[$i] = ($flags[$mask[$i]]) ? 1 : 0;
					$mask[$i] = !$mask[$i] if ($mask_reverse);
					}
#				my $j = $i - $#options - 1;
				$maskt[$i] = $options[$i]; 		#($i <= $#options) ? $options[$i] : get_data($q,"$q_no-$j","$qlab-$j");
				my $x = $#options + 1 - $i;		
				$maskt[$i] = get_data($q,"$q_no-$i","$qlab-$i") if (($specify_n ne '') && ($specify_n >= ($x)));
				&debug("mask[$i] = $mask[$i] ($maskt[$i])");
				$i++;
				}
			}
		else
			{
			&debug("Updating mask for $mask_name (was [$resp{$mask_name}])");
			@mask = split(/$array_sep/,$resp{$mask_name});
			@maskt = split(/$array_sep/,$resp{$maskt_name});
			for(my $i=0;$i<=$nopt;$i++)
				{
				my $j = $i - $#options - 1;
				my $x = ($i <= $#options) ? &subst($options[$i]) : get_data($q,"$q_no-$j","$qlab-$j");
				$maskt[$i] = $x if (($x ne '') && ($mask_local));
				$maskt[$i] = $x if (($x ne '') && ($maskt[$i] eq ''));		# Grab it anyway if it's blank
				my $rem = $#options + 1 - $i;		
				$maskt[$i] = get_data($q,"$q_no-$i","$qlab-$i") if (($specify_n ne '') && ($specify_n >= ($rem)));
				next if ($values[$i] eq '');
				if ($values[$i])
					{
					$mask[$i] = ($mask_reverse) ? !$values[$i] : $values[$i];
					}
				if ($#flags != -1)
					{
# ???? There is a problem here, I don't think the index into the flags array should be $mask[$i], it should be the new value. Later.
					debug("tf=$true_flags, true_flags[$values[$i]]=$flags[$values[$i]], value=$values[$i]");
					$mask[$i] = ($flags[$values[$i]]) ? 1 : 0;
					$mask[$i] = !$mask[$i] if ($mask_reverse);
					}
				&debug("mask[$i] = $mask[$i] ($maskt[$i])");
				}
			}
		$resp{$mask_name} = join ($array_sep,@mask);
		$resp{$maskt_name} = join ($array_sep,@maskt);
		if ($selectvar ne '')
			{
			my $sv = 0;
			for (my $j=0;$j<=$#mask;$j++)
				{
				$sv += $mask[$j];
				}
			&setvar($selectvar,$sv);
			}
		}
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Update mask values
#
sub qt_update_mask_single
	{
	my $name = shift;
	my $ix = shift;
	&subtrace($name,$ix);
	my @mask;
	my @maskt;
	my ($mask_name,$maskt_name);
	
	if ($name ne '')
		{
		$mask_name = &qt_get_mask($name);
		$maskt_name = &qt_get_maskt($name);
		&debug ("Updating mask $mask_name ($ix)");
#
# Read the masks into arrays
#
		if ($resp{$mask_name} eq '')
			{
			&debug("Building new mask for $mask_name");
			my $nopt = $#options + $others;
			my $k;
			for (my $k=0;$k<=$nopt;$k++)
				{
				$mask[$k] = ($mask_reverse) ? 1 : 0;
				my $j = $k - $#options - 1;
				$maskt[$k] = ($k <= $#options) ? $options[$k] : get_data($q,"$q_no-$j","$qlab-$j");
				}
			$mask[$ix] = ($mask_reverse) ? 0 : 1;
			}
		else
			{
			&debug("Updating mask for $mask_name [$resp{$mask_name}]");
			@mask = split(/$array_sep/,$resp{$mask_name});
			@maskt = split(/$array_sep/,$resp{$maskt_name});
			$mask[$ix] = ($mask_reverse) ? 0 : 1;
			&debug("mask[$ix] = $mask[$ix]");
#			if ($mask_local)
#				{
				my $j = $ix - $#options - 1;
				my $x = ($ix <= $#options) ? $options[$ix] : get_data($q,"$q_no-$j","$qlab-$j");
				$maskt[$ix] = $x if ($x ne '');
#				}
			}
		$resp{$mask_name} = join ($array_sep,@mask);
		$resp{$maskt_name} = join ($array_sep,@maskt);
		}
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Reset mask values
#
sub qt_mask_reset
	{
	my $maskname = shift;
	my $others = shift;
	my ($mask_name,$maskt_name);
	$mask_name = &qt_get_mask($maskname);
	$maskt_name = &qt_get_maskt($maskname);
	&debug ("Resetting mask $mask_name");
	my (@mask) = @skips;
	my @maskt;
	my $len = $#mask;
#	for (my $j = 1; $j <= $others; $j++)
#		{
#		$mask[$len+$j] = '';
#		}
	my $i = 0;
	foreach (@mask)
		{
		$mask[$i] = ($mask_reverse) ? 1 : '0';
		$maskt[$i] = $options[$i];
		$i++;
		}
	my $k = 0;
	for(my $k=0;$k<$others;$k++)
		{
		$mask[$i] = ($mask_reverse) ? 1 : '0';
		$maskt[$i] = '';
		$i++;
		}
	$resp{$mask_name} = join ($array_sep,@mask);
	$resp{$maskt_name} = join ($array_sep,@maskt);
	&endsub($resp{$maskt_name});
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Add mask values (No longer used)
#
sub qt_mask_add
	{
	my $dest = shift;
	my $src1 = shift;
	my $src2 = shift;
	
	my $destmask_name = &qt_get_mask($dest);
	my $destmaskt_name = &qt_get_maskt($dest);
	
	my $src1mask_name = &qt_get_mask($src1);
	my $src1maskt_name = &qt_get_maskt($src1);

	my $src2mask_name = &qt_get_mask($src2);
	my $src2maskt_name = &qt_get_maskt($src2);

	&debug ("Adding masks $dest = $src1 + $src2");
	my (@src1mask) = split($array_sep,$resp{$src1mask_name});
	my (@src1maskt) = split($array_sep,$resp{$src1maskt_name});

	my (@src2mask) = split($array_sep,$resp{$src2mask_name});
	my (@src2maskt) = split($array_sep,$resp{$src2maskt_name});

	my $i = 0;
	my $j = 0;
	my @mask;
	my @maskt;
	foreach (@src1mask)
		{
		&debug("src1, i=$i");
		$mask[$j] = $src1mask[$i];
		&debug("copying $src1maskt[$i] to [$j]");
		$maskt[$j] = $src1maskt[$i];
		$j++;
		$i++;
		}
	$i = 0;
	foreach (@src2mask)
		{
		&debug("src2, i=$i");
		$mask[$j] = $src2mask[$i];
		&debug("copying $src2maskt[$i] to [$j]");
		$maskt[$j] = $src2maskt[$i];
		$j++;
		$i++;
		}
	$resp{$destmaskt_name} = join ($array_sep,@maskt);
	$resp{$destmask_name} = join ($array_sep,@mask);
	}

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Subtract mask values
#
sub qt_mask_subtract
	{
	my $dest = shift;
	my $src1 = shift;
	my $src2 = shift;
	
	my $destmask_name = &qt_get_mask($dest);
	my $destmaskt_name = &qt_get_maskt($dest);
	
	my $src1mask_name = &qt_get_mask($src1);
	my $src1maskt_name = &qt_get_maskt($src1);

	my $src2mask_name = &qt_get_mask($src2);
	my $src2maskt_name = &qt_get_maskt($src2);

	&debug ("Subtracting masks $dest = $src1 - $src2");
	my (@src1mask) = split($array_sep,$resp{$src1mask_name});
	my (@src1maskt) = split($array_sep,$resp{$src1maskt_name});

	my (@src2mask) = split($array_sep,$resp{$src2mask_name});
	my (@src2maskt) = split($array_sep,$resp{$src2maskt_name});

	my @mask;
	my @maskt;
	my $i = 0;
	foreach (@src1mask)
		{
		&debug("src1, i=$i");
		$mask[$i] = $src1mask[$i];
		$maskt[$i] = $src1maskt[$i];
		$i++;
		}
	$i = 0;
	foreach (@src2mask)
		{
		&debug("-src2, i=$i, val=$src2mask[$i]");
		$mask[$i] = 0 if $src2mask[$i];
		$maskt[$i] = $src2maskt[$i];
		$i++;
		}
	$resp{$destmaskt_name} = join ($array_sep,@maskt);
	$resp{$destmask_name} = join ($array_sep,@mask);
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Add mask values
#
sub qt_mask_add_many
	{
	my $dest = shift;
	my $destmask_name = &qt_get_mask($dest);
	my $destmaskt_name = &qt_get_maskt($dest);
	my @mask;		# Temp vars to hold the new mask
	my @maskt;
	my $src = shift;
	while ($src ne '')
		{
		my $srcmask_name = &qt_get_mask($src);
		my $srcmaskt_name = &qt_get_maskt($src);

		&debug ("Adding masks $dest += $src");
		my (@srcmask) = split($array_sep,$resp{$srcmask_name});
		my (@srcmaskt) = split($array_sep,$resp{$srcmaskt_name});
		
		my $i = 0;
		my $j = $#mask+1;
		foreach (@srcmask)
			{
			&debug("src, i=$i");
			$mask[$j] = $srcmask[$i];
			&debug("copying $srcmaskt[$i] to [$j]");
			$maskt[$j] = $srcmaskt[$i];
			$j++;
			$i++;
			}
		$src = shift;
		}
	$resp{$destmaskt_name} = join ($array_sep,@maskt);
	$resp{$destmask_name} = join ($array_sep,@mask);
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Copy mask values
#
sub qt_mask_copy
	{
	my $dest = shift;
	my $src = shift;
	my $exact = shift;
	my $destmask_name = &qt_get_mask($dest);
	my $destmaskt_name = &qt_get_maskt($dest);
	my $srcmask_name = &qt_get_mask($src);
	my $srcmaskt_name = &qt_get_maskt($src);
	&debug ("Copying mask $dest = $src srcmaskt_name=$srcmaskt_name");
	my (@srcmask) = split($array_sep,$resp{$srcmask_name});
	my (@srcmaskt) = split($array_sep,$resp{$srcmaskt_name});
	my $i = 0;
	my $j = 0;
	my @mask;
	my @maskt;
	foreach (@srcmask)
		{
		&debug("i=$i, val=$srcmask[$i],  t=$srcmaskt[$i]");
# Make all mask copies take the data as well - other behaviour is obscure/misleading
 		if (1) #$srcmask[$i] || $exact)
			{
			$mask[$j] = '0';
			$mask[$j] = $srcmask[$i];
			&debug("copying $srcmaskt[$i] to [$j]");
			$maskt[$j] = $srcmaskt[$i];
			$j++;
			}
		$i++;
		}
	$resp{$destmaskt_name} = join ($array_sep,@maskt);
	$resp{$destmask_name} = join ($array_sep,@mask);
	}
#
# Copy mask values
#
sub qt_mask_count
	{
	my $src = shift;
	my $srcmask_name = &qt_get_mask($src);
	&debug ("Countng mask $src");
	my (@srcmask) = split($array_sep,$resp{$srcmask_name});
	my $cnt = 0;
	for(my $i=0;$i<=$#srcmask;$i++)
		{
# Make all mask copies take the data as well - other behaviour is obscure/misleading
 		$cnt++ if ($srcmask[$i]);
		}
	$cnt;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Get mask names
#
sub qt_mask_names
	{
	my $src = shift;
	my $delim = shift || ", ";
	my $srcmask_name = &qt_get_mask($src);
	my $srcmaskt_name = &qt_get_maskt($src);
	&debug ("Getting mask names from $src");
	my (@srcmask) = split($array_sep,$resp{$srcmask_name});
	my (@srcmaskt) = split($array_sep,$resp{$srcmaskt_name});
	my $i = 0;
	my $j = 0;
	my @maskt;
	foreach (@srcmask)
		{
#		&debug("i=$i");
		if ($srcmask[$i])
			{
			&debug("getting $srcmaskt[$i] to [$j]");
			$maskt[$j] = $srcmaskt[$i];
			$j++;
			}
		$i++;
		}
	join ($delim,@maskt);
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Update mask values - open ended questions
#
sub qt_update_mask_opens
	{
	&subtrace('qt_update_mask_opens');
	my ($name,@values) = @_;
	my ($mask_name,$maskt_name);
	if ($name ne '')
		{
		my $mask_name = &qt_get_mask($name);
		my $maskt_name = &qt_get_maskt($name);
		my @mask = @values;
		my @maskt = @values;
		my $nopt = $#values;
		for (my $i=0;$i<=$#mask;$i++)
			{
			$mask[$i] = ($maskt[$i] eq '') ? 0 : 1;
			}
		$resp{$mask_name} = join ($array_sep,@mask);
		$resp{$maskt_name} = join ($array_sep,@maskt);
		};
	&endsub;
	}

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Update mask values - number/percentage questions
#
sub qt_update_mask_number
	{
	my ($name,@values) = @_;
	&subtrace($name,join(",",@values));
	my ($mask_name,$maskt_name);
	if ($name ne '')
		{
		my $mask_name = &qt_get_mask($name);
		my $maskt_name = &qt_get_maskt($name);
		my @mask = @values;
		my @maskt = @values;
		my $nopt = $#values;
		for (my $i=0;$i<=$#mask;$i++)
			{
			$mask[$i] = ($mask[$i] > 0) ? 1 : 0;
			$maskt[$i] = $options[$i];
			}
		$resp{$mask_name} = join ($array_sep,@mask);
		$resp{$maskt_name} = join ($array_sep,@maskt);
		};
	&endsub;
	}

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Update mask values - rank questions
#
sub qt_update_mask_rank
	{
	my ($name,@values) = @_;
	&subtrace($name,join(",",@values));
	my ($mask_name,$maskt_name);
	if ($name ne '')
		{
		my $mask_name = &qt_get_mask($name);
		my $maskt_name = &qt_get_maskt($name);
		my @mask = @values;
		my @maskt = @values;
		my $nopt = $#values;
		for (my $i=0;$i<=$#mask;$i++)
			{
			$mask[$i] = ($mask[$i] > 0) ? 1 : 0;
			$maskt[$i] = $options[$i];
			}
		$resp{$mask_name} = join ($array_sep,@mask);
		$resp{$maskt_name} = join ($array_sep,@maskt);
		};
	&endsub;
	}


# This is one I use alot in perl_code.
# returns a hash of true keys. 1===0===1 returns {0=>1,2=>1}
sub qt_hash {
	my $key = shift;
	my $what = lc(shift) || 'one';
	
# 	my @whats = qw (one data);
# 	confess "second val must be on of @whats" unless grep $_ eq $what,@whats;
	
	# try using the key as a mask name, or a data element
	my @trys  = ($key,qt_get_mask($key),"_$key","_Q$key");
	my $val;
	foreach my $t (@trys){
		if (exists $resp{$t}){
			$val=$resp{$t};
			last;
		}
	}
	my @msk = split $array_sep,$val;
	my $ret = {};
	for (my $p=0;$p<@msk;$p++){
		my $val = 1;
		$val = $msk[$p] if $what eq 'data';
		$ret->{$p} = $val if $msk[$p];
	}
	return $ret;
}

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Save the incoming order data to a raw file. This allows any mistakes to be fixed after the fact.
#
sub qt_dumporder
	{
	&subtrace('qt_dumporder');
	my $dumpFile = $qt_root.'/input.raw';
	&debug ("Dumping raw input to file $dumpFile");
	if (!open (DUMPFILE, ">>$dumpFile"))
		{
		&add2body("Can't update dump file: $dumpFile\n");
		}
	else
		{
		my $when = localtime();
		print DUMPFILE "# Begin input $when \n";
		foreach my $key (sort (keys %input))
			{
			print DUMPFILE "    $key = '$input{$key}',\n";
			}
		print DUMPFILE "    HTTP_USER_AGENT = $ENV{HTTP_USER_AGENT}\n";
#		print DUMPFILE "# Begin environment \n";
#		foreach my $key (sort (keys %ENV))
#			{
#			print DUMPFILE "    $key = '$ENV{$key}',\n";
#			}
		print DUMPFILE "#------------------ End \n";
		close DUMPFILE;
		}
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Make sure we keep any external data that we didn't deal with already.
#
sub keep_external_data
	{
# Grab any extraneous input now:
	my @filter_out = (qw{jump_to submit});
	foreach my $key (sort (keys %input))
		{
		if (($dun{$key} eq '') && !grep(/^$key$/i,@filter_out))
			{
			if ($key =~ /^mn_/) 
				{
				$resp{$key} = $input{$key} if ($input{$key} ne '');
				}
			elsif ($key =~ /^rf_/) 	# ? Refused
				{
				$resp{$key} = '1';
				}
			elsif ($key =~ /^dk_/) 	# ? Don't know
				{
				$resp{$key} = '1';
				}
			else
				{
				$dun{$key}++;
				$input{$key} =~ s/^0*([1-9]+)/$1/ unless $allow_leading_0;			# Get rid of octal representation (leading 0's)
				$resp{"ext_$key"} = $input{$key};
				}
			}
		}
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Save the incoming data to a raw file. This allows any mistakes to be fixed after the fact.
#
sub qt_dumpinput
	{
	&subtrace('qt_dumpinput');
	my $dumpFile = $data_dir.'/input.raw';
	&debug ("Dumping raw input to file $dumpFile");
	if (!open (DUMPFILE, ">>$dumpFile"))
		{
		print "Can't update dump file: $dumpFile\n";
		}
	else
		{
		my $tt = time();
		my $ss = ($input{'seqno'} eq '') ? $seqno : $input{'seqno'};
		my $when = localtime();
		print DUMPFILE "# Begin input ts=$tt seq=$ss tnum=$input{tnum} ip=$resp{'ipaddr'} $when\n";
		foreach my $key (sort (keys %input))
			{
			print DUMPFILE "    $key = '$input{$key}',\n";
			}
		print DUMPFILE "    HTTP_USER_AGENT = $ENV{HTTP_USER_AGENT}\n";
#		print DUMPFILE "# Begin environment \n";
#		foreach my $key (sort (keys %ENV))
#			{
#			print DUMPFILE "    $key = '$ENV{$key}',\n";
#			}
		if ($do_cookies)
			{
			foreach my $cookie (sort (keys %cookies))
				{
				print DUMPFILE "    COOKIE $cookie = $cookies{$cookie}\n";
				}
			}
		print DUMPFILE "#------------------ End \n";
		close DUMPFILE;
		}
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Update a hit counter, based on the number of visits made by this client IP address 
# and supplied email
#
sub qt_hitme
	{
	&subtrace('qt_hitme');
	my ($ipaddr,$server_software,$sid) = @_;
	$seqno = &qt_new($sid) if ($input{'seqno'} eq '');
	$resp{'ipaddr'} = $ipaddr;			# Save it in the answer file!
	&qt_dumpinput;
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Save the token data
#
sub qt_save_tokens
	{
	&subtrace('qt_save_tokens');
	
	&debug ("Saving token data to file");
	my $file = "$data_dir/tokens.pl";
	if (!open (DATA_FILE, ">$file"))
		{
		&add2body("Can't create tokens file: $file\n");
		}
	else
		{
		print DATA_FILE '#!/usr/bin/perl'."\n";
#
# Save the response data in its own associative array
#
		print DATA_FILE "# $copyright\n# Response data...\n#\n\t%tokens = (\n";
		my $i = 0;
		foreach my $key (sort (keys %tokens))
			{
			print DATA_FILE ",\n" if ($i > 0);
			my $this = $tokens{$key};
			$key =~ s/'/\\'/g;
			print DATA_FILE "\t\t'$key' =>\t'$this'";
			$i++;
			}
		print DATA_FILE "\n\t\t);\n";
#
# Close the file off
#
		print DATA_FILE "#\n# I Like the number wun\n1;\n";
		close DATA_FILE;
		}
	&endsub;
	}
#
# Save the valid token data
#
sub qt_save_valid_tokens
	{
	&subtrace('qt_save_valid');
	
	&debug ("Saving token data to file");
	my $file = "$data_dir/valid_tokens.pl";
	if (!open (DATA_FILE, ">$file"))
		{
		&add2body("Can't create tokens file: $file\n");
		}
	else
		{
		print DATA_FILE '#!/usr/bin/perl'."\n";
#
# Save the response data in its own associative array
#
		print DATA_FILE "# $copyright\n# Response data...\n#\n\t%valid_tokens = (\n";
		my $i = 0;
		foreach my $key (sort (keys %valid_tokens))
			{
			print DATA_FILE ",\n" if ($i > 0);
			my $this = $valid_tokens{$key};
			$key =~ s/'/\\'/g;
			print DATA_FILE "\t\t'$key' =>\t'$this'";
			$i++;
			}
		print DATA_FILE "\n\t\t);\n";
#
# Close the file off
#
		print DATA_FILE "#\n# I Like the number wun\n1;\n";
		close DATA_FILE;
		}
	&endsub;
	}
#
# Save the valid token data
#
sub qt_save_new_tokens
	{
	&subtrace('qt_save_new_tokens');
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
   	&debug ("Saving token data to file");
   	my $tmpfile = sprintf("new_%d%02d%02d_%02d%02d%02d",$year,$mon,$mday,$hour,$min,$sec);
	my $file = "$data_dir/$tmpfile.pl";
	if (!open (DATA_FILE, ">$file"))
		{
		&add2body("Can't create tokens file: $file\n");
		}
	else
		{
		print DATA_FILE '#!/usr/bin/perl'."\n";
#
# Save the new data in its own associative array
#
		print DATA_FILE "# $copyright\n# Response data...\n#\n\t%new_tokens = (\n";
		my $i = 0;
		foreach my $key (sort (keys %new_tokens))
			{
			print DATA_FILE ",\n" if ($i > 0);
			my $this = $new_tokens{$key};
			$key =~ s/'/\\'/g;
			print DATA_FILE "\t\t'$key' =>\t'$this'";
			$i++;
			}
		print DATA_FILE "\n\t\t);\n\n\t%updated_tokens = (\n";
		$i = 0;
		foreach my $key (sort (keys %updated_tokens))
			{
			print DATA_FILE ",\n" if ($i > 0);
			my $this = $updated_tokens{$key};
			$key =~ s/'/\\'/g;
			print DATA_FILE "\t\t'$key' =>\t'$this'";
			$i++;
			}
		print DATA_FILE "\n\t\t);\n";
#
# Close the file off
#
		print DATA_FILE "#\n# I Like the number wun\n1;\n";
		close DATA_FILE;
		}
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Read the data from Dfile
#
sub qt_read_data
	{
	my $filename = shift;
	&subtrace($filename);
	if ($gz)
		{
		if (-f $filename)
			{
			my $iceref = retrieve ($filename)  or die "Can't read data from $filename!\n";
			my $sludge = uncompress($$iceref) ;
			my $rref = thaw($sludge);
			%resp = %$rref;
			}
		}
	else
		{
		&my_require($filename,0);
		}
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Save the data
#
sub qt_save
	{
	&subtrace('qt_save');
	if ($read_only)
		{
		debug("Read only mode: data not saved");
		}
	else
		{
		if($gz)
			{
			&debug ("Saving response data to file $data_dir/${dfile}, ${tfile}");
			my $frozen = freeze(\%resp);
			my $skwoshd = compress($frozen) ;
			store (\$skwoshd,"$data_dir/${dfile}")  or die "Can't store data in $data_dir/${dfile}!\n";
			if ($use_tnum && ($tfile ne ''))
				{
				store (\$skwoshd,"$data_dir/${tfile}")  or die "Can't store data in $data_dir/${tfile}!\n";
				}
			}
		else
			{
			&debug ("Saving response data to file $data_dir/$dfile, $tfile");
			if (!open (DATA_FILE, ">$data_dir/$dfile"))
				{
				&add2body("qt_save Error $! - Can't open data file: $data_dir/$dfile\n");
				}
			else
				{
				print DATA_FILE '#!/usr/bin/perl'."\n";
				if ($ENV{SCRIPT_NAME})		# Done by a CGI script ?
					{
					$resp{modified} = time();
					$resp{modified_s} = localtime();
					}
				else
					{
					$resp{modified}++;						# Bump it by a second
					$resp{modified_s} = localtime($resp{modified});
					$resp{modified_byscript} = time();		# Record the actual time here
					$resp{modified_byscript_s} = localtime();
					}
		#
		# Save the response data in its own associative array
		#
				my $when = localtime();
				print DATA_FILE "# $copyright\n# Response data... $when\n";
				my $nkeys = scalar keys %resp;
				my $checksum_keys = unpack("%32C*",join('',keys %resp)) % 65535;
				my $checksum_data = unpack("%32C*",join('',values %resp)) % 65535;
				print DATA_FILE "##DFILE_CHK: nkeys=$nkeys checksum_keys=$checksum_keys checksum_data=$checksum_data seq=$resp{seqno} ts=$resp{modified}\n\t%resp = (\n";
				my $i = 0;
				foreach my $key (sort (keys %resp))
					{
		# Escape out unwanted characters in input string
					my $this = $resp{$key};
					$this =~ s/\r\n/\n/g;
					$this =~ s/\n/\\n/g;
					$this =~ s/([\\'])/\\$1/g;
					print DATA_FILE "\t\t'$key','$this',\n";
					$i++;
					}
				$dun{'seqno'} = 1;
				print DATA_FILE "\n\t\t);\n";
		#
		# Close the file off
		#
				print DATA_FILE "#\n# I Like the number wun\n1;\n";
				close DATA_FILE;
				chmod ($chmod,"$data_dir/$dfile") if ($chmod);
			}
		#
		# Now do the Tfile as well:
		#
			if ($use_tnum && ($tfile ne ''))
				{
				if (!open (T_FILE, ">$data_dir/$tfile"))
					{
					&add2body("Error $! - Can't open data file: $data_dir/$tfile\n");
					}
				else
					{
					print T_FILE '#!/usr/bin/perl'."\n";
					if ($ENV{SCRIPT_NAME})		# Done by a CGI script ?
						{
						$resp{modified} = time();
						$resp{modified_s} = localtime();
						}
					else
						{
						$resp{modified}++;						# Bump it by a second
						$resp{modified_s} = localtime($resp{modified});
						$resp{modified_byscript} = time();		# Record the actual time here
						$resp{modified_byscript_s} = localtime();
						}
					
			#
			# Save the response data in its own associative array
			#
					my $when = localtime();
					print T_FILE "# $copyright\n# Response data... $when\n#\n\t%resp = (\n";
					my $i = 0;
					foreach my $key (sort (keys %resp))
						{
			# Escape out unwanted characters in input string
						my $this = $resp{$key};
						$this =~ s/\r\n/\n/g;
						$this =~ s/\n/\\n/g;
						$this =~ s/([\\'])/\\$1/g;
						print T_FILE "\t\t'$key','$this',\n";
						$i++;
						}
					$dun{'seqno'} = 1;
					print T_FILE "\n\t\t);\n";
			#
			# Close the file off
			#
					print T_FILE "#\n# I Like the number wun\n1;\n";
					close T_FILE;
					}
				}
			}
		}
	&my_unrequire("$data_dir/${dfile}");		# Get rid of version in memory cache, so we don't lose these changes
												# It will force the file to be read from disk again next transaction
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Dispatch
#
sub qt_dispatch
	{
	my $stop = shift;
	&subtrace("Stop=$stop");
	&debug ("Dispatch $resp{'survey_id'}: q$q_no (was at $qlab)");
	if ($q_no == -1)			# Is it a terminate ?
		{
		&endsub(-1);
		return -1;
		}
	if ($q_no > $numq)
		{
		if ($one_at_a_time)
			{
			&debug("Gone past last question - finishing");
			&endsub(0);
	      	return 0;	# Let's see what happens here
	      	}
	    else
	    	{
			&debug("Hit the end of the survey");
			$skip_found = 1;
			$q_no--;			# We want to wind back if this is an evaluator, as we have gone too far !!!
			&endsub(0);
	    	return 0;
	    	}
      	}
#
# Check the existence of the question file to see what the question type is :-
#
    my $filename = "$qt_root/$resp{'survey_id'}/config/q$q_no.pl";
    unless (open(QPERL,$filename))
      	{
		&debug ("Could not open file: $filename");
		&endsub(0);
      	return 0;
      	}
    close (QPERL);


	undef @options ;			# Make sure that they are cleaned out OK.
	undef $grid_type;
	undef $display_label;
	undef $others;
	undef $rank_grid;
	undef $random_options;
	undef $fixed;
	undef $execute;
# We can't undef it here, because we are not done with this variable yet :)
#	undef $buttons;
	undef $mask_include;
	undef $mask_update;
	undef $mask_exclude;
	undef $mask_reset;
#	undef $no_validation;
	undef $javascript;
	undef $external;
	undef $specify_n;
	undef $autoselect;
	undef $grid_include;
	undef $grid_exclude;
	undef $mask_local;
	undef $indent;
	undef $no_recency;
	undef @can_proceed;
	undef $none;
	undef $required;
	$table_cellspacing=0;
# 	&debug ("Requiring $filename");
  	&my_require ($filename,1);
  	&debug("qtype=$qtype, $prompt");
	if ($autoselect ne '')		# Is it an auto-select ?
		{
		$skip_found = 1 if ($stop);
		if ($stop)
			{
			&debug("Stopping for AUTOSELECT at q_no=$q_no");
			if($one_at_a_time)
				{
				$q_no++;
				}
			else
				{
				$q_no--;			# We want to wind back if this is an evaluator, as we have gone too far !!!
				}
			&endsub(1);
			return 1;
			}
		}
	if ($qtype == QTYPE_EVAL)		# Is it an evaluator ?
		{
		$skip_found = 1 if ($stop);
		if ($stop)
			{
			&debug("Stopping for EVAL at q_no=$q_no");
			if($one_at_a_time)
				{
				$q_no++;
				}
			else
				{
				$q_no--;			# We want to wind back if this is an evaluator, as we have gone too far !!!
				}
			&endsub(1);
			return 1;
			}
	
		&debug ("Comparing variables $lhs with $rhs");
#
# Get the two arguments
#
		$lhs = &qt_get_side($lhs);
		$rhs = &qt_get_side($rhs);
		&debug ("Comparing values $lhs with $rhs");
#
# Now do the comparison
#
		if ($lhs < $rhs)
			{
			&debug ("Less ");
			$nextq = $skips[0];
			}
		elsif ($lhs == $rhs)
			{
			&debug ("Equal ");
			$nextq = $skips[1];
			}
		elsif ($lhs > $rhs)
			{
			&debug ("Greater ");
			$nextq = $skips[2];
			}
		&debug (" - Skip to q$nextq");
#
# Calculate new value of $q_no
#
		if ($nextq eq '')
			{
			$q_no = &nextq;			# Just go to next in sequence
			}
		elsif ($nextq eq 0)
			{
			$q_no = &nextq;			# Just go to next in sequence
			}
		elsif ($nextq eq -1)
			{
			$q_no = -1;			# Just get the fuck outta here !
			}
		else
			{
# Need to skip to next question if we were not told otherwise
			($nextq == $q_no) ? &nextq : ($q_no = $nextq);
			}
#
# Now that we have decided which question to go to, re-dispatch
#
		&debug("Recursing dispatch");
		my $stat = &qt_dispatch($stop);
		if ($stat != 1)
			{
			&endsub($stat);
			return $stat;
			}
		}
	if ($qtype == QTYPE_CODE)		# Is it a code block ?
		{
		$skip_found = 1 if ($stop);
		if ($stop)
			{
			&debug("Stopping for CODE at q_no=$q_no");
			if($one_at_a_time)
				{
				$q_no++;
				}
			else
				{
				$q_no--;			# We want to wind back if this is a code block, as we have gone too far !!!
				}
			&endsub(1);
			return 1;
			}
			
		$virgin = 0;
		$nextq = &execute_codeblock($code_block);
		undef $code_block;
		if ($nextq eq '')
			{
			$q_no = &nextq;			# Just go to next in sequence
			}
		elsif ($nextq eq 0)
			{
			$q_no = &nextq;			# Just go to next in sequence
			}
		elsif ($nextq eq -1)
			{
			$q_no = -1;			# Just get the fuck outta here !
			}
		else
			{
# Need to skip to next question if we were not told otherwise
			($nextq == $q_no) ? &nextq : ($q_no = $nextq);
			}
#
# Now that we have decided which question to go to, re-dispatch
#
		&debug("Recursing dispatch");
		my $stat = &qt_dispatch($stop);
		if ($stat != 1)
			{
			&endsub($stat);
			return $stat;
			}
		}
	if ($qtype == QTYPE_PERL_CODE)		# Is it a PERL code block ?
		{
		$skip_found = 1 if ($stop);
		if ($stop)
			{
			&debug("Stopping for PERL CODE at q_no=$q_no");
			if($one_at_a_time)
				{
				$q_no++;
				}
			else
				{
				$q_no--;			# We want to wind back if this is a code block, as we have gone too far !!!
				}
			&endsub(1);
			return 1;
			}
		$virgin = 0;
# I think we need to do something here to pass the result back, although it doesn't seem to matter 
# Maybe it should pass back a q_no if there is a jump ???
		&execute_perl_codeblock($code_block);
		undef $code_block;
#		&qt_save;				# Make the changes persistent - assume something later will do that as we are only transient
		$q_no = &nextq;			# Just go to next in sequence
		&debug("Recursing dispatch");
		my $stat = &qt_dispatch($stop);
		if ($stat != 1)
			{
			&endsub($stat);
			return $stat;
			}
		}
	
	&endsub(1);
	return 1;
	}
	
sub nextq
	{
	&subtrace('nextq');
	if ($#sequences != -1)
		{
		if ($virgin)
			{
			$q_no = 1;
			}
		else
			{
			my $aref = $sequences[$resp{'random_seq'}];
			my ($tix,$i);
			$tix = $thisq;
			my @arr = @$aref;
			for (my $i = 0;$i <$#{$aref};$i++)
				{
				$tix = $i if ($thisq == $$aref[$i]);
				}
			$resp{'random_ix'} = $tix+1;
			$q_no = $$aref[$resp{'random_ix'}];
			my $xx = $resp{'random_seq'};
			&debug("sequencer: from $thisq to $q_no, sequence=$xx, ix=$resp{'random_ix'}");
			}
		}
	else
		{
		if ($virgin)
			{
			if (($one_at_a_time == 0) && ($q_no > 1))
				{
				$q_no++;
				}
			else
				{
				$q_no = 1;
				}
			}
		else
			{
			$q_no++;
			}
		}
	&endsub($q_no);
	$q_no;
	}

#
#-----------------------------------------------------------------------------------------
#
sub subst_errmsg
	{
	my $fmt = shift;
	
	while ($fmt =~ /\%[sd]/)
		{
		my $arg = shift;
		if ($fmt =~ /\%[s]/)
			{
			my $new = qq{'"+$arg+"'};
			$new = '' if (!$arg);
			$fmt =~ s/\%[s]/$new/;
			}
		else
			{
			my $new = qq{"+$arg+"};
			$new = '' if (!$arg);
			$fmt =~ s/\%[d]/$new/;
			}
		}
#
# Now fix up HTML encoded entities 
#
	while ($fmt =~ /&#(\d+)\;*/i)
		{
		my $n =  sprintf("%04x",$1);
		$fmt =~ s/&#$1\;*/\\u$n/ig;
		}
	$fmt = decode_entities($fmt);
	$fmt;
	}
	
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Apply masks (if any) to grid
#	
sub do_griding
	{
	# This might be a quick fix to make things work for us:
	&grid_include
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Apply masks (if any)
#	
sub do_masking
	{
	my $mtype = shift;		# Should be either 'validation' or 'presentation'
	my $i;
	my $cnt = 0;
	if (($mask_reset ne '') and ($mtype eq 'validation'))
		{
		&qt_mask_reset($mask_reset,$others);
		}
	my ($mask_name,$maskt_name);
	undef @a_show;
	for(my $i=0;$i<=$#options;$i++)
		{
		$a_show[$i] = 1;					# Show by default
		}
	&subtrace('do_masking',"inc=$mask_include","exc=$mask_exclude");
	if (($mask_include ne '') || ($mask_exclude ne ''))
		{
		my @loc_options = @options;
		
		my $mask_name = '';
		if ($mask_include ne '')
			{
			$mask_name = &qt_get_mask($mask_include);
			$maskt_name = &qt_get_maskt($mask_include);
			}
		if ($mask_exclude ne '')
			{
			$mask_name = &qt_get_mask($mask_exclude);
			$maskt_name = &qt_get_maskt($mask_exclude);
			}
		&debug ("Including mask $mask_name");
		my (@mask) = split(/$array_sep/,$resp{$mask_name});
		my (@maskt) = split(/$array_sep/,$resp{$maskt_name});
#		my $i = 0;
		my $masksize = $#mask+1;
		$masksize = max($masksize,$#vars+1);
		my $j = 0;
		foreach (my $i=0;$i<$masksize;$i++)			#@mask)
			{
			$mask[$i] = 0 if ($mask[$i] eq '');
			$a_show[$i] = 0;			# Turn it off now
			$vars[$i] = '' if ($vars[$i] eq '');
			my $o = ($mask_local) ? &subst($loc_options[$i]) : $maskt[$i];
			if (($mask[$i] && ($mask_include ne ''))
			|| ((!$mask[$i]) && ($mask_exclude ne ''))
			&& ($o ne ''))
				{
				&debug("Including [$i] ($maskt[$i])");
				$options[$i] = $o;
				$a_show[$i] = 1;		# Show this one
				$cnt++;
#				$j++;
				}
			else
				{
#				&debug("Excluding [$i] ($maskt[$i])");
				$options[$i] = $o;		# Make sure it's in the list !
				$a_show[$i] = 0;		# Don't show this one
				}
#			$i++;
			}
		}
	else
		{
		$cnt = $#options + 1;
		}
	&endsub("n=$cnt");
	$cnt;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Do autoselection
#	
sub do_auto
	{
	my $n = shift;
	&subtrace($n);
	if ($n =~ /[a-z]/i)		# Non-numeric ?
		{
		$n = &getvar($n);	# Look up the value
		}
	my @ans = ();
	my $k = 0;
	for (my $k=0;$k<=$#options;$k++)
		{
		$ans[$k] = '0';
		}
	my $loops = 0;
	my $nreq = ($n > ($#options+1)) ? $#options + 1 : $n;
	&debug("nreq=$nreq");
	my $ix = 0;
	while ($ix<$nreq)
		{
		my $iy = int(rand($#options+1));
#		&debug("iy=$iy");
		
		if ((!$ans[$iy]) && ($iy <= $#options) && $a_show[$iy])
			{
			$ans[$iy] = 1;
			$ix++
			}
		$loops++;
		last if ($loops >100);
		}
	&setvar($SelectVar,$n);		# Save the counter		# Get rid of this later ???
	&setvar($selectvar,$n);		# Save the counter
	&set_data($q,$q_no,$qlab,join($array_sep,@ans));
	&qt_update_mask($mask_update,@ans);
	&endsub;
	}
	

sub grid_include
	{
	&subtrace("inc=$grid_include","exc=$grid_exclude");
	my $nsel = 0;
	my ($mask_name,$maskt_name);
	my $ascale = abs($scale);
	for (my $i=0;$i<$ascale+$others;$i++)
		{
		$g_show[$i] = 1;			# If no inclusion, just set to show all
		$nsel++;
		}
	if (($grid_include ne '') || ($grid_exclude ne ''))
		{
		$nsel = 0;
		my @my_scale_words = @scale_words;
		undef @scale_words;
		my $mask_name = '';
		if ($grid_include ne '')
			{
			$mask_name = &qt_get_mask($grid_include);
			$maskt_name = &qt_get_maskt($grid_include);
			}
		if ($grid_exclude ne '')
			{
			$mask_name = &qt_get_mask($grid_exclude);
			$maskt_name = &qt_get_maskt($grid_exclude);
			}
		&debug ("Including mask $mask_name");
		my (@mask) = split(/$array_sep/,$resp{$mask_name});
		my (@maskt) = split(/$array_sep/,$resp{$maskt_name});
		my $i = 0;
		my $j = 0;
		foreach (@mask)
			{
			$g_show[$i] = 0;
			$scale_words[$i] = $maskt[$i]; 			#$loc_options[$i] ;
			if (($mask[$i] && ($grid_include ne ''))
			|| ((!$mask[$i]) && ($grid_exclude ne '')))
				{
				&debug("Including [$my_scale_words[$i]] ($maskt[$i]) nsel=$nsel");
#				$scale_words[$j++] = $maskt[$i]; 			#$loc_options[$i] ;
				$g_show[$i] = 1;
				$nsel++;
				}
			$i++;
			}
		$scale = ($scale < 0) ? -(@scale_words) : @scale_words;
        if ($random_scale)      # Randomise scale
            {
            my $got = 0;
            my $gix = 0;
            my @flag_list = ();
            my @new_list = ();
            while ($got <= $#scale_words)
                {
                my $n = int(rand($#scale_words)+0.5);
                $n = $#scale_words if ($n > $#scale_words);
                if ($flag_list[$n] == 0)
                    {
                    $flag_list[$n] = 1;
                    $new_list[$gix++] = $scale_words[$n];
                    $got++;
                    }
                }
            @scale_words = @new_list;
            &qt_update_mask_opens("scale$q_no",@scale_words);
            }
		}
	&endsub("nsel=$nsel");
	$nsel;
	}
	
# 
# Check to see if we need to have options to show this question type
#
sub need_options
	{
	my $qt = shift;
	my $ans = 1;
	my $masked = (($mask_include ne '') || ($mask_exclude ne ''));
	$ans = 0 if ((($qt == QTYPE_WRITTEN) && !$masked)		# Can now mask out written q's, but only if a +mask_include or +mask_exclude option is present
	|| ($qt == QTYPE_INSTRUCT)
	|| ($qt == QTYPE_CODE)
	|| ($qt == QTYPE_PERL_CODE)
	|| ($qt == QTYPE_CLUSTER)
	|| ($qt == QTYPE_EVAL)	);
	$ans;
	}
	
# 
# Check to see if we need to have grid options to show this question type
#
sub need_grid
	{
	my $qt = shift;
	my $ans = 0;
	$ans = 1 if (($qt == QTYPE_GRID)
	|| ($qt == QTYPE_SLIDER)
	|| ($qt == QTYPE_GRID_MULTI)
	|| ($qt == QTYPE_GRID_PULLDOWN)
	|| ($qt == QTYPE_GRID_TEXT)
	|| ($qt == QTYPE_GRID_NUMBER) );
	$ans;
	}
	
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Get the next question
#	
sub qt_get_q
	{
	&subtrace($q_no);
	undef $focus_control;
	$redirect = '';
	$tabix = 1;
	my $Aresult = 1;
	my $ql = '';
	my $back2 = &input('BACK2');
	$back2 =~ s/^\s+//;		# Netscape 4.7 gives us spaces
	if ($back2 ne '')		# Are we being asked to go back ?
		{
# 
# We are being asked to go back: Look for this set of questions in the list, 
# and see where we are.
#
		my $currq = &input('q_labs');
#		if ($currq eq $jump_index[0])			# Are we at the beginning already ?
#			{
#			}
#		else
#			{
			for (my $ix=0;$ix<=$#jump_index;$ix++)	# Scan the list (starting at the second, because we cannot go before the first Q
				{
				if ($currq eq $jump_index[$ix])
					{
					if (($ix == 0) && ($login_page ne ''))
						{
						$ix = 1 ;			# Force ourselves to the same place
						$back2 = subst($login_page);
						$redirect = <<MSG;
<META HTTP-EQUIV="Refresh" CONTENT="0; URL=$back2">
Page moved permanently. The browser will automatically re-direct you.
If nothing happens, please click <A HREF="$back2">here</A><BR>
MSG
						&add2body($redirect);
						}
					$ql = $jump_index[$ix-1];		# Grab the previous one in the list and use that
	#				alert("Found $ql");
					last;
					}
				}
#			}
		alert(qq{Cannot find Question '$currq' in index}) if ($ql eq '');
		if ($ql =~ /^(\w+)\.(\w+)/i)	# If it is a question range, pull out the first one
			{
			$ql = uc($1);
			}
		}
# I have no idea why this line was here:
#	my @files = grep(/T$resp{seqno}/,readdir(DDIR));
	$ql = uc(&input('jump_to')) if ($ql eq '');
#	$ql = uc(&input('q_label')) if ($ql eq '');
	&debug("jump_to=$ql");
	if ($ql ne '')
		{
		&input('q_no');				# Make sure it doesn't come in as an external
		&input('q_labs');			# Make sure it doesn't come in as an external
		if ($ql =~ /FIRST/i)
			{
			$gotoq = 0;
			}
		elsif ($ql =~ /last/i)
			{
			debug("LASTQ=".$resp{'lastq'}.", numq=$numq");
			if ($resp{'lastq'} >= $numq)
				{
				$gotoq = 0;
				}
			else
				{
				$gotoq = $resp{'lastq'}-1;
				}
			}
		else
			{
			$gotoq = &goto_qlab($ql);	# Look for it then
			}
		debug("Going to $ql [$gotoq]");
		$q_no = $gotoq;
		}
# Look at skip pattern :-
	elsif ($q_no >= $numq)
		{
		return 0;
		}
	elsif ($q_no > 0)
		{
		if ($qtype == QTYPE_MULTI)
			{
	    	my @ans = split(/$array_sep/,get_data($q,$q_no,$qlab));
    		my $n = 0; 	
	    	for (my $ix=0;$ix<=$#skips;$ix++)
	    		{
	    		if ($ans[$ix])
	    			{
					if (($skips[$ix] == '') || ($skips[$ix] == '0'))	
			    		{
			    		}
			    	elsif ($skips[$ix] == -1)
			    		{
				    	&debug ("IX=$ix");
						&debug ("Terminating from Q$q_no");
			    		$n = -1;
			    		last;
			    		}
			    	else
			    		{
			    		&debug ("IX=$ix");
						&debug ("Skipping from Q$q_no to Q$skips[$ix]");
			    		$n = $skips[$ix];
			    		}
			    	}
	    		}
	    	if ($n == -1)
	    		{
				&endsub(-1);
	    		return -1;
	    		}
	    	elsif ($n == 0)
	    		{
	    		$q_no = &nextq; 
	    		}
	    	else
	    		{
	    		$q_no = $n;
	    		}
			}
		elsif (($qtype == QTYPE_ONE_ONLY) || ($qtype == QTYPE_YESNO))
			{
	    	my $ix = get_data($q,$q_no,$qlab);
	    	&debug ("IX=$ix");
			&debug ("Skipping from Q$q_no to Q$skips[$ix]");
			if (($skips[$ix] == '') || ($skips[$ix] == '0'))	
	    		{
	    		$q_no = &nextq; 
	    		}
	    	elsif ($skips[$ix] == -1)
	    		{
				&endsub(-1);
	    		return -1;
	    		}
	    	else
	    		{
	    		$q_no = $skips[$ix];
	    		}
			}
		else
			{
    		$q_no = &nextq; 
    		}
		}
	else
		{
   		$q_no = &nextq; 
#		$q_no++;
		}
# Output the stuff we need :-
	$realq = '';
	$start_q_no = $q_no;		# Save this
	$qcnt = 0;
	my @labels = ();
	my $stop = 0;
	$skip_found = 0;		###### if ($one_at_a_time == 1);		# Perhaps we did find an evaluator, but I don't think it matters yet, as we haven't output anything yet !
	
	$block_size = $input{show_all} if ($input{show_all} ne '');		# Special request to show all questions (should be just for testing)
	while (!$skip_found && ($qcnt < $block_size) && ($q_no <= $numq))
		{
		$stop = 0 if ($input{show_all} ne '');
		$Aresult = &qt_dispatch($stop);			# The parameter 1 means stop when you reach an evaluator
		if ($Aresult != 1)
			{
			&endsub($Aresult);
			return $Aresult;
			}
		$prompt = &subst($prompt);
		for (my $k = 0; $k <= $#skips;$k++)		# Look for skippies...
			{
			if (($skips[$k] ne '0') && ($skips[$k] ne ''))
				{
				$skip_found = 1;
				}
			}
		my $n = &do_masking('presentation');
		if (($n == 0) && &need_options($qtype)) 		# Have we been masked out ?
			{
			&debug("Masked out");
			$skip_found = 0;
			$q_no++;
			next;
			}
		$n = &grid_include;
		if (($n == 0) && &need_grid($qtype)) 		# Have we been masked out ?
			{
			&debug("Grid Masked out");
			$skip_found = 0;
			$q_no++;
			next;
			}
		elsif ($autoselect ne '')									# Automated selection ? - no need to ask the question
			{
			if (!$stop)
				{
				&debug("autoselect=$autoselect");
				$skip_found = 0;
				&do_auto($autoselect);
				$q_no++;
				}
			next;
			}
		$stop = 1;								# Stop on eval/code for subsequent dispatches
		if (($qtype != QTYPE_PERL_CODE) && ($qtype != QTYPE_CODE) && ($qtype != QTYPE_EVAL))
			{
			$realq = $q_no if ($realq eq '');		# Record the first real question we put out
			&add2body(&emit_q(1));
# ??? I am not sure where $code comes from at this point... 
			my $pusher = ($code ne '') ? $qlab : '';
			$pusher = '' if (($qtype == QTYPE_INSTRUCT) || ($qtype == QTYPE_CLUSTER));
			push(@labels,$pusher);
			$qcnt++;
			}
		last if ($external ne '');					# Force externals to drop
		if ((!$skip_found && ($qcnt < $block_size)) && ($one_at_a_time == 0))
			{
			$q_no++;
			}
    	last if ($Aresult != 1);
    	last if ($one_at_a_time == 1);
		}
	$q_no = $numq if ($q_no > $numq);		# Make sure we don't fall off the end !
	if ($one_at_a_time == 0)
		{
   		my $valcode = "";
#   		$valcode .= qq{alert("Calling subs $qcnt")\n};
		if ($no_validation ne '1')
			{
	   		for (my $i=0;$i<$qcnt;$i++)
	   			{
	   			if ($labels[$i] ne '')
	   				{
		   			if ($margin_notes)
		   				{
		   				my $errmsg = subst_errmsg($sysmsg{ERRSTR_E28});
		   				$valcode .= qq{\tif (document.q.rf_$labels[$i].checked && document.q.dk_$labels[$i].checked)\n};
		   				$valcode .= qq{\t\t\{\n\t\talert("$qlab. $errmsg");\n\t\treturn false;\n\t\t\}\n};
		   				$valcode .= qq{\tif (!document.q.rf_$labels[$i].checked && !document.q.dk_$labels[$i].checked)\n};
		   				$valcode .= qq{\t\t\{\n};
				   		$valcode .= qq{\t\tif (!QValid_$i()) return false;\n};
				   		$valcode .= qq{\t\tif (Can_Proceed_$i()) return true;\n};
				   		$valcode .= "\t\t}\n";
		   				}
		   			else
		   				{
				   		$valcode .= qq{	if (!QValid_$i()) return false;\n};
				   		}
				   	}
	   			}
	   		foreach my $method (sort keys %extra_js_methods)
	   			{
	   			$method .= "()" if (!($method =~ /\(/));
		   		$valcode .= "\tif (!$method) return false;\n";
				}
			}
		if ($buttons ne '0')
			{
			if ($ENV{HTTP_USER_AGENT} =~ /opera/i)
				{
				$valcode .= <<QVALID;
// Disable the current onclick handler on the submit button
	document.q.btn_submit.onclick=new Function('');	
	document.q.onsubmit=new Function('return reset_submit_button();');
QVALID
				my $reset_code = <<RESET;
//if (confirm("You have submitted this page once already, but if you are sure you wish to submit again, click OK"))
//	{
//	document.q.btn_submit.value = "$sysmsg{BTN_NEXT}";
//	document.q.onsubmit=new Function("return mysubmit();");
//	alert('Button is re-enabled');
	return true;
//	}
//else
//	return false;
RESET
		   		&add_script("reset_submit_button","JavaScript",$reset_code);
				my $uni_submit = subst_errmsg($sysmsg{BTN_SUBMITTING});
				$valcode .= <<QVALID;
//
// OK, we have passed all the checks and are about to allow the form to be submitted. 
// So we gray it out to make sure it cannot be clicked again
//
	if (document.getElementById('status'))
		document.getElementById('status').innerHTML = "$uni_submit";
//	document.q.btn_submit.value = "$uni_submit";
QVALID
		   		}
		   	else
		   		{
				my $uni_submit = subst_errmsg($sysmsg{BTN_SUBMITTING});
				$valcode .= <<QVALID;
//
// OK, we have passed all the checks and are about to allow the form to be submitted. 
// So we gray it out to make sure it cannot be clicked again
//
	if (document.getElementById('status'))
		document.getElementById('status').innerHTML = "$uni_submit";
//	document.q.btn_submit.disabled = true;
QVALID
				}
			}
		$valcode .= qq{	return true;\n};
   		&add_script("QValid","JavaScript",$valcode);
   		}
	&endsub($Aresult);
	return $Aresult;
  	}
  	
sub get_q_no
	{
	&subtrace('qet_q_no');
	my $result = $q_no;
	if ($q_no eq '')
		{
		my $gotoq = 0;
		my $ql = uc(&input('q_label'));
		if ($ql ne '')
			{
			&input('q_no');				# Make sure it doesn't come in as an external
			if ($ql =~ /FIRST/i)
				{
				$gotoq = 0;
				}
			elsif ($ql =~ /last/i)
				{
				$gotoq = $resp{lastq}-1;
				if ($resp{lastq} =~ /^\d+$/)	# All numbers ?
					{
					if ($resp{lastq} >= $numq)
						{
						$gotoq = $numq;
						}
					else
						{
#						$gotoq = 0;
#						alert("A thousand pardons O Illustrious One ! You have been to the end of the interview already, so I am opening it at the beginnning again.",1);
						}
					}
				}
			else
				{
				$gotoq = &goto_qlab($ql)-1;	# Look for it then
				}
			debug("Going to $ql [$gotoq]");
			$start_q_no = $gotoq;
			$q_no = $gotoq;
			}
#		if ($gotoq > 0)
#			{
#			$start_q_no = $gotoq;
#			$q_no = $gotoq;
#			}
		else
			{
			if ($use_q_labs)
				{
				my $buf = &input('q_labs');
				my @qq = split(/\./,$buf);
				if ($#qq == -1)
					{
					my $buf2 = &input('q_no');		# Try the old way...
					if ($buf2 eq '')
						{
						#&add2body("Warning: Could not get q_labs from [$buf]");
						}
					else
						{
						my @qq = split(/\./,$buf2);
						&add2body("Warning: Could not get q_no from [$buf2]") if ($#qq == -1);
						if ($#qq == 0)
							{
							$result = $qq[0];
							$start_q_no = $qq[0];
							}
						else
							{
							$result = $qq[1];
							$start_q_no = $qq[0];
							}
						}
					}
				elsif ($#qq == 0)
					{
					$result = &goto_qlab($qq[0]);
					$start_q_no = &goto_qlab($qq[0]);
					}
				else
					{
					$result = &goto_qlab($qq[1]);
					$start_q_no = &goto_qlab($qq[0]);
					}
				}
			else
				{
				my $buf = &input('q_no');
				my @qq = split(/\./,$buf);
				&add2body("Warning: Could not get q_no from [$buf]") if ($#qq == -1);
				if ($#qq == 0)
					{
					$result = $qq[0];
					$start_q_no = $qq[0];
					}
				else
					{
					$result = $qq[1];
					$start_q_no = $qq[0];
					}
				}
			}
		$result = $start_q_no if ($result < $start_q_no);		# Be a little defensive and avoid a paradox
		&debug("questions = $start_q_no to $result");
		}
	&endsub($result);
	$result;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Output the standard header - used by go.pl
#
sub qt_Header
	{
	&subtrace('qt_Header');
	$resp{'survey_id'} = &input('survey_id');
	$resp{'score'} = &input('score');
	$resp{seqno} = &input('seqno');
	$resp{tnum} = &input('tnum');
	if ($resp{seqno} eq '')
		{
		$resp{seqno} = $cookies{$survey_id} if ($do_cookies);			# Try to get seq no from cookie
		if ($resp{seqno} eq '')
			{
			$resp{seqno} = $seqno;					# Try to get seq no from ip address
			}
		}
	$resp{'token'} = &input('token') if ($resp{'token'} eq '');
	$resp{'agent'} = $ENV{'HTTP_USER_AGENT'};
	if ($resp{seqno} eq '')
		{
		$resp{seqno} = &qt_new($resp{'survey_id'});
		}
	else
		{
		$tfile = '';
		$dfile = "D$resp{seqno}.pl";	
		$dfile .= "z" if ($gz);
		if ($use_tnum)
			{
			$tfile = "T$resp{seqno}.$resp{tnum}.pl";
			$tfile .= "z" if ($gz);
			&debug("I want file: $tfile");
			if (!-f "$data_dir/$tfile")
				{
				&debug("Can't find file: $data_dir/$tfile, reverting to normal D file: $data_dir/$dfile");
				$tfile = $dfile;
				}
			&qt_read_data("$data_dir/$tfile");
			$resp{tnum}++;
			$tfile = "T$resp{seqno}.$resp{tnum}.pl";	# Update the filename to be saved now
			}
		else
			{
			&qt_read_data("$data_dir/$dfile");
			$resp{tnum} = 1 if ($use_tnum);
			}
		}
	$q_no = &get_q_no;
	$thisq = $q_no;

	if ($do_cookies)
		{
		print "Set-Cookie: $survey_id=$seqno;\n" if ($cookies{$survey_id} eq '');
		}
# It's a good idea to put out an official DTD, so IE doesn't go anal on us :)
	#print qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">\n<HTML>\n};
	print qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">\n};
	print "<html" . $html_alignment . ">\n";
	&debug("Starting at Q $thisq");
	&add2hdr(&subst("<TITLE>$my_company : $survey_name ($resp{seqno}/$thisq) </TITLE>"));
	&add2hdr(qt_mymeta());
	&add_stylesheet;
	my $s = qq{try {
				return 'localStorage' in window && window['localStorage'] !== null;
			} catch (e) {
				return false;
				}
			};
	&add_script("locals","JavaScript",$s);
	$s = qq{
			var d = new Date();
			document.cookie = cookie_name+"=0;expires=" + d.toGMTString() + ";path=/;domain=$ENV{SERVER_NAME};";
		};
	&add_script("del_cookie(cookie_name)","JavaScript",$s);
	$s = qq{
			var cs = document.cookie ;
			if (cs.length != 0) {
				var cv = cs.match ( '(^|;)[\s]*' + cookie_name + '=([^;]*)' );
				return decodeURIComponent ( cv[2] ) ;
			}
			return '' ;
		};
	&add_script("get_cookie(cookie_name)","JavaScript",$s);
	$s = qq{
			if (locals){
				document.q.session.value = (typeof localStorage["session$survey_id"] != 'undefined') ? localStorage["session$survey_id"]: '';
			} else {
				document.q.session.value = get_cookie("session$survey_id");
			}
			var mynow = new Number(new Date); 	// Perl epoch is in seconds, this is milliseconds
			if (!document.q.session.value) {
				if (locals){
					localStorage["session$survey_id"] = mynow;
					document.q.session.value = localStorage["session$survey_id"];
				} else {
					document.cookie = "session$survey_id="+mynow+"; path=/; domain=$ENV{SERVER_NAME};" ;
					document.q.session.value = get_cookie("session$survey_id");
				}
			}
//			document.q.btn_submit.value = '$sysmsg{BTN_NEXT}';	//this is where the problem is with external html files and language encoding in the next button!!
		};
	&add_script("loadme","JavaScript",$s);
	if ($form)
		{
		&add2body(qq{<FORM name="q" id="q" method="$http_method" ACTION="${vhost}${virtual_cgi_bin}$go.$extension"});
		&add2body(qq{		ENCTYPE="x-www-form-encoded"});
			
	   	if ($one_at_a_time == 1)
	   		{
	   		&add2body(qq{		OnSubmit="return QValid()"});
	   		}
	   	else
	   		{
	   		&add2body(qq{		OnSubmit="return QValid()"});
	   		}
		&add2body("> \n");
		}
	&endsub;
	}

sub add_stylesheet
	{
	my $stylefile = qq{$ENV{DOCUMENT_ROOT}/$survey_id/$theme.css};
	my $styleurl = qq{/$survey_id/$style.css};
	my $themefile = qq{$ENV{DOCUMENT_ROOT}/themes/$theme/style.css};
	my $compatfile = qq{../triton/$survey_id/html/style.css};
#	print "<br>theme=$theme, themefile=$themefile<br>\n";
	my $themeconfig = qq{$ENV{DOCUMENT_ROOT}/themes/$theme/config.js};
	if (-f $themeconfig) {
		&add2hdr(qq{<script type="text/javascript" src="/cgi-mr/getjs.pl?extras=/themes/$theme/config.js"></script>\n});
	}
	if ($theme && -f $themefile)
		{
		$stylefile = $themefile;
		$styleurl = qq{/themes/$theme/style.css};
		}
	if ((-f $stylefile) && !$inline_stylesheet)
		{
		&add2hdr(qq{<link rel="stylesheet" href="$styleurl">});
		}
	elsif ((-f $compatfile) && !$inline_stylesheet)
		{
		&add2hdr(qq{<link rel="stylesheet" href="../$survey_id/style.css">});
		}		
	else
		{
		&add2hdr(qq{<style type="text/css">\n});
		if (-f $stylefile)
			{
			open SFILE,"<$stylefile" || my_die "Error $! reading stylesheet file: $stylefile\n";
			while (<SFILE>)
				{
				chomp;
				s/\r//g;
				&add2hdr("$_");
				}
			close SFILE;
			}
		else
			{
#
# We couldn't find a style sheet, so we provide it inline as a fallback
#
			&add2hdr(<<STYLE);
.prompt {  font-family: Arial, Helvetica, sans-serif; font-size: 10pt; font-style: normal; font-weight: normal; }
.heading { background-color: darkslateblue; color:yellow; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: bold; }
.options { background-color: lightblue; color:#000000; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: normal; }
.options2 { background-color: LIGHTSTEELBLUE; color:#000000; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: normal; }
.instruction {  font-family: Arial, Helvetica, sans-serif; font-style: italic; font-size: 9pt; }
.default {  }
.links {  font-family: Arial, Helvetica, sans-serif; font-size: 9pt}
.body { background-color: white; font-family: Arial, Helvetica, sans-serif; font-size: 9pt}
.mytable { background-color: darkslateblue; color:yellow; font-family: Arial, Helvetica, sans-serif; font-size: 9pt; font-style: normal; font-weight: bold; border-width:2px; border-color:darkslateblue; border-style:solid;}
.notes { color:blue; background-color: #FFFFFF; font-family: Arial, Helvetica, sans-serif; font-size: 7pt}
STYLE
			}
		&add2hdr(qq{</style>\n});
		}
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Output the standard meta tags (including the NOSCRIPT tweak)
#
sub qt_mymeta {
#
# Despite it actually working, putting a META tag inside a NOSCRIPT tag is not standards compliant.
#
	my $pid_name = ($url_pid) ? qq{ext_$url_pid} : 'ext_PID';
	my $ext_pid = $resp{$pid_name};
	my $myargs;
	$myargs .= qq{?survey_id=$survey_id};
	$myargs .= qq{&amp;language=$language} if ($language);
	$myargs .= qq{&amp;pid=$ext_pid} if ($ext_pid);
	$myargs .= qq{&amp;seqno=$input{seqno}} if ($input{seqno});

	qq{
	<META NAME="Company" CONTENT="Triton Information Technology">
	<META NAME="Author" CONTENT="Mike King">
	<META NAME="Copyright" CONTENT="Triton Information Technology 1995-2011">
<!-- ICRA no longer exists, but leave it in place in case of residual support -->
	<meta http-equiv="pics-label" content='(pics-1.1 "http://www.icra.org/ratingsv02.html" comment "ICRAonline v2.0" l gen true for "http://$ENV{SERVER_NAME}/"  r (nz 1 vz 1 lz 1 oz 1 cz 1) "http://www.rsac.org/ratingsv01.html" l gen true for "http://$ENV{SERVER_NAME}/"  r (n 0 s 0 v 0 l 0))'>
<!-- This line prevents the browser from caching the page: -->
	<META HTTP-EQUIV="Expires" CONTENT="0">
<!-- Technically this is not standards compliant, but it does seem to work in all browsers. Not worth fighting it, can't find a compliant solution :( -->
	<NOscRipt>
	<meta http-equiv="Refresh" content="0;URL=/cgi-mr/noscript.pl$myargs" />
	</NOscript>	
	};
}

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Output the standard header - used by token.pl
#
sub qt_token_header
	{
	&subtrace('qt_token_header');
	$resp{'agent'} = $ENV{'HTTP_USER_AGENT'};

	&debug("Starting at Q $thisq");
	&add2hdr(&subst("<TITLE>$my_company : $survey_name ($resp{seqno}/$thisq) </TITLE>"));
	&add2hdr(qt_mymeta());
	&add_stylesheet;
	
	if ($form)
		{
		&add2body(qq{<FORM name="q" id="q" method="$http_method" ACTION="${vhost}${virtual_cgi_bin}$go.$extension"
			ENCTYPE="x-www-form-encoded"
			OnSubmit="return QValid()" >\n});
		}
	&endsub;
	}
	
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Output the NEW standard footer
#
sub new_footer{
	&subtrace('new_footer');

	my $ffields = shift;
	my $stuff;
#
# Get the footer template from the theme...
#
	my $tfile = "../htthemes/$theme/footer.html";
	if ($theme && -f $tfile) {
		my $dref = parse_template($tfile);
#		use Data::Dumper;
#		my $buf = Dumper $dref;
#		$buf =~ s/\n/<br>\n/ig;
#		print $buf;
#
# Put more data into the hash
#
		$$dref{form}{fields} = $ffields;
		$$dref{form}{buttons} = '' if ($buttons eq '0');
		$$dref{perc} = 55;
		$$dref{theme} = $theme;
		$$dref{perc} = '?';
		my $q = ($#sequences != -1) ? $resp{'random_ix'} : $q_no;
		$$dref{perc} = int(100*$q/$numq) if ($numq > 0);
		$$dref{perc} = 100 if ($$dref{perc} > 100);
		$$dref{percimg} = int($$dref{perc}/5)*5;
		$$dref{btn_submitting} = subst_errmsg($sysmsg{BTN_SUBMITTING});
		$$dref{btn_next} = subst_errmsg($sysmsg{BTN_NEXT});
		$$dref{btn_back} = subst_errmsg($sysmsg{BTN_BACK});
		$$dref{seqno} = $resp{seqno};

#
# Now run it through the template meister
#
		my $template = $$dref{footer};
		$stuff = processit($template,$dref);
	}
	&endsub;
	$stuff;
}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Output the standard footer
#
sub qt_Footer
	{
	&subtrace('qt_Footer');
	&debug("showing Q$q_no");
#
# Work out the necessary hidden fields to go on the form...
#
	my $formfields = join("\n",
			qq{<INPUT NAME="survey_id" TYPE="hidden" VALUE="$resp{'survey_id'}">},
			qq{<INPUT NAME="seqno" TYPE="hidden" VALUE="$resp{seqno}">},
			qq{<INPUT NAME="jump_to" TYPE="hidden" VALUE="">},
			qq{<INPUT NAME="session" TYPE="hidden" VALUE="">},
			);
	if ($q_no) {
		my $sq_no = ($realq eq '') ? $start_q_no : $realq;
		my $q_labs = &goto_q_no($q_no);
		$q_labs =~ s/^q//i;
		my $qq = $q_no if (!$use_q_labs);
		$qq = "${sq_no}.$q_no" if (!$use_q_labs);			# This is a patch to get around a weakness in TReplay.exe
		if (!$one_at_a_time && ($sq_no != $q_no)) {
			$qq = "${sq_no}.$q_no" if (!$use_q_labs);
			$q_labs = &goto_q_no($sq_no).".".&goto_q_no($q_no);
			$q_labs =~ s/^q(\w+)\.q(\w+)/$1.$2/i;
		}
		if ($use_q_labs) {
			$formfields .= qq{\n<INPUT NAME="q_labs" TYPE="hidden" VALUE="$q_labs">\n};
		} else {
			$formfields .= qq{\n<INPUT NAME="q_no" TYPE="hidden" VALUE="$qq">\n};
		}
	}
	my $ftr = new_footer($formfields);
	if ($ftr) {
		add2body($ftr);
	} else {

	if ($do_footer)
		{
		if ($custom_footer ne '')
			{
			&add2body(&subst($custom_footer));
			}
		else
			{
			&add2body(<<XX);
<HR><small><IMG SRC="$virtual_root/pix/logosmall.gif" ALIGN="MIDDLE">
\&copy; Triton Information Technology 1995-2011. For more information,
please contact <A HREF="mailto:$mailto\?subject=$survey_id" TABINDEX="-1">$mailname</A></small><BR>
XX
			}
		}
	if ($form)
		{
		&add2body($formfields);
		if ($mike)
			{
			my $tnum = ".$resp{tnum}" if ($use_tnum);
			my $ro = ($read_only) ? qq{<FONT COLOR="RED"><B>READ ONLY MODE: CHANGES WILL not BE SAVED $resp{ext_fam_no}/$resp{ext_id_no} v$resp{ver}</B></FONT>} : '';
			if ($custom_footer ne "default") {
                &add2body("");
            } elsif ($use_q_labs)
                 {
               &add2body(qq{<FONT size="-2">$survey_id $resp{seqno}$tnum &nbsp; $q_labs $ro</FONT>});
                 }
           else
                {
                &add2body(qq{<FONT size="-2">$survey_id $resp{seqno}$tnum &nbsp; $qq $ro</FONT>});
               }
            }
# Outputting auto-save and sticky leave page
		&add2body(qq{
<span class="status">
<div id="response" onclick="toggleoutput();"></div>
<!-- <iframe  src="/blank.html" width="600" height="200" id="output" style="visibility:hidden;">
Ajax output will appear here...
</iframe> -->
</span>
}) if ($extras{dojo}{enabled});
		}
		&add2body("</FORM>");
		}
	if ($extras{jquery}{modules}{spellchecker} && $extras{jquery}{enabled}) {		# Using the jquery spellchecker?
		&add2body(qq{
<!--[if IE]>
<!-- Version 1.3 is old already, but it does work :) -->
	<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.3/jquery.min.js"></script>
	<script type="text/javascript" src="/spell/js/jquery.spellchecker.js"></script>
	<script type="text/javascript">
var src;
function checkit(e){
		e.preventDefault();
		src = this.id;
		src = src.replace("btn", "");
		\$("#ok"+src).html("Requesting spellcheck...");

		\$("#"+src)
		.spellchecker({
			url: "/spell/checkspelling.php",
			lang: "en",
			engine: "google",
			suggestBoxPosition: "above"
		})
		.spellchecker("check", function(result){

			// spell checker has finished checking words
			\$("#ok"+src).html("Click on words above for spelling suggestions ");				

			// if result is true then there are no badly spelt words
			if (result) {
				\$("#ok"+src).html("OK");				
			}
		});
	return false;
	}
// Use JQuery rather than Dojo for the ready thingy
	\$(document).ready(function() {
	  jquerySetup();
	  });
	</script>
<![endif]-->
});
	}
	if (($external ne '') && (!$revisit || $dive_in))
		{
#
# I am hoping this doesn't mess with anything else
# For diagnostic interviews, if we are trying to jump to a question that cannot be found, we default to the first question of
# the survey. Normally the first question is the start page, so dumping the javascript error message before externals makes sure 
# that the error message is displayed to the user properly.
#
# If a javascript method is mentioned, assume that it replaces the regular QValid method
# (Because IE takes the last declaration of multiple js subs, but other browsers do not)
        if ($javascript ne '')
            {
            $javascript = &subst($javascript);
            my ($jsfile,$method) = ($1,$2) if ($javascript =~ /^(.*?),(.*)/);
            $method .= "()" if (!($method =~ /\(/));
            &add_script("QValid","JavaScript","return $method;");
            }
		&dump_scripts;				
#
		&dump_external($external);
		print "$redirect\n";
		dump_body(new_footer());
#		print qq{ </FORM> <br><br><br><br> </BODY> };
		print qq{</HTML>};
		}
	else
		{
		&dump_html;
		}
	&endsub;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Output the "You have been terminated" message
#
sub qt_Terminate
	{
	&subtrace('qt_Terminate');
	&add2body("<H1>");
	if ($terminate_url ne '')
		{
		if ($terminate_url =~ /<%\w+%>/)
			{
			$terminate_url =~ /<%(\w+)%>/;
			my $thing = $1;
			my $newthing = get_thing($thing);
			&debug("<%$thing%> ==> $newthing\n");
			$terminate_url =~ s/<%$thing%>/$newthing/gi;
			}
		if ($terminate_url ne '')
			{
			my $ext_pid = "";
			if ($url_pid) {
				$pid_name = "ext_" . $url_pid;
				$ext_pid = $resp{$pid_name};
				$terminate_url .= $ext_pid;
			} elsif ($emit_url_vars) {
				my $append_url = "";
				my @url_vars = split(',', $emit_url_vars);
				foreach my $url_var(@url_vars) {
					$url_varname = "ext_" . $url_var;
					$url_var_data = $resp{$url_varname};
					$append_url .= "&" . $url_var . "=" . $url_var_data;
				}
				$terminate_url .= $append_url;
			}
			&add_script("","JavaScript",qq{parent.location = "$terminate_url";});
			}
		}
	&add2body(qq{<IMG SRC="$virtual_root/$resp{'survey_id'}/banner.gif" BORDER="0" ALIGN="MIDDLE">\n}) if ($do_logo);
	&add2body(qq{
<h1>Thank you !</H1>\n
Thank you for participating in our survey.
At the present time we have filled our quotas.<BR>
We appreciate the time that you have taken to give us your opinions.<BR>
<a href="$return_url" TABINDEX="-1"> Click here to go to the $return_name</a><BR><BR>
});
	&endsub;
	}

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Output the Thank you message
#
sub qt_Thankyou
	{
	&subtrace('qt_Thankyou');
	my $statusfile = qq{$qt_root/$resp{survey_id}/html/status$resp{status}.htm};
	if ($input{finish} eq '0')
		{
		$external = '';
		&serve_page('notyet.htm');
		}
	elsif (-f $statusfile)
		{
		$external = '';
		&serve_page(qq{status$resp{status}.htm});
		}
	elsif ($thankyou_url eq 'thanks.htm')
		{
		$external = '';
		&serve_page($thankyou_url);
		}
	else
		{
		&add2body("<H1>");
		$external = '';
		while ($thankyou_url =~ /<%\w+%>/)
			{
			$thankyou_url =~ /<%(\w+)%>/;
			my $thing = $1;
			my $newthing = get_thing($thing);
			&debug("<%$thing%> ==> $newthing\n");
			$thankyou_url =~ s/<%$thing%>/$newthing/gi;
			}
		&debug("Thankyou_url=$thankyou_url\n");
#		if ($thankyou_url ne '')
			{
			my $ext_pid = "";
			if ($url_pid) {
				$pid_name = "ext_" . $url_pid;
				$ext_pid = $resp{$pid_name};
				$thankyou_url .= $ext_pid;
			} elsif ($emit_url_vars) {
				my $append_url = "";
				my @url_vars = split(',', $emit_url_vars);
				foreach my $url_var(@url_vars) {
					$url_varname = "ext_" . $url_var;
					$url_var_data = $resp{$url_varname};
					$append_url .= "&" . $url_var . "=" . $url_var_data;
				}
			}
				$terminate_url .= $append_url;
			&add_script("","JavaScript",qq{parent.location = "$thankyou_url";});
			}
		&add2body(qq{<IMG SRC="$virtual_root/$resp{'survey_id'}/banner.gif" BORDER="0" ALIGN="MIDDLE">\n}) if ($do_logo);
		&add2body("Thank you very much !</H1>\n");
		&add2body("Thank you for participating in our survey. ");
		&add2body("We appreciate the time that you have taken to give us your opinions.<BR>\n");
		&add2body(qq{<a href="$return_url" TABINDEX="-1"> Click here to go to the $return_name</a><BR><BR>\n});
		}
	&endsub;
	}
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# btn_by
#
sub btn_by
	{
	&subtrace();
	my $perc = shift;
	my $btns = '';
	$btns .= qq{<HR class="divider">} if (!$tight);
	$btns .= <<BTNTABLE;
<br>
<TABLE BORDER="0" WIDTH="100%" class="buttontable">
<TR>
BTNTABLE
# BACK Button
	my $back2 = $input{BACK2};
	$back2 =~ s/^\s+//;		# Netscape 4.7 gives us spaces
	my $page1 = (($input{q_labs} eq '') || (($input{q_labs} eq $jump_index[1]) && ($back2 ne '')));
	$page1 = 0 if ($page1 && ($login_page ne ''));
	my $clrback2 = '';
	if (($show_back_button) && !$page1)
		{
		$clrback2 = qq{document.q.BACK2.value="";};
		$btns .= <<BACKBTN; 
		<TD width="90"> 
		<INPUT class="button" TYPE="BUTTON" VALUE="$sysmsg{BTN_BACK}" tabindex="-1"  alt="BACK" onclick="document.q.BACK2.value='1';document.q.submit()">
		<INPUT TYPE="HIDDEN" name="BACK2">
		</TD>
BACKBTN
		}
	if ((($simple_back_button) || ($ENV{HTTP_USER_AGENT} =~ /qt embedded/i)) && !$page1)
		{
		$btns .= <<BACKBTN; 
		<TD width="90"> 
		<INPUT class="input" TYPE="BUTTON" VALUE="$sysmsg{BTN_BACK}" tabindex="-1"  alt="BACK" onclick="window.history.go(-1)">

		</TD>
BACKBTN
		}
	my $tix = qq{TABINDEX="$tabix"};
	$tix = '' if ($tabix == 1);
	$btns .= <<NEXTBTN;
		<TD width="90">
		<INPUT class="button" TYPE="SUBMIT" VALUE="$sysmsg{BTN_NEXT}" $tix onclick='document.q.jump_to.value="";$clrback2 document.q.onsubmit=new Function("return mysubmit()")' id="btn_submit" name="btn_submit">
		</TD>
NEXTBTN
# Section Buttons
    %major_sections = %adm_major_sections if (%adm_major_sections && ($adm_ipaddr{$ENV{REMOTE_ADDR}} || $resp{navigate}));
	if ((@major_sections) || (%major_sections))
		{
		my $lastn = -1;
		my @the_sections = (sort keys %major_sections);
		@the_sections = @major_sections if (@major_sections);
		foreach my $section (@the_sections)
			{
#			my $tix = qq{TABINDEX="$tabix"};
			my $tix = qq{TABINDEX="-1"};
			my $sname = $section;
			my $ssect = $section;
			my $slab = "BEGIN$ssect";
			$ssect = $major_sections{$section} if (%major_sections);
			my $gotoq = &goto_qlab($slab);
			if ($gotoq > 0)
				{
				$tix = '' if ($tabix == 1);	
				my $cls = ($q_no > $gotoq) ? "heading" : "options";
				my $uni_submit = subst_errmsg($sysmsg{BTN_SUBMITTING});
				my $disableme = 'rmsubmithandler()';	# qq{this.disabled=true};
				$btns .= <<NEXTBTN;
	<TD> 
	<BUTTON type="SUBMIT" onclick="document.q.onsubmit='';document.q.jump_to.value='$slab';if (document.getElementById('status')) document.getElementById('status').innerHTML='$uni_submit';$disableme;document.q.submit();" $tix class="$cls">$ssect</button>
	</TD>
NEXTBTN
				$lastn = $gotoq;
				}
			}
		}	
	$btns .= "<TD valign='top'>".&get_progress_html($perc)."</TD>" if ($no_progress_bar eq '');
	if (!$tight || ($custom_footer ne '')) {
		if ($custom_footer eq "none" || $custom_footer eq "0") {
			$btns .= &subst("");
		}
		if ($custom_footer eq "mobile") {
				$btns .= &subst(qq{</TR>\n</table>\n<table width=100%>\n<tr>\n<td align='right'>\n<INPUT TYPE="hidden" NAME="action" value=""><INPUT TYPE="BUTTON" NAME="btn_close" ID="btn_close" value="CLOSE" class="btn_close" onclick="document.q.action.value='';if (confirm('Are you sure you want to abort this interview?')) {document.q.action.value='dnf';this.value='Closing...';document.q.submit();}"><br><br>\n</td>\n});
		} 
		if ($custom_footer ne "" && $custom_footer ne "default" && $custom_footer ne "0" && $custom_footer ne "mobile" && $custom_footer ne "none") {
			$btns .= &subst("</TR>\n</table>\n<table width=100% class='custom_footer'>\n<tr>".$custom_footer);
		}
		#if ($custom_footer eq "") {
		#	$btns .= &subst("<TD align='right'>".$custom_footer."</TD>");
		#} 
		if ($custom_footer eq "default") {
		my $link = '';
		my $end_link = '';
		if ($no_click_triton eq '')
			{
			$link = qq{<A HREF="http://www.market-research.com/" TABINDEX="-1" target="triton_home">};
			$end_link = "</A>";
			}
		$btns .= <<NEXTBTN3 if (!$no_copy);
</TR>\n</table>\n<table width=100% class='custom_footer'>\n<tr><TD><P><FONT size="-2" face="Arial, Helvetica, sans-serif">&nbsp;Survey provided by
        $link $my_company $end_link $for_client
        <br>&nbsp;&copy; Triton Information Technology 1995-2011 all rights reserved.
        &nbsp;&nbsp;<A HREF="mailto:$mailto\?subject=$survey_id" TABINDEX="-1">
        email : $mailname</a></FONT><BR></P>
	</TD>
NEXTBTN3
			}
		}
	$btns .= qq{<TD ><IMG SRC="/$survey_id/$logo"></TD>} if ($logo ne '');
# Refused Button
	if ($can_refuse)
		{
		my $uni_submit = subst_errmsg($sysmsg{BTN_SUBMITTING});
		my $disableme = 'rmsubmithandler()';	# qq{this.disabled=true};
		my $onclick = qq{if (confirm('Do you really want to continue without answering every question?')) {document.q.onsubmit='';if (document.getElementById('status')) document.getElementById('status').innerHTML='$uni_submit';$disableme;document.q.submit();} else return false;};
		$btns .= <<REFUSEBTN;
	<TD align=right> 
	<INPUT TYPE="SUBMIT" VALUE="$sysmsg{BTN_REFUSED}" TABINDEX="-1" onclick="$onclick">
	</TD>
REFUSEBTN
		}
	$btns .= "</TR></TABLE>";
	&endsub;
	$btns;	
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
#
sub get_buttons
	{
	&subtrace('get_buttons');
	my $perc = '?';
	my $q = ($#sequences != -1) ? $resp{'random_ix'} : $q_no;
	$perc = int(100*$q/$numq) if ($numq > 0);
	$perc = 100 if ($perc > 100);
	my $result = '';
	if ($buttons ne '0')
		{
		my $tfile = "../htthemes/$theme/footer.html";
		$result .= &btn_by($perc) if (($form) && !($theme && -f $tfile));
		}
	&endsub;
	$result;
	}
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
#
# Output the standard buttons
#
sub qt_Buttons
	{
	&subtrace('qt_buttons');
	if ($qtype > 0)
		{
		my $btns = &get_buttons;
		&add2body($btns);
		}
	else
		{
		&add2body(qq{<BR><BR>Return to <A HREF="../../demos.html">$my_company Demonstration</A> page<BR>\n});
		}
	&endsub;
	}

#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
#
# Theme support....
#
# Themes provide an easier way of theming a survey than the previous method.
# The assumption is that the module htthemes contains a set of themes, each in it's 
# own folder, such as htthemes/default, or whatever name you care to give it.
#
our %theme_fallback = (		# This is a fallback in case the elements don't exist
					spacer1 => qq{&nbsp;},
					spacer5 => qq{&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;},
					spacer10 => qq{&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;},
					);
sub theme_part {
	my $partname = shift;
	my $fallback = $theme_fallback{$partname};
#	add2body("theme_part request($partname), fallback = [$fallback]");
	if ($theme) {
		my $partfile = qq{$theme/$partname.png};	# Look in theme
		return qq{<IMG src="/themes/$partfile">} if (-f "../htthemes/$partfile");
		my $partfile = qq{default/$partname.png};	# Look in default
		return qq{<IMG src="/themes/$partfile">} if (-f "../htthemes/$partfile");
	}
	return $fallback;
}

#
# This one reads a template file into a hash, looking for tags like this:
# <script type="text/template" id="xxx"> ... </script>
# The contents of the script are placed in a hash, using the id (xxx in this example)
# As the key. A reference to the has is returned
#
sub parse_template(){
	my $tfile = shift;
	my $buf = read_file($tfile) || die "Error $! reading file $tfile\n";
	my @lines = split(/\n/,$buf);
	my %parts;
	my $current = '';
	foreach my $line (@lines) {
		$line =~ s/\r//g;
		next if ($line =~ /^\s*\/\//i);		# Skip comments
		next if ($line =~ /^\s*#/i);		# Skip comments
		next if ($line =~ /^\s*$/i);		# Skip blank lines
		if (($line =~ /<script/i) && ($line =~ /type=["']*text\/template["']*/i)) {		# Must be a script with type=text/template
			$current = $1 if ($line =~ /id=["']*([\w\.]+)["']*/i);
#			print "Starting part: $current\n";
		} elsif ($line =~ /<\/script>/i) {
			$current = '';
		} else {
			if (!$current) {
# This just appears in the apache error_log if turned on
#				warn "No current part to receive line: $line\n" ;
			} else {
				push @{$parts{$current}},$line;			# Just stack it up
#				print "$line<br>\n";
			}
		}
	}
# 
# Now copy the elements we have found, and copy them into a hash.
# Also work out any structural references (eg sysmsg.MSG21)
#
	my $pref;
	foreach my $part (sort keys %parts) {
		my $val = join("\n",@{$parts{$part}})."\n";
		my $bit = substr($val,0,10)."...";
		if ($part =~ /\./) {
			my @bits = split(/\./,$part);

#			my $p = join(",",@bits);
#			print "bits=$#bits, $p\n";

			$bit =~ s/[<>]//ig;
			if ($#bits == 1) {
				$$pref{$bits[0]}{$bits[1]} = $val;
#				print "Added $bits[0].$bits[1] $bit<br>\n";
			}
			if ($#bits == 2) {
				$$pref{$bits[0]}{$bits[1]}{$bits[2]} = $val;
#				print "Added $bits[0].$bits[1].$bits[2] $bit<br>\n";
			}
		} else {
			$$pref{$part} = $val;
#			print "Added $part $bit<br>\n";
		}
	}
	$pref;
}
#
# This one processes a template string (first parameter), using the supplied 
# data hash reference (second parameter). Allows replacement tags to be nested 
# once only, although it could be changed to a deeper level if needed.
#
sub processit() {
	my $tmpl = shift;
	my $data = shift;
	my $out;
	my $tt = Template->new({
			INTERPOLATE  => 1,
			}) || die "$Template::ERROR\n";
#	print "Processing <br>\n";
	$tt->process(\$tmpl,$data,\$out);
	my $loop = 1;
	while ($out =~ /\[\%/){
#		print "Re-processing $loop\n";
		$tmpl = $out;
		$out = '';
		$tt->process(\$tmpl,$data,\$out);
		$loop++;
		last if ($loop>20);		# Prevent a deadly spin loop
	}
	$out;
}

#
# This is required to live in the perl library
#
1;
