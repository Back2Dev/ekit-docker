#!/usr/bin/perl
## $Id: 360_archive_docs.pl,v 1.19 2012-04-24 17:07:35 triton Exp $
# Script to collect all the documents and data for a respondent, and put them into a single file,
# in case we ever need them again.
#
# Copyright Triton Information Technology 2004 on...
#
use strict;
use Getopt::Long;							#perl2exe
use File::Copy;								#perl2exe
use File::Basename;							#perl2exe
use Date::Manip;							#perl2exe
use Archive::Zip;							#perl2exe

#Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");

our (%config,$dbt,$qt_root,%files,%deletes,$sfh);
require 'TPerl/qt-libdb.pl';
require 'TPerl/360_delete_core.pl';
#
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_n,$opt_only,$opt_delete,$opt_clean,
	$opt_cms_status,$opt_start_at,
	$opt_gz);
GetOptions (
			help => 	\$opt_h,
			debug => 	\$opt_d,
			trace => 	\$opt_t,
			version => 	\$opt_v,
			noaction => \$opt_n,
			delete =>	\$opt_delete,
			clean =>	\$opt_clean,
			'start_at=s'=> \$opt_start_at,
			'only=s' => \$opt_only,
			cms =>		\$opt_cms_status,
			gz =>		\$opt_gz,
			) or die_usage ( "Bad command line options" );

sub die_usage
	{
	my $msg = shift;
	print "Error: $msg\n" if ($msg ne '');
	print <<ERR;
Usage: $0 [-version] [-trace] [-help] [-noaction] [-only=ID] AAA101
	-help		Display help
	-version	Display version no
	-trace		Trace mode
	-noaction	Don't take any actions, just go through the motions
	-delete		DELETE everything as well ;)
	-clean		Clean them out (ie delete if no files found - probably archived previously)
	-start_at=xxx	Start from this ID
	-only=ID	Only do it for this ID
	-cms		Get list of ID's to archive from uploaded CMS data, which lives in PWI_UPLOAD_PARTICIPANT
	-gz			use Tar/GZip (default is .ZIP)
ERR
	exit 0;
	}
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/TPerl/360_archive_docs.pl,v 1.19 2012-04-24 17:07:35 triton Exp $'."\n";
	exit 0;
	}

&get_root;
my $archive_root = getServerConfig ('archive');
die "Config item archive= is missing from server.ini\n" if (!$archive_root);

&db_conn;
my %temp = ();
$dbt = 1 if ($opt_d);
my $andwhere = ($opt_start_at) ? " AND ID>=? " : '';
my $allsql = "select distinct UID,FULLNAME from $config{index} where rolename=? $andwhere order by UID";
my @params = ('Self');
if ($opt_cms_status)		# Are we getting it from PWI_UPLOAD_PARTICIPANT ? (This is uploaded from CMS)
	{
	$allsql = "select distinct ID as UID,CONCAT(FIRSTNAME,' ',LASTNAME) as FULLNAME from PWI_UPLOAD_PARTICIPANT WHERE STARTDATE < ? AND CMS_STATUS = 'C' $andwhere order by ID";
	@params = (UnixDate('6 weeks ago',"%Y-%m-%d"));
	}
push @params,$opt_start_at if ($opt_start_at);
my $th = &db_do($allsql,@params);
my $aref = $th->fetchall_arrayref;
$th->finish;
print "Starting archive run, destination dir = $archive_root/participant/ \n";
foreach my $arr (@$aref)
	{
	my $first = 1;
	next if (($opt_only ne '') && ($opt_only ne $arr->[0]));
	print "Archiving files for: $arr->[0] $arr->[1]\n" if ($opt_t);
	%files = ();
	%deletes = ();
	my $uid = $arr->[0];
	my $base = "$archive_root/participant/$uid";
	&force_dir($base);
	my $sqlfile = qq{$base/restore_$uid.sql};
	open SQLFILE,">$sqlfile" || die "Error $! encoutered while writing to file: $sqlfile\n";
	print "Creating SQL file: $sqlfile\n" if ($opt_t);
	my $asql = "select FULLNAME,UID,PWD,SID,ROLENAME from $config{index} WHERE UID=? ORDER BY SID";
	addsql("DELETE from $config{index} WHERE UID='$uid'");
	my $th = &db_do($asql,$uid);
	my $fullname = $arr->[1];
	$fullname =~ s/[\s]/_/ig;
	$fullname =~ s/[\-\+'"\)\(\{\}]//ig;
	my @stack = ();
	while (my $href = $th->fetchrow_hashref())
		{
		addfile("$qt_root/$config{participant}/web/u$$href{PWD}.pl");
		addfile("$qt_root/$$href{SID}/web/u$$href{PWD}.pl");
		my $seq = db_get_user_seq($$href{SID},$uid,$$href{PWD});
		addfile("$qt_root/$$href{SID}/web/D$seq.pl");
		addfile("$qt_root/$$href{SID}/doc/$seq.rtf");
		push @stack,"DELETE from $$href{SID} WHERE UID='$uid'";
#
# The following ones are something special that came from Paine PR
#
		if (opendir(DOCDIR, "$qt_root/$$href{SID}/doc"))
			{
		    my @fl = grep /${uid}_/, readdir(DOCDIR);
		    foreach my $f (@fl)
		    	{addfile("$qt_root/$$href{SID}/doc/$f");}
		    closedir DOCDIR;		
			}
		}	
	$th->finish;
	foreach my $sql (@stack)
		{
		addsql($sql);
		}
	close SQLFILE;
	my ($dev,$ino,$mode,$nlink,$userid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($sqlfile);
	unlink $sqlfile if ($size == 0);
	rmdir $base if (!%files);
	if (%files)
		{
		print qq{$arr->[0] $arr->[1]\n};
		print "Files to archive for $arr->[0] $arr->[1]: \n".join("\n  - ",keys %files)."\n\n" if ($opt_t);
		foreach my $src (keys %files)
			{
            my @parts = split(/\//,$src);
            my $fname = pop @parts;
            my $dir = pop @parts;
            my $job = pop @parts;
            my $path = "$base/$job/$dir";
            my $dst = "$path/$fname";
            &force_dir($path);
            print "Path=$path,\nCopying $src => $dst\n" if ($opt_t);
            copy($src,$dst) unless ($opt_n);
			}
		if (!$opt_gz)
			{
			my $zipname = qq{$base $fullname.zip};
			$zipname =~ s/[\s]/_/ig;
			$zipname =~ s/[\-\+'"\)\(\{\}]//ig;
			my $zip = Archive::Zip->new();
			print "Zipping $uid to $zipname\n" if ($opt_t);
			$zip->addTree($base, $uid);
			$zip->writeToFileNamed($zipname);
			undef $zip;
			}
		else
			{
# Make a tarball from the files
			my $tarname = qq{$base $fullname.tar};
			$tarname =~ s/[\s]/_/ig;
			$tarname =~ s/[\-\+'"\)\(\{\}]//ig;
			my $cmd = "tar cvf $tarname ${base} -P ";
			$cmd =~ s/\\/\//g;
			$cmd =~ s?(\w):?/cygdrive/$1?g if ($^O =~ /win32/i );
			print "Executing cmd: $cmd\n" if ($opt_t);
			my $res = `$cmd`;
			print "$res\n" if ($opt_t);
# GZip them 
			$cmd = "gzip -f $tarname";
			$cmd =~ s/\\/\//g;
			print "Executing cmd: $cmd\n" if ($opt_t);
			my $res = `$cmd`;
			print "$res\n" if ($opt_t);
			}
# Delete the (temporary) source files
		if (!$opt_d)
			{
			my $cmd;
			if ($^O =~ /win32/i )
				{
				$base =~ s/\//\\/g;
				$cmd = "RD /S /Q $base";		# DOS RMDIR COMMAND
				}
			else
				{$cmd = "rm -rf $base";}
			print "Executing cmd: $cmd\n" if ($opt_t);
			my $res = system($cmd);
			print "$res\n" if ($opt_t);
			}
		}
	else
		{
		print "Nothing to archive for $arr->[0] $arr->[1]";
		if ($opt_clean)
			{
			print " - deleting";
			my $result = "deleting files: \n  ".join("\n  ",sort keys %files)."\n";
			unlink keys %files unless ($opt_n);
			print "\n$result\n" if ($opt_t);
			foreach my $sql (keys %deletes)
				{
				&db_do($sql) unless ($opt_n);		# Assume the SQL is self contained, no parameters needed.
				print "SQL: $sql\n" if ($opt_t);
				}
			}
		print "\n";
		}
	if ($opt_delete)
		{
		my $result = "Deleting files: \n  ".join("\n  ",sort keys %files)."\n";
		unlink keys %files unless ($opt_n);
		print "\n$result\n" if ($opt_t);
		foreach my $sql (keys %deletes)
			{
			&db_do($sql) unless ($opt_n);		# Assume the SQL is self contained, no parameters needed.
			print "$sql\n" if ($opt_t);
			}
		}
	}
&db_disc;
#
# Subroutines:
#
sub addfile
	{
	my $filename = shift;
	$files{$filename}++ if (-f $filename);
	}
sub addsql
	{
	my $sql = shift;
	$deletes{$sql}++;
#
# Is this the first time we have seen this SQL command ?
#
	if ($deletes{$sql} == 1)	
		{
#
# Now do some cleverness to determine a set of INSERT statements that we could use to restore this participant
#
		$sql =~ s/DELETE/SELECT */ig;
		if ($sql =~ /FROM (\w+)/ig)
			{
			my $from = $1;
			my $th = &db_do($sql);
			while (my $href = $th->fetchrow_hashref())
				{
				my (@flist,@vlist);
				foreach my $fld (keys %$href)
					{
					push @flist,$fld;
					$$href{$fld} =~ s/'/''/g;
					push @vlist,$$href{$fld};
					}
				my $isql = "INSERT INTO $from (".join(",",@flist).") VALUES ('".join("','",@vlist)."');";
				$isql =~ s/''/null/g;		# Empty string fails for integer fields, null is safer
				print SQLFILE "$isql\n";
				}
			}
		else
			{print "Warning: could not determine table from DELETE SQL statement: $sql\n";}
		}
	}
#
# End of file
#
1;
