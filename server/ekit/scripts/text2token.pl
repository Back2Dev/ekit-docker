#!/usr/bin/perl
## $Id: text2token.pl,v 1.26 2011-08-10 01:39:46 triton Exp $
# Text2token.pl
#
# THIS IS THE ONE TO USE !!!! ALL OTHERS ARE IMITATIONS OR SUPERCEDED.
#
# Two output files are produced:XXX101_xlate.txt
# and XXX101_tokenised.txt
#
# The first file is intended to be read into a spreadsheet. 
# 	There are 3 columns, labelled: Where,Original,Translated
# 		Where: is an identifier telling us where the text lives in the survey
# 		Original: is the original English text for reference
# 		Translated: is a space for the text when it has been translated
# - Open the file in excel, select the last 2 columns (Original,Translated)
#	From the Excel menu select Format->Cells, click on the alignment tab, set
#  	the vertical alignment to "Top" and check the "Wrap text" option. This 
#	will wrap the text nicely in the cells, and enlarge the cells as needed.
# - Save the file in Excel format, and email it off for translation. 
#	The translators should fill in one spreadsheet for each language to be 
# 	translated.
# - Once you get the files back, you will need to follow the steps in 
#	token2text.pl
#
# By Mike King
#
#	$Header: /au/apps/alltriton/cvs/scripts/text2token.pl,v 1.26 2011-08-10 01:39:46 triton Exp $  	Logfile, Revision, Date, Author
# 
#----------------------------------------------------------------------
#
use Data::Dumper;
use Getopt::Long;							#perl2exe
require 'TPerl/qt-libdb.pl';
my @unwanted = ('', qw[qtype javascript varlabel varname var skip mask_include mask_exclude mask_reset mask_add mask_copy mask_update grid_include grid_exclude survey_name window_title thankyou_url true_flags terminate_url selectvar display_label survey_id]);
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
#
#----------------------------------------------------------------------
#

my $were_known = 0;
my $todo = 0;
our $qt_root;
our $relative_root;
our %known = ();
our ($opt_d,$opt_h,$opt_v,$opt_language,$opt_trim,$opt_toggle,$opt_prime,$opt_varlabel,$opt_br,$opt_nodb);
our $skip = 0;
my %already = ();
our @stack = ();
our ($dbt);

# Subroutines start here
sub die_usage
	{
	my $msg = shift;
	print qq{\nError: $msg\n\n} if ($msg ne '');
	print <<USAGE;
Usage: $0 [-v] [-t] [-h]  AAA101
	-h			Display help
	-v			Display version no
	-d			Debug/trace mode
	-nodb		Do not use the existing language DB (Ignore previously translated items, skips working with the language DB)
	-language=XX where XX is country code, eg ES/FR/DE/IT etc
		(assumes this survey ID ends in EN (English version), but not when using -toggle option)
	-toggle		Use new method of toggling language
	-prime	 	Prime an AAA101_en.txt file from AIR101.txt
USAGE
	print "\tAAA101 Survey ID\n";
	exit 0;
	}

sub cleanit
	{
	my $thing = shift;
	$thing =~ s/<br>/\\n/ig unless $opt_br;
	$thing =~ s/^"//g;			# Leading quotes are evil
	$thing =~ s/"$//g;			# Trailing quotes are evil
	$thing =~ s/\\n/\\n /g;
	$thing =~ s/^\s*(.*?)\s*$/$1/;
	if ($opt_trim)				# Jan uses trailing \n's for formatting reasons.
		{
		$thing =~ s/^\\n//g;		
		$thing =~ s/\s*\\n*\s*\\n\s*$//g;
		$thing =~ s/\\n$//g;		# Catch the double CRLF at the end
		}	
	$thing;
	}

sub process_lib
	{
	while (<LIBFILE>)
		{
		chomp;
		s/\r//g;
		my @bits = split /\t/;
		next if ($bits[1] =~ /Original/i);					# Skip first line
		next if ($bits[2] =~ /do not translate/i);			# SKIP garbage entries
		next if (($bits[1] eq '') || ($bits[2] eq ''));		# Skip non-translated things
		$known{cleanit($bits[1])} = cleanit($bits[2]);
		}
	}

sub dump_stack
	{
	if ($#stack ne -1)
		{
		if (!$skip)
			{
			for (my $i=0;$i<=$#stack;$i++)
				{
				my ($prefix,$key,$text,$xlated) = split(/\t/,$stack[$i]);
				my $line = $stack[$i];
				$line =~ s/^.*?\t//;
				print XL "$line";
				}
			# print XL "\n";
			}
		if ($opt_toggle)
			{
			for (my $i=0;$i<=$#stack;$i++)
				{
				my ($prefix,$key,$text,$junk) = split(/\t/,$stack[$i]);
				$key =~ s/\./_/g;
				$key = uc($key);		# Make sure it is upper case
				$text =~ s/{/\\{/g;
				$text =~ s/}/\\}/g;
# ??? Not sure if it should be the resp hash we use here, but I guess it's an easy way to carry things around
				print EN "\$resp\{_T$key\} = qq\{$text\};\n";
				}
			print EN "\n";
			}
		@stack = ();
		$skip = 0;
		}
	}

sub prime_me
	{
	my $src = shift;
	my $target = shift;
	print "Priming file: $target\n";
	open(SRC,"<$src") || die "Error $! while opening file: $src\n";
	open(TARGET,">$target") || die "Error $! while creating file: $target\n";
	while (<SRC>)
		{
		chomp;
		s/\r//g;
		print TARGET "$_\n";
		print TARGET "+varlabel=$2\n"
			if ((/^\s*Q\s+(\w+)\.*\s*(.*)$/i) && ($opt_varlabel)); 	# Question line ?
		print TARGET "	+varlabel=$1\n"
			if ((/^\s*A\s*(.*)$/i) && ($opt_varlabel)); 	# Attribute line ?
		print TARGET "	+varlabel=$1\n"
			if ((/^\s*G\s*(.*)$/i) && ($opt_varlabel)); 	# Grid line ?
		}
	close SRC;
	close TARGET;
	}
#-----------------------------------------------------------
#
# Main line start here
#
#-----------------------------------------------------------

GetOptions (
			help 	=> \$opt_h,
			debug 	=> \$opt_d,
			version => \$opt_v,
			trim 	=> \$opt_trim,
			toggle 	=> \$opt_toggle,
			nodb	=> \$opt_nodb,
			varlabel=> \$opt_varlabel,
			'br!'	=> \$opt_br,
			prime => \$opt_prime,
			'language=s' => \$opt_language,
			) or die_usage ( "Bad command line options" );
$dbt = 1 if ($opt_d);
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/text2token.pl,v 1.26 2011-08-10 01:39:46 triton Exp $'."\n";
	exit 0;
	}

#
# Check the parameter (The Survey ID)
#
our $survey_id = $ARGV[0];
&die_usage("Missing survey id") if ($survey_id eq '');
&die_usage("Source survey id should end with EN") if (!($survey_id =~ /EN$/i) && (!$opt_toggle));

our $opt_language = uc($opt_language);
die_usage("Missing 2 character language code") if ($opt_language eq '');
die_usage("Language codes should be 2 characters") if (length($opt_language) != 2);
#die_usage("I don't think you really want to translate to English, you dick wad!") if ($opt_language eq 'EN');

my $target_sid = $survey_id;
$target_sid =~ s/EN$/$opt_language/i if (!$opt_toggle);

&get_root;

my $input_file = "$relative_root${qt_root}/$survey_id/config/$survey_id.txt";
$input_file = "$relative_root${qt_root}/$survey_id/config/${survey_id}_en.txt" if ($opt_toggle);

die "Cannot find directory $relative_root${qt_root}/${survey_id}\n" if (! -d "$relative_root${qt_root}/${survey_id}") ;

# Make sure the target directory exists:
force_dir("$relative_root${qt_root}/$target_sid/config");
my $xl_file = "$relative_root${qt_root}/$target_sid/config/${target_sid}_xlate.txt";
$xl_file = "$relative_root${qt_root}/$target_sid/config/${target_sid}_xlate_$opt_language.txt" if ($opt_toggle);
my $toggle_file = "$relative_root${qt_root}/$target_sid/config/${target_sid}.txt";
my $en_file = "$relative_root${qt_root}/$target_sid/config/lang_.pl";
my $lib_file = "$relative_root${qt_root}/cfg/translation-lib-$opt_language.txt";

if ($opt_d) {
	print "input file: $input_file\n xl_file: $xl_file\n toggle_file: $toggle_file\n en_file: $en_file\n libfile: $lib_file\n\n";	
}

#
# One more check, to be smart...
#
if ((-f $toggle_file) && (!-f $input_file) && $opt_toggle)
	{
	if ($opt_prime)
		{
		prime_me($toggle_file,$input_file);
		}
	else
		{
		die_usage(<<MSG);
It appears that you have not yet primed this survey for translation. 
The English version of the survey needs to be created 
as $input_file. I can 
do this for you if you specify the -prime option: basically this 
copies $toggle_file to $input_file, 
and (optionally) inserts +varlabel statements on all the questions. 
MSG
		}
	}
open(SRC,"<$input_file") || die "Cannot open file $input_file for input\n";
print "IF: $input_file\n\n";

unless ($opt_nodb) {
	open(LIBFILE,"<$lib_file") || print "No translation library file found ($lib_file)\n";
	process_lib;# if (LIBFILE);
	close(LIBFILE);
}
print "Get '$xl_file' translated\n";
open(XL,">$xl_file") || die "Cannot open file $xl_file for output\n";
print XL "Where\tOriginal\tTranslated\n \t \t \n";
if ($opt_toggle)
	{
	open(TOGGLE,">$toggle_file") || die "Cannot open file $toggle_file for output\n";
	open(EN,">$en_file") || die "Cannot open file $en_file for output\n";
	my $when = localtime();
	print EN qq{#!/usr/bin/perl\n# File generated: $when\n# Script containing English version of strings\n#\n};
	}
#
# Output the file header
#
my $when = localtime();
my $done = 0;
my %bits = ();

#
# Now read through the file and do the replacements
#

# We have #+no_xlate=QA0000 in the source so that things like this
# <B>$$language_switch </B><br><br><center>$$service_summary</center>
# are not translated.
#
my $no_xlate_hints = {};  

my $icnt = 0;
my ($n, $g, $p);
$n = $g = $p = 1;
my $ql = '';
my $qtype = '';
while (<SRC>)
	{
	chomp;
	s/\r//g;
	my $key = '';
	my $prefix = '';
	my $text = '';
	if (/^\s*Q\s+([\.\w]+)\s+(.*)$/i) 	# Question line ?
		{
		&dump_stack;
		$ql = $1;
		$text = $2;
		$ql =~ s/\.$//g;				# Trim off any trailing dots...
		$key = "Q$ql";
		$n = $g = $p = 1;			# New question resets all indices
		
		
#			print XL "#Q$key-------------------------------\n";
		$prefix = "Q $ql";
		$prefix .= "." if ($opt_toggle);
		}
	elsif (/^\s*Q\s+([\.\w]+)\.(.*)$/i) 	# 'broken' question line.
		{
			print "Question $1 will not be translated.  Insert a space after '$1'\n";
			# print "Here 1=$1 2=$2\n";
		}
	elsif (/^\s*\+qtype\s*=\s*(.*?)\s*$/i)		# Question type ?
		{
		$qtype = $1;
		$skip = 1 if (grep(/^$qtype$/i,(qw[code eval perl_code repeater])));
		}
	elsif (/^\s*A\s+(.*)/i)		# Attribute line ?
		{
		$text = $1;
		$key = "Q${ql}.$n";
#		print XL "#A$n $key, $bits{$key}\n";
		$prefix = "  A";
		$n++;
		}
	elsif (/^\s*G\s+(.*)/i) 	# Grid line ?
		{
		$key = "Q${ql}.G$g";
		$text = $1;
		$prefix ="  G";
		$g++;
		}
	elsif (/^\s*P\s+(.*)/i) 	# Pulldown line ?
		{
		$key = "Q${ql}.P$p";
		$text = $1;
#			print XL "PKEY=$key $bits{$key}\n";
		$prefix ="  P";
#			print XL "P $ql. $bits{$key}\n";
		$p++;
		}
	elsif (/^\s*\+dk\s*=\s*(.*)/i) 	# dk ?
		{
		$key = "Q${ql}.DK";
		$prefix = "  +dk=";
		$text = $1;
#			print XL "+dk=$bits{$key}\n";
		}
	elsif (/^\s*\+instr\s*=\s*(.*)/i) 	# Instruction ?
		{
		$key = "Q${ql}.I";
		$prefix = "  +instr=";
		$text = $1;
#			print XL "+instr=$bits{$key}\n";
		}
	elsif (/^\s*\+middle\s*=\s*(.*)/i) 	# left anchor ?
		{
		$key = "Q${ql}.GM";
		$prefix = "  +middle=";
		$text = $1;
		}
	elsif (/^\s*\+left_word\s*=\s*(.*)/i) 	# left anchor ?
		{
		$key = "Q${ql}.GL";
		$prefix = "  +left_word=";
		$text = $1;
		}
	elsif (/^\s*\+right_word\s*=\s*(.*)/i) 	# right anchor ?
		{
		$key = "Q${ql}.GR";
		$prefix = "  +right_word=";
		$text = $1;
		}
	elsif (/^\s*\+([\w_]+)\s*=\s*(.*)/i) 	# some other qualifier ?
		{
		$key = $1;
		$prefix = "  +$1=";
		$text = $2;
		$key = '' if (grep(/^$key$/i,@unwanted));
		unless ((length($text) > 3) && ($text =~ /\D/))
			{
			$key = '';
			}
		}
	my $lookup = 1;
	$lookup=0 if  $text =~ /^\$\$\w+$/;
	$lookup=0 if $text =~ /^\[%\s*\w+\s*%\]$/;
	$lookup = 0 if $no_xlate_hints->{uc($key)};
	if (($key ne '') && !$skip && $lookup)
		{
		$text = cleanit($text);
		 #print "Here $key|$text|\n".Dumper $no_xlate_hints;
		my $newtext = '';
		$todo++;
		if ($known{$text} ne '')
			{
				# print "found '$text=$known{$text}'\n";
			$newtext = $known{$text};
			$were_known++;
			$todo--;
			}
		elsif ($already{$text} ne '')
			{
			$todo--;
			$newtext = 'DO NOT TRANSLATE - ALREADY DONE ABOVE';
			}
		$already{$text}++;
		push @stack,"$prefix\t$key\t$text\t$newtext\n";
		my $newkey = $key;
		$newkey =~ s/\./_/g;
		print TOGGLE "# $_\n";		# Print the original to help scrutability
		my $space = ($prefix =~ /=$/) ? "" : " ";
		print TOGGLE "$prefix$space\$\$T$newkey\n";
		}
	elsif ( /\s*#\s*\+no_xlate\s*=\s*(.*?)\s*$/)
		{
			my @list = split /,/,$1;
			s/^\s*(.*?)\s*$/$1/ foreach @list;
			$no_xlate_hints->{$_}++ foreach @list;
			print TOOGLE "$_\n";
		}
	else
		{print TOGGLE "$_\n";}
	$icnt++;
	}
&dump_stack;
close(SRC);
close(XL);
if ($opt_toggle)
	{
	print TOGGLE "# End of file\n";
	close(TOGGLE);
	print EN "1;	# End of file\n";
	close(EN);
	}
print "I looked up $were_known things already, and there are $todo left to translate\n";

#dump some basic statistics to a file
my $stats = "Total Lines: $icnt\nTotal seen: $were_known\nTranslation needed: $todo\n";
my $statsFile = "$relative_root${qt_root}/$target_sid/config/${target_sid}.stats";
open (FILE, ">$statsFile") || die "Trying to create the statistics file. Unable to open to write stats file: $statsFile $!";
print FILE "$stats";
close FILE;

1;
