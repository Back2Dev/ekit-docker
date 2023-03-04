#!/usr/bin/perl
$|++; # unbuffer stdout
###$Id: qfiles.pl,v 1.35 2011-07-26 21:05:29 triton Exp $
#
# QFILES parser
#
# Copyright Triton Information Technology 2001, All rights reserved
#
use strict;
use FileHandle;  						#perl2exe
use Data::Dumper;  						#perl2exe
use Getopt::Long;  						#perl2exe
use DirHandle;  						#perl2exe
use Time::Local;						#perl2exe

use TPerl::TritonConfig qw(getConfig);  #perl2exe
use TPerl::Parser;  					#perl2exe
use TPerl::Dump;						#perl2exe
use File::Slurp;						#perl2exe
#
# These 4 are for Windoze benefit, to shut up perl2exe:
#
use constant;							#perl2exe
use IO::WrapTie;						#perl2exe
use File::Spec;							#perl2exe
use	File::Spec::Win32;					#perl2exe

my $file = undef;
my $dest = undef;
my $debug = 0;
my $var_usage = [];
my $var_usage_all = undef;
my $help = undef;
my $quick = 0;
my $require_ck = 1;
my $var_ck = 1;
my $no_var_warn = [];
my $var_warning_exclude_file = 1;
my $qfiles = 1;
my $length_warn = 1;
my $recode = 1;
my $ass_warn = 1;
my $simple_tabs = 0;

# get 'global' variables
    my $root = getConfig ('TritonRoot');

GetOptions (
	'file:s'=>\$file,
	'write_in:s'=>\$dest,
	 debug	=>\$debug,
	 'variable:s'=>$var_usage,
	 'allvariables!'=>\$var_usage_all,
	 'varchk!'=>\$var_ck,
	 'requireqfiles!'=>\$require_ck,
	 'novarwarn'=>$no_var_warn,
	 'lengthwarn!'=>\$length_warn,
	 'warnfile!'=>\$var_warning_exclude_file,
	 'assgnwarn!'=>\$ass_warn,
	 quick=>\$quick,
	 'qfiles!'=>\$qfiles,
	 help=>\$help,
	 'recode!'=>\$recode,
	 'simple_tabs'=>\$simple_tabs,
) or usage ( "Bad Command line Options" );

if ($quick){
	$var_ck=0;
	$require_ck=0;
	$length_warn =0;
	$recode=0;
}

my $job = shift;

my $p = new TPerl::Parser;
$file ||= $p->parser_filename (SID=>$job);
usage ("Cannot get file for job '$job'") unless $file;
$dest ||= join '/',( $root,$job,'config','');

sub usage {
	my $message = shift;
	print "  $message\n";
	print 
	qq{  Usage: qfiles [options] survey_id
   options:
	 -help 	show help information
	 -file  	alternate to parsing $file
	 -debug	show debug information
	 -write_in	alter dest from $dest
	 -nolengthwarn  do not warn about long variables.
	 -simple_tabs	If specified then all tabs will be created the same vs. NAGS style with the first dot used for specifying name for attribute.

	 -quick	  sets requireqfile and varchk to off 
	 -[no]qfiles	 generate qfiles.  default on.
	 -[no]requireqfile	require any generated perl files. default on

   Variable Checking options:
	 -[no]varchk controls variable checking. def on
	 -[no]assignwarning no 'XXX was assigned but not used' warnings'

   the following need varchk on to work:
	 -variable VAR show everything about VAR. repeatable
	 -ignore_var	VAR no warnings for this VAR. repeatable
	 -[no]warnfile use the ignore_vars.txt file in $dest. default on
	 -[no]allvars show usage of all vars found. default is off

	 all options can be abbreviated to uniqueness
};
die "\n";
}

usage ( ) if $help;
usage ( "SurveyID  must be specified on command line") unless $job;
usage ( "file '$file' cannot be read") unless -r $file;
# usage ( "Directory $dest cannot be written to") unless -w "$dest/";

print "Job=$job\nfile=$file\nwriting to $dest\n" if $debug;
my $starttime =timelocal (localtime);
print "starting $job at ".scalar (localtime ($starttime))."\n";
my $fh = new FileHandle ("< $file") or die "canna open $file";
$p->parse (file=>$file);

# print Dumper $p;
my $max_varl;
unless ($length_warn){
	$max_varl = 1000 ;
	$p->err->I("Not warning about long variable names");
}

my $eng_error = $p->engine_files (dir=>$dest,SID=>$job,max_var_length=>$max_varl,troot=>$root,recode=>$recode,simple_tabs=>$simple_tabs) if $qfiles ;
$p->err->E("Trouble making engine files:$eng_error") if $eng_error;

if ( $var_ck){
	### look for names of vars to ignore
		my $ig_fn = "$dest/ignore_vars.txt";
		if (-e $ig_fn && $var_warning_exclude_file){
			$p->err->I("ignoring variables named in $ig_fn");
			push @$no_var_warn,read_file ($ig_fn);
			s/^\s*(.*?)\s*$/$1/ foreach @$no_var_warn;
		}
	my $ext_file = join '/',$root,$job,'config','external_vars.txt';
	my $externals = eval(read_file($ext_file)) if -e $ext_file;
	# print Dumper $externals;
	my $usage = $p->variable_usage( allvars=>$var_usage_all,variables=>$var_usage,
		ignore=>$no_var_warn,no_assign_warnings=>!$ass_warn,external_info=>$externals ); 
	# print Dumper $usage->{assign};
}

$p->err->pretty_count(head=>"\nParser Error Summary");

if ($require_ck && $qfiles){
	print "\nChecking files... ";

	my $quest = scalar (@{$p->questions});
	for (my $count=1;$count<$quest;$count++){                
		my $filename = "$dest/q$count.pl";
		eval { require "$filename"};
		$p->err->E("Could not require $filename\n$@") if $@;
	}
	foreach ('config.pl','config2.pl','qlabels.pl'){
		my $filename = "$dest/$_";
		eval { require "$filename"};
		$p->err->E( "Could not require $filename\n$@\n") if $@;
	}
}
my $endtime = timelocal (localtime);
print "\n\nDone $job\n".scalar (localtime ($endtime)).
	" ".($endtime-$starttime)." seconds.\n\n";
# sleep 5;	# Give the user a chance to see the output


