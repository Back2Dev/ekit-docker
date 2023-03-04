#!/usr/bin/perl
# $Id: mergertf.pl,v 1.4 2012-04-11 12:43:26 triton Exp $
#
# Script to merge D-file data into an RTF file
#
use strict;
use TPerl::TritonConfig qw (getConfig); 	
use Getopt::Long; 							
use Data::Dumper;

require 'TPerl/qt-libdb.pl';
#
#-----------------------------------------------------------
#
# Main line starts here
#
#-----------------------------------------------------------
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
my $array_sep = '===';
our %resp;
my (%opts,%cfg);
GetOptions (
	debug			=> \$opts{debug},
	'seqno=i'		=> \$opts{seqno},
	help			=> \$opts{h},
	version			=> \$opts{v},
	'template=s'	=> \$opts{template},
	'data=s'		=> \$opts{datafile},
	'target=s'		=> \$opts{target},
) or die_usage ('Bad Command line options');

$cfg{troot} = getConfig ('TritonRoot');
our $t=1;
#
# Gnarly little sucker that we need bcos regexp's don't work
# (ie don't return a full array) if there is no data in there at all
#
sub mysplit
    {
    my $re = shift;
    my $x = shift;

    if ($x =~ /$re$/)                   # Check at the end
        {
        my @y = split /$re/,"$x ";      # Add a space to make the split work
        $y[$#y] = '';                   # Then nuke it to cover our tracks
        @y;
        }
    else
        {
        split /$re/,$x;
        }
    }

sub notag {
	my $str = shift;
	$str =~ s/<br>/ /gi;
	$str =~ s/<.*?>//gs;
	$str =~ s/&nbsp;//ig;
	return $str;
}
sub die_usage
	{
	my $msg = shift;
	print qq{Error: $msg
Usage: $0 [-v] [-t] [-h] AAA101
	-h Display help
	-v Display version no
	-t Trace mode
	-seqno=nnn
	-template=template-file-name
	-data=data-file-name
	AAA101 Survey ID
};
	exit 0;
	}
if ($opts{h})
	{
	&die_usage;
	}
if ($opts{v})
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/mergertf.pl,v 1.4 2012-04-11 12:43:26 triton Exp $'."\n";
	exit 0;
	}
#
# Check the parameter (The Survey ID)
#
my $survey_id = shift;

my $input_file = qq{$cfg{troot}/$survey_id/templates/doctemplate.rtf};
$input_file = qq{$cfg{troot}/$survey_id/templates/$opts{template}} if ($opts{template}); # Template file specified?
$input_file = qq{$cfg{troot}/$survey_id/templates/$opts{template}} if ($opts{template} && $opts{template} =~ /^[\.\/]/); # Template includes a path?
my $output_file;
$output_file = qq{$cfg{troot}/$survey_id/doc/$opts{target}}.lc($opts{seqno}).".rtf" if ($output_file eq '');
$output_file = qq{$cfg{troot}/$survey_id/doc/$opts{target}} if ($opts{target}); # Target file specified?
$output_file = qq{$cfg{troot}/$survey_id/doc/$opts{target}} if ($opts{target} && $opts{target} =~ /^[\.\/]/); # Target includes a path?

#if ($opts{template} ne '')
#	{
#	$input_file = "$cfg{troot}/$survey_id/templates/$opts{template}_template.rtf";
#	$output_file = "$cfg{troot}/$survey_id/doc/$opts{template}_$target_name.rtf";
#	}

my $respfile = "$cfg{troot}/$survey_id/web/D$opts{seqno}.pl";
$respfile = qq{$cfg{troot}/$survey_id/web/$opts{datafile}} if ($opts{datafile}); # Data file specified?
$respfile = qq{$opts{datafile}} if ($opts{datafile} && $opts{datafile} =~ /^[\.\/]/); # Data file includes a path?

&die_usage("Missing survey_id\n")  if ($survey_id eq '');
&die_usage("Missing sequence no\n")  if ($opts{seqno} eq '' && !$opts{template});

die "Cannot find directory $cfg{troot}/${survey_id}\n" if (! -d "$cfg{troot}/${survey_id}") ;

my $data_dir = "$cfg{troot}/${survey_id}/web";
die "Cannot find data directory $data_dir\n" if (! -d "$data_dir" ) ;

my $config_dir = "$cfg{troot}/${survey_id}/config";
die "Cannot find data directory $config_dir\n" if (! -d "$config_dir" ) ;

open(IN,"<$input_file") || die "Cannot open file $input_file for input\n";

my $ag;
#
# Get the data file
#
&my_require ("$respfile",1);

# Pull in the default language file:
my $filename = "$cfg{troot}/$survey_id/config/lang_.pl";
#print "Pulling in $filename\n";
&my_require ($filename,0);

$resp{ext_language} = '';

#print Dumper \%resp;
open(OUT,">$output_file") || die "Cannot open file $output_file for output\n";
print "Wrote file: $output_file\n";
my $q_no = 1;		# Starting point
my $grix = 0;
our $qtype = 99;
our ($q,$qlab,$q_label,@scale_words,@options,$rank_grid,$others,$scale,$dk,@pulldown,);
my $prefix = '';
my $nextfix = '';
my $nreplaced = 0;
my $abort = 0;
	my @ans;
	my ($two,$data,$ix1,$ix2,@matrix,$dmatrix,%resp);
	my $val = '';
#print "Starting processing now...\n";
while (<IN>)
	{
	chomp;
	s/\r//g;
#	$line = $_;
#
# This fixes symbols that span 2 lines & get missed otherwise
#	
	if (/\{\\field\{\\\*\\fldinst SYMBOL$/i)
		{
		s /\{\\field\{\\\*\\fldinst SYMBOL$//i;
		$nextfix = '{\field{\*\fldinst SYMBOL';
		}
	if (/\{\\field\{\\\*\\fldinst $/)
		{
		s /\{\\field\{\\\*\\fldinst $//;
		$nextfix = '{\field{\*\fldinst ';
		}
	if (/(<[^>]*)$/)		
		{
		$nextfix = $1;
		s /<[^>]*$//;
		}
	$_ = "$prefix$_";
	$prefix = $nextfix;
	$nextfix = '';
#
# Looking for field codes:
#
	while ((/<(.+?)>/) && !$abort)
		{
		undef $qlab;
		undef $q_no;
		my $orig = $1;
		my $ting = $orig;
# <A}{\f2\cf2 1}{\b\i\v x1>
		&debugprint("orig='$orig'");
		$ting =~ s/[\\\w+]+ //g;		# Kill the rtf
		$ting =~ s/}{//g;			# Kill the matching braces
		&debugprint("ting='$ting'");
		$ting = lc($ting);
		if ($ting =~ /(\w+?)x(\d+)x(\d+)(\D*)$/)
			{
			$qlab = $1;
			$ix1 = $2-1;
			$ix2 = $3-1;
			$ag = lc($4);
			$data = &get_data($q,$q_no,"Q$qlab")
			}
		elsif ($ting =~ /(\w+?)x(\d+)/)
			{
			$two = $2 - 1;
			$qlab = $1;				#&goto_q_no($1);
			$grix = $two;
#			$qlab =~ s/^q//i;
			$data = &get_data($q,$q_no,"Q$qlab-$two");
			if ($data eq '')
				{
				$data = &get_data($q,$q_no,"Q$qlab");
				}
			}
		elsif ($ting =~ /^(\w+)$/)
			{
			$qlab = $1;
#			$qlab =~ s/^q//i;
			$data = &get_data($q,$q_no,"Q$qlab")
			}
		else		# Looks like there is whitespace in the token to be replaced...
			{
			$data = $orig;		# Keep the original thing
			s/</&lt;/;			# Nuke the '<' temporarily to get out the loop
			}
# For some reason an undef here really messes things up, and $qtype remains blank forever
#		undef $qtype;
#		&debugprint("GOTO $qlab");
		$q_no = &goto_qlab($qlab);
		if ($q_no > 0)
			{
		    my $filename = "$cfg{troot}/$survey_id/config/q$q_no.pl";
		  	&my_require ($filename,0);
		  	}
		&debugprint("ting=$ting");
#		$data = &get_data($q,$q_no,"Q$qlab");
		my $newthing = $data;
debugprint("data=$data, ting=$ting, qlab=$qlab qtype=$qtype");		
		if ($q_no > 0)
			{
			if ($qtype == QTYPE_ONE_ONLY)
		  		{
		  		&debugprint("CHECKING ONE ONLY");
		  		undef @ans;
				if ($data eq '')		# No data available - skip over it !
					{
					$newthing = '';
					}
				else
					{
			  		if ($data > $#options)
			  			{
						$newthing = get_data($q,$q_no,"Q${qlab}-0");		# Pull in the 'Other (Specify...............)'
						}
					else
			  			{
						$newthing = $options[$data];
						}
					}
		  		}
		  	if ($qtype == QTYPE_MULTI)
		  		{
				if ($data eq '')		# No data available - skip over it !
					{
					$newthing = '';
					}
				else
					{
			  		&debugprint("CHECKING MULTI");
			  		my $i = 0;
			  		my $ix = 0;
			  		undef @ans;
			  		$newthing = 'No';
					@ans = mysplit($array_sep,$data);
			  		while ($i <= $#ans)
			  			{
			  			if ($ans[$i])
			  				{
			  				&debugprint("ix=$ix, two=$two");
			  				if ($two == $ix)
				  				{
				  				$newthing = $options[$i];
	#			  				print "Gotcha: $newthing\n";
				  				$i = $#ans;					# Quit the loop
				  				}
				  			$ix++;
			  				}
			  			$i++;
			  			}
			  		}
		  		}
		  	if (($qtype == QTYPE_GRID) || ($qtype == QTYPE_GRID_NUMBER) 
		  	|| ($qtype == QTYPE_GRID_TEXT) || ($qtype == QTYPE_GRID_PULLDOWN)
		  	|| ($qtype == QTYPE_GRID_MULTI) )
		  		{
				if ($data eq '')		# No data available - skip over it !
					{
					$newthing = '';
					}
				else
					{
			  		undef @ans;
					@ans = mysplit($array_sep,$data);
					undef @matrix;
					my $index = 0;
					my $extrax = ($qtype == QTYPE_GRID_MULTI) ? $others : 0;
					my $extray = ($qtype == QTYPE_GRID_MULTI) ? 0 : $others;
					for(my $y=0;$y<=($#options+$extray);$y++)
						{
						for(my $x=0;$x<$scale+$extrax;$x++)
							{
							$matrix[$y][$x] = $ans[$index++];
#							print "dmatrix[$y][$x]=$matrix[$y][$x]\n";
							}
						}
					
					if ($qtype == QTYPE_GRID_NUMBER)
						{
						my $ix = ($ix1*abs($scale)) + $ix2;
				  		&debugprint("CHECKING NUMBER GRID $qlab [$ix1, $ix2] => ix=$ix");
						# Work out a true index into this thing
						$newthing = $ans[$ix];
#						$newthing = $matrix[$ix2][$ix1];
						}
					elsif ($qtype == QTYPE_GRID_TEXT)
						{
						my $ix = ($ix1*abs($scale)) + $ix2;
				  		&debugprint("CHECKING TEXT GRID $qlab [$ix1, $ix2] => ix=$ix");
						$newthing = $ans[$ix];
						}
					elsif ($qtype == QTYPE_GRID_PULLDOWN)
						{
						my $ix = ($ix1*abs($scale)) + $ix2;
				  		&debugprint("CHECKING PULLDOWN GRID $qlab [$ix1, $ix2] => ix=$ix");
				  		$newthing = '';
						$newthing = $pulldown[$ans[$ix]] if ($ans[$ix] > 0);
						}
					elsif ($qtype == QTYPE_GRID_MULTI)
						{
						my $ix = ($ix2*(abs($scale)+$others)) + $ix1;
				  		&debugprint("CHECKING MULTI GRID $qlab [$ix1, $ix2] => ix=$ix");
				  		if ($data =~ /$array_sep/)
				  			{
							if (1)
								{
						  		my @my_scale = @scale_words;
						  		push @my_scale,'Other' if ($others);
						  		$newthing = '';
								if ($matrix[$ix1][$ix2])
									{
									$newthing = ($ag =~ /a/i) ? notag($options[$ix1]) : $my_scale[$ix2];
									$newthing = $resp{"_Q$q_label-$ix1"} if (($ix2 == $#my_scale) && $resp{"_Q$q_label-$ix1"});
									}
#					  			print "$q_label($ting): matrix[$ix1][$ix2]=$newthing ix=$ix\n";
								}
							else
								{
						  		my @names=();
						  		my $i = 0;
						  		my @my_scale = @scale_words;
						  		push @my_scale,'Other' if ($others);
						  		foreach my $x (@my_scale)
						  			{
#						  			print "$q_label: matrix[$ix2][$i]=$matrix[$ix2][$i] ix=$ix\n";
						  			push (@names,$x) if ($matrix[$ix2][$i]);
						  			$i++;
						  			}
						  		if ($others)
						  			{
	#					  			push(@names,$x) if ($ans[$ix]);
						  			}
								$newthing = join(", ",@names);
								}
							}
				  		else
				  			{
				  			$newthing = $data;
				  			}
						}
					else
						{
				  		&debugprint("CHECKING GRID two=$two");
						if ($#scale_words != -1)
							{
							$newthing = ($rank_grid) ? $options[$ans[$two]] : $scale_words[$ans[$two]];
							}
						else
							{
							$newthing = $ans[$two]+1;
							}
						$newthing = $dk if (($newthing eq '') && ($ans[$two] > $#scale_words));
						}
					}
		  		}
		  	if (($qtype == QTYPE_NUMBER) || ($qtype == QTYPE_PERCENT))
		  		{
				if ($data eq '')		# No data available - skip over it !
					{
					$newthing = '';
					}
				else
					{
			  		&debugprint("CHECKING NUMBER [$data]");
			  		undef @ans;
					@ans = mysplit($array_sep,$data);
					$newthing = $ans[$two];
					}
		  		}
		  	if ($qtype == QTYPE_WRITTEN)
		  		{
		  		$newthing = $data;
				$newthing =~ s/\r//g;
		  		}
			}
		if ($newthing eq '')
			{
			$newthing = &getvar($ting);
			$newthing =~ s/^"//; # Trim quotes
			$newthing =~ s/"$//;
			}
# This is a bit of code originally grafted in as a 'special' for FGI102, to allow for foreign language stuff put in as resp{_xQ1_G2} etc
        while ($newthing =~ /\$\$(\w+)/)
            {
			my $oldthing = $1;
#           print "subst for $oldthing : ".$resp{"_".uc($oldthing)}."\n";
			my $new1 = $resp{"_".uc($oldthing)};
            $newthing =~ s/\$\$$oldthing/$new1/ig;
            }
		$newthing =~ s/\\n/\\line /g;
		$newthing =~ s/<BR>/ /ig;
		$newthing =~ s/&\w+;*//ig;
		$newthing = "DK" if ($newthing eq "-1");
		$orig =~ s/\\/\\\\/g;
		$orig =~ s/{/\\{/g;
# If the regexp has ( or ), it wants them to be balanced, so we have to escape them
		$orig =~ s/\)/\\)/g;
		$orig =~ s/\(/\\(/g;
		&debugprint("Replacing <$orig> with [$newthing]");
#		&debugprint($_);
		s/<$orig>/$newthing/ig;
		&debugprint("NEW STR: $_");
		$nreplaced++;
		if ($nreplaced > 500)
			{
			$abort = 1;
			print OUT "TOO MANY REPLACEMENTS($nreplaced): ABORTING\n";
			print STDERR "TOO MANY REPLACEMENTS($nreplaced): ABORTING\n";
			}
		}
	s/&lt;/</g;		# Put the < back in (we nuked it b4)
#
# In this section we are looking to replace the rating scales
#
# SYMBOL 129 .. 140 = 1..10		
# SYMBOL 32 = blank
# SYMBOL 117 = DIAMOND
#
	while (/fldinst SYMBOL (\d+)/i)
		{
		my $orig = $1;
		my $sym = $orig;
		my $n = $orig - 129;
		&debugprint("SYMBOL $orig, n=$n");
		if (($n >= 0) && ($n <= 12))	
			{
			if ($n == 0)			# Starting a scale ?
				{
#
# Split the grid
#
				$val = '';
				undef @ans;
				if ($data ne '')
					{
					@ans = mysplit($array_sep,$data);
					$val = $ans[$grix++];
					&debugprint("q_no=$q_no, \@ans=".join(",",@ans));
					&debugprint("n=$n, val=$val, ix=$grix");
					if ($grix > $#ans)
						{
						$q_no++;
						$grix = $two+1;
						}
					}
				}
			else
				{
				&debugprint("n=$n, val=$val, ix=$grix");
				}
			if ($val eq '')
				{
				$sym = 32;
				}
			else
				{
				$sym = ($n == $val) ? 117 : 32;
				}
			}
		s /fldinst SYMBOL $orig/fldinst SYMBOL=$sym/i;
		}
	s/fldinst SYMBOL=/fldinst SYMBOL /ig;
	print OUT "$_\n";
	}
#print "OK\n";

sub debugprint
	{
	my $msg = shift;
	print "$msg\n" if ($opts{debug});
	}
1;

