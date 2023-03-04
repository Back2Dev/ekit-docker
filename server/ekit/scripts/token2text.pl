#!/usr/bin/perl
## $Id: token2text.pl,v 1.28 2011-08-30 02:40:55 triton Exp $
# Text2token.pl
#
# THIS IS THE REAL McCoy ~!!!
#
# Once you get the files back (see text2token.pl), you will need to follow this procedure:
# 1) Open the spreadsheets, and save the file as a tab-separated text file:
# 	C:\triton\TRI118DE\config\TRI118DE_xlate.txt
# 	(This will replace the original file you produced in the first part).
# 2) Run the command:
# 	TOKEN2TEXT TRI118DE TRI118EN
# This will produce a file: 
# 	C:\triton\TRI118DE\config\TRI118DE.txt
# 	With the text merged in. 
# 3) Run up the designer, create 
# 	C:\triton\TRI118DE\config\TRI118DE.TSF
# 	And import the Text file above.
# 4) Generate the Newton files, or deploy to ASP.
#
# By Mike King
#
#	$Header: /au/apps/alltriton/cvs/scripts/token2text.pl,v 1.28 2011-08-30 02:40:55 triton Exp $  	Logfile, Revision, Date, Author
#	$Log: token2text.pl,v $
#	Revision 1.28  2011-08-30 02:40:55  triton
#	Finally fixed utf-8 problem
#
#	Revision 1.27  2011-08-30 00:23:22  triton
#	Polishing
#
#	Revision 1.26  2011-08-30 00:01:54  triton
#	Tweaked vertscale
#
#	Revision 1.25  2011-08-29 00:59:10  triton
#	Give usage if no command line parameters
#
#	Revision 1.24  2011-08-29 00:39:16  triton
#	Create a script to generate vertical scale files
#
#	Revision 1.23  2011-08-28 23:43:26  triton
#	Add rank qtype
#
#	Revision 1.22  2010-10-14 20:53:35  triton
#	adding support to ignore the existing lanugage DB.
#
#	Revision 1.21  2008-06-27 02:23:06  triton
#	Trim qlabel first
#
#	Revision 1.20  2008-06-02 01:23:03  triton
#	Be tolerant of case changes
#
#	Revision 1.19  2006/11/03 04:07:05  triton
#	Don't do substitutions in files (asking for trouble), will do in config files/templates
#	
#	Revision 1.18  2006/08/17 02:12:14  triton
#	Filter double quotes
#	
#	Revision 1.17  2006/07/05 12:54:03  triton
#	token2text now reads the xlation library for another chance.
#	text2token ignores "DO NOT TRANSLATE..." entries
#	
#	Revision 1.16  2005/05/19 08:57:52  triton
#	Make a pass thru the file to eliminate code q's, which clutter the error list
#	
#	Revision 1.15  2005/03/29 04:56:12  triton
#	Added window_title and survey_name
#	
#	Revision 1.14  2005/03/23 02:32:32  triton
#	Made the aliens hash find things without a Q in front
#	
#	Revision 1.13  2005/03/23 01:55:49  triton
#	Made it lookup CUSTOM_FOOTER AND THANKYOU_MESSAGE
#	
#	Revision 1.12  2005/03/09 01:12:55  triton
#	Fixed up a few things that should be translated, and that should not..
#	
#	Revision 1.11  2004/11/16 21:45:13  triton
#	Adding support for dots in the question number
#	
#	Revision 1.10  2004/11/11 05:41:23  triton
#	*** empty log message ***
#	
#	Revision 1.9  2004/10/01 12:45:32  triton
#	Add thankyou_url to unwanted list
#	
#	Revision 1.8  2004/09/30 11:42:17  triton
#	Make resp keys upper case,
#	+varlabels generation is optional
#	
#	Revision 1.7  2004/09/28 06:21:55  triton
#	Commented out an incomplete die statement
#	
#	Revision 1.6  2004/09/27 05:19:21  triton
#	Tweak to allow for +varlabel and +varname
#	
#	Revision 1.5  2004/09/26 23:51:45  triton
#	Put in toggle support
#	
#	Revision 1.4  2004/08/11 14:18:00  triton
#	Pull in by position if text does not match exactly
#	
#	Revision 1.3  2004/07/16 07:41:04  triton
#	Added -language and -charset cmd line options
#	
#	Revision 1.2  2004/07/15 05:02:41  triton
#	Deal with +instr as well
#	
#	Revision 1.1  2004/04/21 00:58:44  triton
#	moved token/text stuff to scripts dir
#	
#	Revision 2.0  2004/03/29 02:21:21  triton
#	We move library files to TPerl, scripts to scripts, remove some crap to the 'Attic' and move to version 2.0 for whats left over.
#	
#	Revision 1.3  2003/08/03 02:34:42  triton
#	Added comments
#	
#	Revision 1.2  2003/05/26 22:40:51  triton
#	Some serious work on this one too, to bring it up to data and make it compatible.
#	
#	Revision 1.1  2003/01/21 05:11:16  triton
#	I think these need to be checked in
#	
#	Revision 1.2  2002/08/15 13:06:39  triton
#	no message
#	
#	Revision 1.1  2002/04/10 12:38:40  mikkel
#	v1 - merge translated text back (paired with survey2token.pl)
#	
#	Revision 1.1  2001/06/06 05:40:55  king
#	no message
#	   	File history, RCS format
# 
#----------------------------------------------------------------------
#
use Getopt::Long;
use HTML::Entities;
require 'TPerl/qt-libdb.pl';
#
#----------------------------------------------------------------------
#
my @unwanted = ('', qw[qtype javascript varlabel varname var skip mask_include mask_exclude mask_reset mask_add mask_copy mask_update grid_include grid_exclude thankyou_url survey_id]);
my @qtypes = ();
$qtypes[$QTYPE_NUMBER]		= 'number';
$qtypes[$QTYPE_MULTI]		= 'multi';
$qtypes[$QTYPE_ONE_ONLY]	= 'single';
$qtypes[$QTYPE_YESNO]		= 'yesno';
$qtypes[$QTYPE_WRITTEN]		= 'written';
$qtypes[$QTYPE_PERCENT]		= 'percent';
$qtypes[$QTYPE_INSTRUCT]	= 'instruction';
$qtypes[$QTYPE_EVAL]		= 'evaluator';
$qtypes[$QTYPE_DOLLAR]		= 'dollar';
$qtypes[$QTYPE_RATING]		= 'rating';
$qtypes[$QTYPE_UNKNOWN]		= 'single';
$qtypes[$QTYPE_FIRSTM]		= 'firstmention';
$qtypes[$QTYPE_COMPARE]		= 'compare';
$qtypes[$QTYPE_GRID]		= 'grid';
$qtypes[$QTYPE_OPENS]		= 'text';
use strict;

our ($opt_language,$opt_charset,$opt_help,$opt_version,$opt_d,$opt_toggle,$opt_t,$opt_trim,$opt_br,$opt_nodb);
our %known = ();
our %knownlc = ();
#
# Subroutines start here
#
sub die_usage
	{
	my $msg = shift;
	print "Error: $msg\n" if ($msg ne '');
	print <<USAGE;
Usage: $0 [-version] [-trace] [-help] [-toggle] -language=XX [XXX101DE] XXX101EN
	-help		Display help
	-version	Display version no
	-debug		Debug mode
	-trace		Trace mode
	-nodb		Do not use the existing language DB (Ignore previously translated items, skips working with the language DB)
	-language	Mandatory 2 character language code, ES=Spanish, FR=French, DE=German und zo weiter....
	-toggle		use new toggle method for translation
	XXX101DE	Survey ID (target) [optional if using toggle method]
	XXX101EN	Survey ID (source) 
USAGE
	exit 0;
	}

sub process_lib
	{
	while (<LIBFILE>)
		{
		chomp;
		s/\r//g;
		my @bits = split /\t/;
		next if ($bits[1] =~ /^Original/i);					# Skip first line
		next if ($bits[2] =~ /do not translate/i);			# SKIP garbage entries
		next if (($bits[1] eq '') || ($bits[2] eq ''));		# Skip non-translated things
		# print "Here $bits[0] -- $bits[1]\n";
		$known{cleanit($bits[1])} = cleanit($bits[2]);
		$knownlc{lc(cleanit($bits[1]))} = cleanit($bits[2]);
		}
	}

sub cleanit
	{
	my $thing = shift;
	$thing =~ s/<br>/\\n/ig unless $opt_br;
	$thing =~ s/^"//g;			# Leading quotes are evil
	$thing =~ s/"$//g;			# Trailing quotes are evil
	$thing =~ s/\\n/\\n /g;
	if ($opt_trim)				# Jan uses trailing \n's for formatting reasons.
		{
		$thing =~ s/^\\n//g;		
		$thing =~ s/\s*\\n*\s*\\n\s*$//g;
		$thing =~ s/\\n$//g;		# Catch the double CRLF at the end
		}	
	$thing;
	}


#-----------------------------------------------------------
#
# Main line start here
#
#-----------------------------------------------------------
GetOptions (
	'language:s'=>\$opt_language,
	'charset:s'=>\$opt_charset,
	help => \$opt_help,
	trim 	=> \$opt_trim,
	'br!'	=> \$opt_br,
	toggle => \$opt_toggle,
	version => \$opt_version,
	debug => \$opt_d,
	trace => \$opt_t,
	nodb => \$opt_nodb,
) or die_usage();

if ($opt_help)
	{
	&die_usage;
	}
if ($opt_version)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/token2text.pl,v 1.28 2011-08-30 02:40:55 triton Exp $'."\n";
	exit 0;
	}
our $qt_root;
our $relative_root;

#
# Check the parameter (The Survey ID)
#
our $survey_id = shift;
our $src_survey_id = shift;
$src_survey_id = $survey_id if ($src_survey_id eq '') && $opt_toggle;
die_usage("You must specify a target language id for translation\n") if ($opt_language eq '');
$opt_language = uc($opt_language);

&get_root;

# Input files:
my $input_file = "$relative_root${qt_root}/$src_survey_id/config/$src_survey_id.txt";
$input_file = "$relative_root${qt_root}/$src_survey_id/config/${src_survey_id}_en.txt" if ($opt_toggle);
my $xl_file = "$relative_root${qt_root}/$survey_id/config/${survey_id}_xlate.txt";
$xl_file = "$relative_root${qt_root}/$survey_id/config/${survey_id}_xlate_$opt_language.txt" if ($opt_toggle);
my $lib_file = "$relative_root${qt_root}/cfg/translation-lib-$opt_language.txt";
# Output files:
my $output_file = "$relative_root${qt_root}/$survey_id/config/$survey_id.txt";
my $missing_file = "$relative_root${qt_root}/$survey_id/config/${survey_id}_missing.txt";
my $lang_file = "$relative_root${qt_root}/$survey_id/config/lang_$opt_language.pl";

&die_usage("Missing target survey ID") if ($survey_id eq '');
&die_usage("Missing source survey ID") if ($src_survey_id eq '');

die "Cannot find directory $relative_root${qt_root}/${survey_id}\n" if (! -d "$relative_root${qt_root}/${survey_id}") ;

unless ($opt_nodb) {
	open(LIBFILE,"<$lib_file") || print "No translation library file found ($lib_file)\n";
	process_lib;# if (LIBFILE);
	close(LIBFILE);
}

open(SRC,"<$input_file") || die "Cannot open file $input_file for input\n";
print "Reading xl_file '$xl_file'\n";
open(XL,"<$xl_file") || die "Cannot open file $xl_file for input\n";

if ($opt_toggle)
	{
	open(LANG,">$lang_file") || die "Cannot open file $lang_file for output\n";
	my $when = localtime();
	print LANG qq{#!/usr/bin/perl\n# File generated: $when\n# Script containing $opt_language version of strings (charset=$opt_charset)\n#\n};
	}
else
	{
	print "Creating output file '$output_file'\n";
	open(OUT,">$output_file") || die "Cannot open file $output_file for output\n";}
	open(MISS,">$missing_file") || die "Cannot open file $missing_file for output\n";
#
# Run through the XL file and pull in the stuff:
#
our %english = ();
our %alien = ();
our %direct = ();
our %directlc = ();
while (<XL>)
	{
	chomp;
	s/\r//;
	my @parts = split(/\t/);
	my $key = trim(uc($parts[0]));
	if ($key ne '' && $key !~ /^Q/){
		# print "$key needs a Q\n";
		$key="Q$key";
	}
	my $en = $parts[1];
	$en =~ s/^"//;
	$en =~ s/"$//;
	$en =~ s/""/"/g;
	$en = trim($en);
	$en =~ s/\\n$//g;
	my $al = $parts[2];
	$al =~ s/^"//;
	$al =~ s/"$//;
	$al =~ s/\\n$//g;
	$al =~ s/""/"/g;
	$al = trim($al);
	next if ($parts[0] eq '');
	next if ($parts[0] =~ /where/i);
	$english{$key} = $en;
	$alien{$key} = $al;
	$direct{trim($english{$key})} = $al if (!($al =~ /^DO NOT TRANSLATE/i));
	$direct{lc(trim($english{$key}))} = $al if (!($al =~ /^DO NOT TRANSLATE/i));
	print "XL $key=$al\n" if ($opt_t);
	}
close(XL); 
#
# Output the file header
#
my $when = localtime();
my $done = 0;
my %bits = ();
#
# Now read through the file and do the replacements
#
my $icnt = 0;
my ($n,$g,$p);
$n = $g = $p = 1;
my %already = ();
my @stack = ();
my $skip = 0;
our $unsure = 0;
our @dnt_list = ();
our @eval_qs = ();
my $ql = '';

use Data::Dumper;
# print "direct=".Dumper \%direct;
# print "english=".Dumper \%english;
# print "alien=".Dumper \%alien;

my %skipq = ();
while (<SRC>)
	{
	chomp;
	s/\r//g;
	my $key = '';
	if (/^\s*Q\s+([\w\.]+)\s+(.*)$/i) 	# Question line ?
		{
		$key = $1;
		$key =~ s/\.$//;	# Trim off trailing dot
		$ql = $key;
		}
	elsif (/^\s*\+qtype\s*=\s*(.*?)\s*$/i) 	# qtype specifier ?
		{
		my $qtype = $1;		
		if (grep(/^$qtype$/i,(qw[code eval perl_code repeater])))
			{
			$skipq{$ql}++; 
			}
		}
	}
close SRC;
my $vert_script = '';
open(SRC,"<$input_file") || die "Cannot open file $input_file for input\n";
my $no_xlate_hints = {};
my %question;	# Temporary holder of question info
while (<SRC>)
	{
	chomp;
	s/\r//g;
	my $key = '';
	my $prefix = '';
	my $text = '';
	my $orig = $_;
	my $rest = '';
	if (/\s*#\s*\+no_xlate\s*=\s*(.*?)\s*$/){
		my @list = split /,/,$1;
		s/^\s*(.*?)\s*$/$1/ foreach @list;
		$no_xlate_hints->{$_}++ foreach @list;
	}
	if (/^\s*Q\s+([\w\.]+)\s+(.*)$/i) 	# Question line ?
		{
		$key = $1;
		my $prompt = $2;
		$key =~ s/\.$//;	# Trim off trailing dot
		$ql = $key;
		$prefix = "Q ";
		print "Original=Q ($key) $prompt\n" if ($opt_t);
		my $new = lkup($key,$prompt);
		$new = $prompt if ($new eq '');
		$rest = ($opt_toggle) ? "$new" : "$key. $new";
		print "New=Q ($key) $rest\n" if ($opt_t);
		$n = $g = $p = 1;			# New question resets all indices
#		print Dumper \%question;
		if ($question{prompt} && ($question{qtype} =~ /^rank$/i))
			{
			my $cmd = qq{perl ../scripts/qt.vertscale.pl $survey_id Q$question{qlabel} -left='$question{left}' -right='$question{right}'\n};
#			print $cmd;
			if (!$vert_script){		# Is this the first vertical scale? 
				my $when = localtime;
				$vert_script = "$relative_root${qt_root}/$survey_id/config/verticals.sh";
				print "Creating vertical scale script file '$vert_script'\n";
				open(VERT,">:raw:utf8","$vert_script") || die "Cannot open file $vert_script for output\n";
				print VERT qq{#!/bin/bash\n# Script to build vertical scales for $survey_id $when\n};
				}
			print VERT $cmd;
			}
		undef %question;
		$question{prompt} = $new;
		$question{qlabel} = $ql;
		}
	elsif (/^\s*A\s+(.*)/i)		# Attribute line ?
		{
		$key = "${ql}.$n";
		$prefix = "A ";
		$rest = lkup($key,$1);
#		print "A key=$key, $rest\n";
		$n++;
		}
	elsif (/^\s*G\s+(.*)/i) 	# Grid line ?
		{
		$key = "${ql}.G$g";
		$prefix = "G ";
		$rest = lkup($key,$1);
		$question{left} = $rest if ($g == 1);
		$question{right} = $rest if ($g == 2);
		$g++;
		}
	elsif (/^\s*P\s+(.*)/i) 	# Pulldown line ?
		{
		$key = "${ql}.P$g";
		$prefix = "P ";
		$rest = lkup($key,$1);
		$p++;
		}
	elsif (/^\s*\+dk\s*=\s*(.*)/i) 	# dk ?
		{
		$key = "${ql}.DK";
		$prefix = "+dk=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+instr\s*=\s*(.*)/i) 	# instr ?
		{
		$key = "${ql}.I";
		$prefix = "+instr=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+caption\s*=\s*(.*)/i) 	# Grid caption?
		{
		$key = "${ql}.GM";
		$prefix = "+caption=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+middle\s*=\s*(.*)/i) 	# middle of grid ?
		{
		$key = "${ql}.GM";
		$prefix = "+middle=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+left_word\s*=\s*(.*)/i) 	# left anchor ?
		{
		$key = "${ql}.GL";
		$prefix = "+left_word=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+right_word\s*=\s*(.*)/i) 	# right anchor ?
		{
		$key = "${ql}.GR";
		$prefix = "+right_word=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+reminder2_subject\s*=\s*(.*)/i) 	# right anchor ?
		{
		$key = "REMINDER2_SUBJECT";
		$prefix = "+reminder2_subject=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+reminder1_subject\s*=\s*(.*)/i) 	# right anchor ?
		{
		$key = "REMINDER1_SUBJECT";
		$prefix = "+reminder1_subject=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+email_subject\s*=\s*(.*)/i) 	# right anchor ?
		{
		$key = "EMAIL_SUBJECT";
		$prefix = "+email_subject=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+window_title\s*=\s*(.*)/i) 	# right anchor ?
		{
		$key = "WINDOW_TITLE";
		$prefix = "+window_title=";
		$rest = lkup($key,$1);
		# print "k=$key p=$prefix r=$rest\n";
		}
	elsif (/^\s*\+survey_name\s*=\s*(.*)/i) 	# right anchor ?
		{
		$key = "SURVEY_NAME";
		$prefix = "+survey_name=";
		$rest = lkup($key,$1);
		# print "k=$key p=$prefix r=$rest\n";
		}
	elsif (/^\s*\+thankyou_message\s*=\s*(.*)/i) 	# right anchor ?
		{
		$key = "THANKYOU_MESSAGE";
		$prefix = "+thankyou_message=";
		$rest = lkup($key,$1);
		# print "k=$key p=$prefix r=$rest\n";
		}
	elsif (/^\s*\+custom_footer\s*=\s*(.*)/i) 	# right anchor ?
		{
		$key = "CUSTOM_FOOTER";
		$prefix = "+custom_footer=";
		$rest = lkup($key,$1);
		}
	elsif (/^\s*\+language\s*=\s*(.*)/i) 	# Language specifier ?
		{
		$prefix = "+language=";
		$rest = ($opt_language ne '') ? $opt_language : $1 ;
		}
	elsif (/^\s*\+charset\s*=\s*(.*)/i) 	# charset specifier ?
		{
		$prefix = "+charset=";
		$rest = ($opt_charset ne '') ? $opt_charset : $1 ;
		}
	elsif (/^\s*\+qtype\s*=\s*(.*?)\s*$/i) 	# qtype specifier ?
		{
		my $qtype = $1;
		push @eval_qs,"Q$ql" if (grep(/^$qtype$/i,(qw[code eval perl_code repeater])));
#		print "qtype=$qtype\n" if ($qtype =~ /^rank$/i);
		$question{qtype} = $qtype;
		}
	elsif (/^\s*\+([\w_]+)\s*=\s*(.*)/i) 	# some other qualifier ?
		{
		$key = $1;
		$prefix = "+$1=";
		$rest = $2;
		unless ((length($rest) > 3) && ($rest =~ /\D/))
			{
			$prefix = '';
			}
		}
	if ($prefix eq '')
		{
		if ($opt_toggle)
			{
			print LANG "#$orig\n";
			}
		else
			{print OUT "$orig\n";}
		}
	else
		{
		$rest =~ s/\\n/<BR>/ig; 		# Make sure stray line feeds are dealt with now
		if ($opt_toggle)
			{
			if (!grep(/^$key$/i,@unwanted))
				{
				my $q = ($prefix =~ /^\+/) ? "" : 'Q';
				$key =~ s/\./_/g;
				$key =~ s/\s+//g;
				$key = uc($key);		# Make sure it is upper case
				$rest =~ s/{/\\{/g;
				$rest =~ s/}/\\}/g;
				$rest =~ s/@/\\@/g;
				print LANG "\$resp{_T$q$key} = qq{$rest};\n";
				}
			else
				{print "UNWANTED: $key\n" if ($opt_t);}
			}
		else
			{print OUT "$prefix$rest\n";}
		}
	$icnt++;
	}
close(SRC);
if ($vert_script){
#	print qq{ ! Don't forget to generate vertical scales for rank questions with the command \nsource $vert_script\n};
	close VERT;
}


if ($opt_toggle)
	{
	print LANG "1;\n";
	close(LANG);
	}
else
	{close(OUT);}
close(MISS);
my @dnts = ();
foreach my $key (@dnt_list)
	{
	push @dnts,$key if (!grep(/^$key$/,@eval_qs));
	}
my $cnt = $#dnts+1;
#print "$survey_id Done: Not sure about $unsure, did not xlate $cnt (".join(",",@dnts).")\n";

sub lkup
	{
	my $key = "Q".uc(shift);
	my $orig = shift;
	$orig =~ s/^"//;
	$orig =~ s/"$//;
	$orig =~ s/""/"/g;
	$orig = trim($orig);
	$orig =~ s/\\n/<BR>/ig;
#	$orig =~ s/<BR>/\\n/ig;
#	$orig =~ s/\\n$//g;
	my $verdict = "[EN] ???";
	my $new = "$orig";
	# print "in lkup key=$key\n";
# 	if ($key eq 'QTHANKYOU_MESSAGE'){
# 		print "new=$new\n";
# 	}
	if ($alien{$key} ne '')
		{
		$new = $alien{$key};
		$verdict = "[?] Unsure (English=$orig)";
		}
#	print "$key: [$orig], $direct{$orig}\n";
	if ($direct{$english{$key}} ne '')		# Can I look it up by the full string indexed by key?
		{
		$new = "$direct{$english{$key}}";
		$verdict = '';
#		$verdict = "[?] Unsure";
		}
	if ($direct{$orig} ne '')				# Can I look it up by the full string in the file we are scanning ?
		{
		$verdict = "";
		$new = $direct{$orig};
		}
	if ($knownlc{lc($orig)} ne '')				# Can I look it up by the (lower case) full string from the library file ?
		{
		$verdict = "";
		$new = $knownlc{lc($orig)};
		}
	if ($known{$orig} ne '')				# Can I look it up by the full string from the library file ?
		{
		$verdict = "";
		$new = $known{$orig};
		}
	$verdict = '' if (!($new =~ /[a-z]/i));		# If no alpha chars, must be just numbers
	$unsure++ if ($verdict eq "[?] Unsure");
	$verdict = '' if ($skipq{$ql});				# Take it 'as is' if it's an eval/code etc qtype
	$verdict = '' if $no_xlate_hints->{$key};
	$verdict = '' if $orig =~ /^\$\$\w+$/;

	if ($verdict eq "[EN] ???")
		{
		push @dnt_list,$key;
		}
	if ($verdict ne '')
		{
		if ($opt_toggle)
			{print LANG "# $verdict\n";}
		else
			{print OUT "# $verdict\n";}
		print MISS join("\t",($verdict,$key,$orig,$alien{$key}))."\n";
		}
	$new;
	}
1;
