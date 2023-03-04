#!/usr/bin/perl
#
# $Id: pwi_getdocs.pl,v 1.10 2012-11-27 23:17:58 triton Exp $
#
# Script to assemble document files for MAP
#
use strict;
use	File::Copy;							
#use	File::Stat;							
use Getopt::Long;						
use File::Path;	  						
use File::Basename;  					

use TPerl::CmdLine;  					
use TPerl::Error;		  				
use TPerl::TritonConfig qw(getConfig);  

require 'TPerl/qt-libdb.pl';
require 'TPerl/pwikit_cfg.pl';
#
#

#
# Mainline starts here
#


$| = 1;
my $ncopy = 0;
our ($relative_root,$qt_root,%config);
our (%resp);
my (%opts);
GetOptions (
			help => \$opts{h},
			debug => \$opts{d},
			trace => \$opts{t},
			version => \$opts{v},
			nocopy => \$opts{nocopy},
			nolog => \$opts{nolog},
			norsync => \$opts{norsync},			# Skip the rsync step
			noanalysis => \$opts{noanalysis},	# Skip the analysis
			'batch=s' => \$opts{batch},			# Output rsync commands to batch file
			) or die_usage ( "Bad command line options" );
if ($opts{h})
	{
	&die_usage;
	}
if ($opts{v})
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/scripts/pwi_getdocs.pl,v 1.10 2012-11-27 23:17:58 triton Exp $'."\n";
	exit 0;
	}
    
my $err = new TPerl::Error ();
my $remote_root =  getConfig('RemoteRoot');	# Was qq{map@mappwi.com:/home/vhosts/pwikit/triton};
my $defaultdir = "$relative_root${qt_root}/pwikitdocs/";
#my $defaultdir = 'd:/temp/pwikitdocs';
my $output_dir = $defaultdir;
print "Output dir=$output_dir\n RemoteRoot=$remote_root\n" if ($opts{t});
die "Missing RemoteRoot= setting in server.ini\n" if (!$remote_root);
if ($opts{h})
	{
	die <<HELP;
Usage: $0 [-h] [-n] [-t] [-r] [output-dir]
  Where:
  [-n] - do not copy any files, just go through the motions
  [-h] - Displays this help message
  [-t] - Turns on trace output, tells you what it is doing
  [-r] - do not do the RSYNC part
  [-a] - do not do the document analysis part
  [output-dir] Is the output directory (defaults to $defaultdir)
       - under here are automatically created sub-directories for each workshop location
       - and workshop date
       - and a 'printed' sub-directory
       Move files to the 'printed' directory when you have printed them
HELP
	}
my $logfile = "$relative_root${qt_root}/log/pwi_getdocs.log";
if (my $fh = new FileHandle (">> $logfile"))
	{
	$err->fh ($fh);
	}
else
	{
	$err->E("Could not write to $logfile")
	}
my $cmdl = new TPerl::CmdLine;
mkpath(dirname($logfile),1);
mkpath("$output_dir",1);
mkpath("$output_dir/printed",1);

my $ssh = getConfig('ssh');
die qq{triton/cfg/server.ini is missing command for ssh (eg ssh=-e "ssh -i /cygdrive/d/triton/.ssh/id_rsa -o StrictHostKeyChecking=no"\n} if (!$ssh);
$err->I(sprintf ("Starting $0 at %s",scalar(localtime)));
#
# If we are saving commands to a batch file, start the file now...
#
if ($opts{batch}) {
	open(BF,"> $opts{batch}") || die "Error $! writing to file $opts{batch}\n";
	print BF "REM Batch file to sync documents from server\n";
}
if ($opts{norsync})
	{
	$err->I("Skipping rsync");
	print "Skipping rsync stage\n";
	}
else
	{
	print "Retrieving documents from Server...\n";
	# rsync c:\triton\ looks like a host called triton
	my $root = $qt_root;
	$root =~ s#^([a-z]):\\#\/cygdrive\/$1\/#i;
	$root =~ s#\\#/#ig;								# Fix any stray backslashes
	foreach my $sid (sort keys %{$config{snames}}) {
		print "$sid ";
		my $cmd = qq{rsync -rtuvz $ssh --delete --copy-links $remote_root/$sid/doc $root/$sid --exclude=*.txt};
		rsync_do($cmd);
		$cmd = "rsync -rtuvz $ssh --delete --copy-links $remote_root/$sid/web $root/$sid --exclude=u*.pl --exclude=input.raw --exclude=*.txt";
		rsync_do($cmd);
		}
	print ".\n";
	}
if ($opts{batch}) {
	close(BF);			# Close off the batch command file
	# And execute it...
	my $cmd = qq{$opts{batch}};
	my $exec = $cmdl->execute (cmd=>$cmd);
	if ($exec->success)
		{
		$err->I($exec->output);
		}
	else{	
		$err->E($exec->output );
		print "Error:".$exec->output."\n";
		}
}
if ($opts{noanalysis}) {
	print "Skipping document analysis stage\n";
} else {
	print "Analyzing documents...\n";
	$err->I(sprintf("Analyzing documents at %s",scalar(localtime)));
	foreach my $sid (sort keys %{$config{snames}})
		{
		print "$sid ";
# Turns out they do still want the individual KP's :)
#		next if ($sid eq 'MAP010');		# No longer need Q10's, as they are consolidated into MAP010A
		move_qdocs($sid);
		}
	print ".\nCopied $ncopy files\n";
	print "Done.\n";
	$err->I("Copied $ncopy files\n");
}
#
# Now copy back the log file, so that we can see went on remotely:
#
if (!$opts{nolog})
	{
	my $cmdl = new TPerl::CmdLine;
	my $logf = $logfile;
#	$logf =~ s/^\w://;		# Strip the drive letter off the front
	$logf =~ s#^([a-z]):\\#\/cygdrive\/$1\/#i;
	$logf =~ s/\\/\//g;		# Turn the filename into unix format
	my $cmd = "rsync $ssh -tuvz --copy-links $logf $remote_root/log";
	my $exec = $cmdl->execute (cmd=>$cmd);
	if ($exec->success)
		{
		$err->I($exec->output );
		}
	else{	
		$err->E($exec->output );
		print "Error:".$exec->output."\n";
		}
	}
#------------------------------------------------------------------------------------------
#
# Subroutines start here
#
sub rsync_do () {
	my $command = shift;
	print  "$command\n" if ($opts{t});
	if ($opts{batch}) {
		print BF "$command\n";
	} else {
		my $exec = $cmdl->execute (cmd=>$command);
		if ($exec->success) {
			$err->I($exec->output );
		} else {	
			$err->E($exec->output );
			print "Error:".$exec->output."\n";
		}
	}
}

sub move_qdocs
	{
	my $survey_id = shift;
	die "Error: missing survey id\n" if ($survey_id eq '');
#
# Get the set of document files:
#
	my $webdir = "$relative_root${qt_root}/$survey_id/web";
	my $docdir = "$relative_root${qt_root}/$survey_id/doc";
	force_dir($docdir);		# This should prevent a die from the next line
	die ("Error $! while opening directory $docdir\n") if (! opendir(DDIR,"$docdir"));
	my @docfiles = grep (/^[0-9]+\.rtf$/i,readdir(DDIR));
	closedir(DDIR);
# 
# Now look through them
#
	foreach my $docfile (@docfiles)
		{
		print "$docfile:\n" if ($opts{t});
		if (!($docfile =~ /^([0-9]+)\.rtf$/i))
			{
			$err->E("Error: incorrect document name : $docfile");
			}
		else
			{
			my $seq = $1;	# Grab the sequence number
			my $srcfilename = "$docdir/$docfile";
			my $dfilename = "$webdir/D$seq.pl";
			if (-f $dfilename)
				{
				my $copy = 1;
				undef %resp;
				&my_require($dfilename,0);			# Grab the contents, do not force creation
				print "seq=$seq, password=$resp{password}, fullname=$resp{fullname}, location=$resp{location}, workshopdate=$resp{workshopdate}\n" if ($opts{t});
				if ($resp{fullname} eq '')
					{
					$err->E("Error: data file for $srcfilename is missing participant's name");
					$copy = 0;
					}
				foreach my $key ('workshopdate','location','locationcode','fullname')
					{
					$resp{$key} =~ s/[\/\\]+/-/g;
					}
				if ($resp{location} eq '')
					{
					$err->E("Missing location information for $resp{fullname} ($srcfilename)");
					$copy = 0;
					}
				if ($resp{workshopdate} eq '')
					{
					$err->E("Missing workshop date information for $resp{fullname} ($srcfilename)");
					$copy = 0;
					}
				$resp{locationcode} = $resp{location} if ($resp{locationcode} eq '');
				$resp{locationcode} =~ s/^\s+//;
				$resp{locationcode} =~ s/\s+$//;
				$resp{workshopdate} =~ s/^\s+//;
				$resp{workshopdate} =~ s/\s+$//;
				my $destpath = "$output_dir/$resp{locationcode}/$resp{workshopdate}";
				my $destname = "$resp{lastname},$resp{firstname}-$resp{id}-$survey_id-$seq.rtf";
				my $oldname = "$resp{id}-$resp{fullname}-$survey_id-$seq.rtf";
				if ($survey_id eq 'MAP010A')
					{
					my $wfilename = "$docdir/$resp{id}.rtf";		# Special filename for MAP010A
					if (-f $wfilename)								# Use this instead
						{
						$srcfilename = $wfilename;
						$destname = "$resp{lastname},$resp{firstname}-$resp{id}-$survey_id.rtf";
						$oldname = "$resp{id}-$resp{fullname}-$survey_id.rtf";
						}
					else
						{
						$copy = 0;									# Don't copy the document containing the list of names
						}
					}
				my $destfile = "$destpath/$destname";
				my $olddestfile = "$destpath/$oldname";
				my $printfile = "$output_dir/printed/$destname";
				my $oldprintfile = "$output_dir/printed/$oldname";
#
# Is there a new print file there already ?
#
				if ($copy && (!-f $printfile))		# If no new print file, look for an old print file
					{
					if ($copy && (-f $oldprintfile))		# If this matches we are done
						{
						my @statprint = stat($oldprintfile) or die "No $oldprintfile: $!";
						my @statsrc = stat($srcfilename) or die "No $srcfilename: $!";
						$copy = 0 if (($statsrc[7] == $statprint[7]) # size check
							|| ($statsrc[9] == $statprint[9])); # modification time
	#					print "print $printfile: no change\n" if (!$copy);
						}
					}
#
# Has the file been printed already ?
#
				if ($copy && (-f $printfile))
					{
					my @statprint = stat($printfile) or die "No $printfile: $!";
					my @statsrc = stat($srcfilename) or die "No $srcfilename: $!";
					$copy = 0 if (($statsrc[7] == $statprint[7]) # size check
						|| ($statsrc[9] == $statprint[9])); # modification time
#					print "print $printfile: no change\n" if (!$copy);
					}
#
# Does the file exist in the 'ready to print' folder already ?
#
				if ($copy && (-f $olddestfile))		# Look for old format first
					{
					my @statdest = stat($olddestfile) or die "No $destfile: $!";
					my @statsrc = stat($srcfilename) or die "No $srcfilename: $!";
					$copy = 0 if (($statsrc[7] == $statdest[7]) # size check
						|| ($statsrc[9] == $statdest[9])); # modification time
#					print "dest $destfile: no change\n"  if (!$copy);
					}
				if ($copy && (-f $destfile))		# Look for new format now
					{
					my @statdest = stat($destfile) or die "No $destfile: $!";
					my @statsrc = stat($srcfilename) or die "No $srcfilename: $!";
					$copy = 0 if (($statsrc[7] == $statdest[7]) # size check
						|| ($statsrc[9] == $statdest[9])); # modification time
#					print "dest $destfile: no change\n"  if (!$copy);
					}
				print "COPY=$copy\n" if ($opts{t});
				if ($copy)
					{
					if (!$opts{nocopy})
						{
						$ncopy++;
						force_dir($destpath);
						copy($srcfilename,$destfile);
						}
					$err->I("Copying $srcfilename => $destfile");
					print "Copying $srcfilename => $destfile\n" if ($opts{t});
					}
				}
			else
				{
#				print STDERR "File not found: $dfilename\n";
				}
			}
		}
	}

