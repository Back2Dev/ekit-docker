#!/usr/local/bin/perl
# $Id: 360_vacuum.pl,v 1.5 2012-11-08 08:09:38 triton Exp $
#
use Getopt::Long;						#perl2exe
use	File::Copy;							#perl2exe
use	File::stat;							#perl2exe
use File::Path;	  						#perl2exe
use File::Basename;  					#perl2exe

use TPerl::CmdLine;  					#perl2exe
use TPerl::Error;		  				#perl2exe
use TPerl::TSV;							#perl2exe
#
# Mainline starts here
#
# This looks for orphaned files and moves them to a location defined in the
# config file (server.ini) named orphans_dir.
#
# It scans the following:
# u-files
# d-files
# document files (.rtf)
#
my $ncopy = 0;
my ($orphan,@ufiles,@dfiles,$rref,@rfiles);
our (%config,$relative_root,$qt_root);
our ($opt_h,$opt_n,$opt_t,$opt_status_file,$opt_restore);
GetOptions (
	'trace'=>\$opt_t,
	'noaction'=>\$opt_n,
	'help'=>\$opt_h,
	'restore'=>\$opt_restore,
	'status_file=s',\$opt_status_file,
) or die_usage ('Bad Command line options');
my $err = new TPerl::Error ();

my $defaultdir = "$relative_root${qt_root}/pwikitdocs/";
#my $defaultdir = 'C:/temp/pwikitdocs';
my $output_dir = $defaultdir;
print "Output dir=$output_dir\n" if ($opt_t);
my $orphan_base = getConfig('orphans_dir');
die "Fatal error: [orphans_dir] is not defined in server.ini\n" if ($orphan_base eq '');

die_usage() if ($opt_h);

sub die_usage
	{
	print STDERR <<HELP;
Usage: $0 [-help] [-noaction] [-trace] [-status_file=] [-restore]
  Where:
  [-noaction]   - do not do anything permanent, just go through the motions
  [-help]       - Displays this help message
  [-trace]      - Turns on trace output, tells you what it is doing
  [-restore]	- ??? Future option to restore orphaned files ???
  [-status_file=] - ??? Use some kind of status file ???
HELP
	exit(1);
	}

my ($volume,$directories,$myname) = File::Spec->splitpath($0);
$myname =~ s/\.\w+//g;
my $logfile = "$relative_root${qt_root}/log/$myname.log";
mkpath(dirname($logfile),1);
if (my $fh = new FileHandle (">> $logfile"))
	{
	$err->fh ($fh);
	}
else
	{
	$err->E("Could not write to $logfile")
	}

our $t = $opt_t;
$err->I(sprintf ("Starting $0 at %s",scalar(localtime)));
my $dbh = &db_conn;
print "Checking for orphans ...\n";
#my $cmdl = new TPerl::CmdLine;
foreach my $sid (sort keys %{$config{snames}})
	{
	my %seql = ();
	my %pwdl = ();
	my %gotu = ();
	my %gotd = ();
	my %gotr = ();
	my @orphans = ();
	print "$sid...\n" if ($opt_t);
	my $sql = "SELECT PWD,UID,SEQ FROM $sid";
	my $th = &db_do($sql);
	$rref = $th->fetchall_arrayref;
	foreach my $aref (@$rref)
		{
		print "$aref->[1] $aref->[2]\n" if ($opt_t);
		if ($aref->[2] > 0)
			{
			$seql{$aref->[2]} = qq{$sid/$aref->[1]};
			}
		$pwdl{$aref->[0]} = qq{$sid/$aref->[1]};
		}	 
	$th->finish;
	my $data_dir = "$relative_root${qt_root}/$sid/web";
	opendir DDIR,$data_dir || die "Error $! encountered while opening directory $data_dir\n";
	my @files = readdir(DDIR);
	closedir(DDIR);
	my $doc_dir = "$relative_root${qt_root}/$sid/doc";
	opendir DDIR,$doc_dir || die "Error $! encountered while opening directory $doc_dir\n";
	my @docfiles = readdir(DDIR);
	closedir(DDIR);
#
# Scan the u files for orphans
#
	@ufiles = grep(/^u.*?.pl$/,@files);
	foreach my $file (@ufiles)
		{
#		print qq{$file\n} if ($opt_t);
		if ($file =~ /^u(.*?)\.pl$/)
			{		
			my $pwd = $1;
			if ($pwdl{$pwd} eq '')
				{
				print qq{$file: ORPHAN\n} if ($opt_t);
				push @orphans,qq{$file};
				}
			else
				{ 
				$gotu{$pwd}++; 
#				print qq{$file: OK\n} if ($opt_t);
				}
			}
		else
			{ 
			warn("Bogus u-file filename: $file");
			}
		}
#
# Scan the D-files for orphans
#
	@dfiles = grep(/^D.*?.pl$/,@files);
	foreach my $file (@dfiles)
		{
#		print qq{$file\n} if ($opt_t);
		if ($file =~ /^D(.*?)\.pl$/)
			{		
			my $seq = $1;
			if ($seql{$seq} eq '')
				{
				print qq{$file: ORPHAN\n} if ($opt_t);
				push @orphans,qq{$file};
				}
			else
				{
				$gotd{$seq}++; 
#				print qq{$file: OK\n} if ($opt_t);
				}
			}
		else
			{ warn("Bogus D-file filename: $file"); }
		}
#
# Scan the doc files for orphans
#
	@rfiles = grep(/^.*?.rtf$/,@docfiles);
	foreach my $file (@rfiles)
		{
#		print qq{$file\n} if ($opt_t);
		if ($file =~ /^(.*?)\.rtf$/)
			{		
			my $seq = $1;
			if ($seql{$seq} eq '')
				{
				print qq{$file: ORPHAN\n} if ($opt_t);
				push @orphans,qq{$file};
				}
			else
				{ 
				$gotr{$seq}++; 
#				print qq{$file: OK\n} if ($opt_t);
				}
			}
		else
			{ warn("Bogus rtf-file filename: $file"); }
		}
#
# Now check that we found everything we should have
#
	foreach my $aref (@$rref)
		{
		if ($aref->[2] > 0)		# We have a valid seqno for this one
			{
			if ($gotd{$aref->[2]} eq '')
				{
				error("Missing D-file for $sid pwd=$aref->[0], uid=$aref->[1], seq=$aref->[2]");
				}
			}
		if ($gotu{$aref->[0]} eq '')
			{
			error("Missing U-file for $sid pwd=$aref->[0], uid=$aref->[1]");
			}
		
		} 
#
# At this point the orphans array has stuff in it to move out the way
#
	foreach $orphan (@orphans)
		{
		my $subdir = "???";
		$subdir = "doc" if ($orphan =~ /^\d*/);
		$subdir = "web" if ($orphan =~ /^u/);
		$subdir = "web" if ($orphan =~ /^D/);
		my $src = "${qt_root}/$sid/$subdir/$orphan";
		my $dst = "${orphan_base}/$sid/$subdir/$orphan";
		info("Moving file $src to $dst");
		if (!$opt_n)
			{
			mkpath("${orphan_base}/$sid/$subdir",1);
			move($src,$dst);
			}
		}
	}
#------------------------------------------------------------------------------------------
#
# Subroutines start here
#
sub info
	{
	my $msg = shift;
	print "[I] $msg\n";
	$err->I($msg);
	}
sub warn
	{
	my $msg = shift;
	print "[W] $msg\n";
	$err->W($msg);
	}
sub error
	{
	my $msg = shift;
	print "[E] $msg\n";
	$err->E($msg);
	}
sub fatal
	{
	my $msg = shift;
	print "[F] $msg\n";
	$err->F($msg);
	}

1;
