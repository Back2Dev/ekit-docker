#!/usr/bin/perl
#
# $Id: pwi_vacuum.pl,v 1.9 2012-11-01 03:26:13 triton Exp $
#
# Script to vacuum the PWI Kit
#
use strict;
use Data::Dumper;
#
use TPerl::TritonConfig qw(getConfig); 
use TPerl::CmdLine;
#
require 'TPerl/qt-libdb.pl';
require 'TPerl/360-lib.pl';
require 'TPerl/pwikit_cfg.pl';
require 'TPerl/360_vacuum.pl';
#
#
# The common part of 360_vacuum.pl has been done already,
# - it cleans up any orphaned files and moves them out of the way. 
# Now we are doing some custom work for the job...
#
# Now read the status file, and start the archiving process:
#
our ($opt_status_file,%config,$qt_root, $opt_n,$opt_restore,$dbh, $opt_t, $err);

info("Connecting to database, retrieving participant status values");
my $completes = &get_cms_status;
#
# We now have a list of the UID's that are completed, 
# and can therefore be moved to the completed area.
#
my $completed_base = getConfig('completed_dir');
die "Fatal error: [completed_dir] is not defined in server.ini\n" if ($completed_base eq '');
die "Fatal error: completed_dir [$completed_base] does not exist \n" if (!-d $completed_base );
&db_conn;	# Re-connect, because get_cms_status does a disconnect for us
for my $uid (keys %{$completes})
	{
	my $fullname = $$completes{$uid};
	info("Assembling completed info for $uid - $fullname");
	print qq{Creating path "${completed_base}/$uid"};
	mkpath("${completed_base}/$uid");
	my %movers = ();
	foreach my $sid (sort keys %{$config{snames}})
		{
		my $sql = "SELECT PWD,UID,SEQ FROM $sid where uid=?";
		my $th = &db_do($sql,$uid);
		while (my $href = $th->fetchrow_hashref)
			{
# u-file
			my $pwd = $$href{PWD};
			my $seq = $$href{SEQ};

			my $src = "${qt_root}/$sid/web/u$pwd.pl";
			my $dst = "${completed_base}/$uid/$sid-u$pwd.pl";
			$movers{$src} = $dst;

			if ($seq >0)
				{
# D-file
				my $src = "${qt_root}/$sid/web/D$seq.pl";
				my $dst = "${completed_base}/$uid/$sid-D$seq.pl";
				$movers{$src} = $dst;
# document (rtf file)
				my $src = "${qt_root}/$sid/doc/$seq.rtf";
				my $dst = "${completed_base}/$uid/$sid-$seq.rtf";
				$movers{$src} = $dst;
				}
			}
		$th->finish;
		}
#
# Now do the actual moving of the files
#
	foreach my $src (keys %movers)
		{
		next if (! -f $src);
		my $dst = $movers{$src};
		info("Moving file $src to $dst");
		if (!$opt_n)
			{
			if ($opt_restore)
				{
				move($dst,$src) if (-f $dst);
				}
			else
				{
				if ($src =~ /MAP026\/web\/D/) 	# We'll keep post workshop data for statistical analysis of ws leaders
					{ copy($src,$dst) if (-f $src); } 
				else
					{ move($src,$dst) if (-f $src); }
				}
			}
		}
	my $base = "${completed_base}/$uid";
#	rmdir($base);	# This should fail if directory is not empty
	if (-d $base) {	# If it's still there, create a zip file of them
		my $tarname = qq{$base $fullname.tar};
		$tarname =~ s/[\s]/_/ig;
		$tarname =~ s/[\-\+'"\)\(\{\}]//ig;
		my $cmd = "tar cvf $tarname ${base} -P ";
		$cmd =~ s/\\/\//g;
		$cmd =~ s?(\w):?/cygdrive/$1?g if ($^O =~ /win32/i );
		do_cmd($cmd);

# GZip them 
		$cmd = "gzip -f $tarname";
		$cmd =~ s/\\/\//g;
		do_cmd($cmd);
		}
# Delete the (temporary) source files
	if (!$opt_n)
		{
		my $cmd;
		if ($^O =~ /win32/i )
			{
			$base =~ s/\//\\/g;
			$cmd = "RD /S /Q $base";		# DOS RMDIR COMMAND
			}
		else
			{$cmd = "rm -rf $base";}
		do_cmd($cmd);
		}
	}

#
# Custom subs for this job...
#
sub get_cms_status
	{
	&db_conn;

	my %completes;
	my $sql = qq{select FULLNAME,CMS_STATUS,UID from PWI_STATUS where cms_status='X' or (cms_status='C' and wsdate<date_sub(now(),interval 6 month))};
	print "Executing sql: $sql\n";	
	my $th = $dbh->prepare($sql);
	$th->execute;
	while (my $href = $th->fetchrow_hashref)
		{
		$$href{FULLNAME} =~ s/^$$href{UID}\s*//ig;
		$completes{$$href{UID}} = $$href{FULLNAME};	# Save the name alongside the ID,(only archiving completed responses)
		}
	$dbh->disconnect;
	\%completes;
	}

sub do_cmd {
	my $cmd = shift;
	my $cmdl = new TPerl::CmdLine;
	print "Executing cmd: $cmd\n" if ($opt_t);
	my $exec = $cmdl->execute (cmd=>$cmd);
	if ($exec->success) {
	    $err->I($exec->output) if ($opt_t);
	} else {
	    $err->E($exec->output );
	    print "Error:".$exec->output."\n";
	}
}

1;
