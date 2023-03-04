#!/usr/bin/perl
## $Id: 360_restore_docs.pl,v 1.8 2012-04-24 17:21:54 triton Exp $
# Script to unpack all the documents and data for a respondent, 
# and put them back in the right places. 
# Optionally we also reassign the sequence numbers when migrating
# to a another server.
#
# Copyright Triton Information Technology 2004 on...
#
use strict;
use Getopt::Long;							#perl2exe
use File::Copy;								#perl2exe
use File::Path;								#perl2exe
use File::Basename;							#perl2exe
use Data::Dumper;							#perl2exe
use Archive::Zip;							#perl2exe

use TPerl::Error;							#perl2exe

#Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");

our (%config,$dbt,$qt_root,$sfh,$seqno);
require 'TPerl/qt-libdb.pl';
#
our($opt_d,$opt_h,$opt_v,$opt_t,$opt_n,$opt_only,
	$opt_gz,
	$opt_override,
	);
GetOptions (
			help => 	\$opt_h,
			debug => 	\$opt_d,
			trace => 	\$opt_t,
			version => 	\$opt_v,
			noaction => \$opt_n,
			'only=s' => \$opt_only,
			gz =>		\$opt_gz,
			override => \$opt_override,
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
	-only=ID	Only do it for this ID
	-override   Override existing D-files with ones in the archive
	-gz			use Tar/GZip [default is .ZIP] (relies on presence of tar / gzip in path
ERR
	exit 0;
	}
if ($opt_h)
	{
	&die_usage;
	}
if ($opt_v)
	{
	print "$0: ".'$Header: /au/apps/alltriton/cvs/TPerl/360_restore_docs.pl,v 1.8 2012-04-24 17:21:54 triton Exp $'."\n";
	exit 0;
	}

&get_root;
my $archive_root = getServerConfig ('archive');
die "Config item archive= is missing from server.ini\n" if (!$archive_root);

&db_conn;
$dbt = 1 if ($opt_d);

my $srcdir = "$archive_root/participant/";
opendir(SRCDIR,$srcdir) || &die_usage( "cannot read directory: $srcdir");
my $e = new TPerl::Error;
my $when = localtime();
$e->I("Starting $0 at $when");
my $restdir = "$archive_root/participant/restore";
&force_dir($restdir);
my $ext = ($opt_gz) ? "gz" : "zip";
my @zipfiles = grep (/\.$ext/i ,readdir(SRCDIR));
closedir(SRCDIR);
my $zfcnt = 0;
my %cases;
my ($isthere,$havedata);
foreach my $zf (@zipfiles)
	{
	$isthere = $havedata = 0;
	print "Checking archive file: $zf\n" if ($opt_t);
	next if ($opt_only && !($zf =~ /^$opt_only/i ));
	my $id = ($zf =~ /^(\d+)/i) ? $1 : $zf;
	$id =~ s/\..*//g; 
# First up, search the existing database, and cache all the pwd's and seq's
	my $sql = "SELECT * FROM $config{index} where UID=?";
	my $th = &db_do($sql,$id);
	undef %cases;
	while (my $href = $th->fetchrow_hashref)
		{
		$cases{$$href{SID}}{FULLNAME} = $$href{FULLNAME};
		$cases{$$href{SID}}{PWD} = $$href{PWD};
		$isthere++;
		}
	$th->finish;
	foreach my $SID (keys %{$config{snames}})
		{
		my $sql = "SELECT * FROM $SID where UID=? and SEQ>0";
		my $th = &db_do($sql,$id);
		while (my $href = $th->fetchrow_hashref)
			{
			$cases{$SID}{SEQ} = $$href{SEQ};
			$havedata++;
			}
		$th->finish;
		}
# Done caching
	print Dumper \%cases if ($opt_t);
	print "Unpacking file $zf for $id\n" if ($opt_t);
	$zfcnt++;
	if (!$opt_gz)
		{
		my $zip2 = Archive::Zip->new("$srcdir$zf");
		$zip2->extractTree($id,"$restdir/$id");
		undef $zip2;
		}
	else
		{
	# GUnZip them 
		my $tarname = $zf;
		my $cmd = "gunzip $tarname";
		$cmd =~ s/\\/\//g;
		print "Executing cmd: $cmd\n" if ($opt_t);
		my $res = `$cmd`;
		print "$res\n" if ($opt_t);
	# Extract the files
		my $tarname = $zf;
		$tarname =~ s/[\s]/_/ig;
		$tarname =~ s/[\-\+'"\)\(\{\}]//ig;
#		$cmd = "tar cvf $tarname ${base} -P ";
		$cmd =~ s/\\/\//g;
		$cmd =~ s?(\w):?/cygdrive/$1?g if ($^O =~ /win32/i );
		print "Executing cmd: $cmd\n" if ($opt_t);
		my $res = `$cmd`;
		print "$res\n" if ($opt_t);
		}
# Now we have unpacked the file, it's time to run through them 
# and reassign the sequence numbers to avoid a clash.
	my $sfile = qq{$restdir/$id/restore_$id.sql};
	my $sfilenew = qq{$restdir/$id/restore_$id.sql.new};
	my $updfile = qq{$restdir/$id/restore_${id}_update.sql};
	print "Opening sql file: $sfile\n" if ($opt_t);
	open SF,"<$sfile" || die "Could not open SQL file [$sfile]\n";
	open SFN,">$sfilenew" || die "Could not create new SQL file [$sfilenew]\n";
	open UPFN,">$updfile" || die "Could not create update SQL file [$updfile]\n";
	my $lastpwd = 'XY1234';
	my %pass;
	my $updcnt = 0;
	my (%movers,@sqli,@sqlu);
	while (<SF>)
		{
		chomp;
		s/\r//g;
		my $hr = splitsql($_);
		$hr->{hash}{SEQ} = '' if ($hr->{hash}{SEQ} eq 'null');
		print Dumper $hr if ($opt_d);
		my $sp = $hr->{hash}{PWD};
		if ($hr->{table} eq 'MAP_CASES')
			{
			$pass{$sp} = nextpwd($hr->{hash}{SID},$sp) if (!$pass{$sp});
			$hr->{hash}{PWD} = $pass{$sp};
			}
		else
			{		# Fix the ufile:
			my $oldf = qq{$restdir/$id/$hr->{table}/web/u$sp.pl};
			my $newf = qq{$restdir/$id/$hr->{table}/web/u$pass{$sp}.pl};
			my_cp($oldf,$newf,'','',$sp,$pass{$sp});
			$movers{$newf} = qq{$qt_root/$hr->{table}/web/u$pass{$sp}.pl};
			}
		if (($hr->{hash}{SEQ} ne '') && ($hr->{hash}{SEQ} ne '0'))
			{
			my $oldseq = $hr->{hash}{SEQ};
			my $oldf = qq{$restdir/$id/$hr->{table}/web/D$hr->{hash}{SEQ}.pl};
			my $olddoc = qq{$restdir/$id/$hr->{table}/doc/$hr->{hash}{SEQ}.rtf};
			$hr->{hash}{SEQ} = my_nextseq($hr->{table});
			my $newf = qq{$restdir/$id/$hr->{table}/web/D$hr->{hash}{SEQ}.pl};
			my_cp($oldf,$newf,$oldseq,$hr->{hash}{SEQ},$sp,$pass{$hr->{hash}{PWD}});
			$movers{$newf} = qq{$qt_root/$hr->{table}/web/D$hr->{hash}{SEQ}.pl};

			if (-f $olddoc)
				{
				my $newdoc = qq{$restdir/$id/$hr->{table}/doc/$hr->{hash}{SEQ}.rtf};
				my_cp($olddoc,$newdoc,$oldseq,$hr->{hash}{SEQ},'','');
				$movers{$newdoc} = qq{$qt_root/$hr->{table}/doc/$hr->{hash}{SEQ}.rtf};
				}
			my $usql = "UPDATE $hr->{table} set SEQ=$hr->{hash}{SEQ},STAT=$hr->{hash}{STAT} WHERE uid='$hr->{hash}{UID}' and PWD='$hr->{hash}{PWD}'";
			print UPFN qq{$usql;\n};
			push @sqlu,$usql;
			$updcnt++;
			}
		if ($hr->{table} ne 'MAP_CASES')
			{
			$hr->{hash}{PWD} = ($pass{$hr->{hash}{PWD}}) ? $pass{$hr->{hash}{PWD}} : nextpwd($hr->{table});
			}
		my (@k,@v);
		foreach my $key (keys %{$hr->{hash}})
			{
			if (($hr->{hash}{$key} ne '') && ($hr->{hash}{$key} ne 'null'))
				{
				push @k,$key;
				push @v,$hr->{hash}{$key};
				}
			}
		my $keys = join ",",@k;
		my $values = join "','",@v;
		my $sql = qq{INSERT INTO $hr->{table} ($keys) values ('$values')};
		print SFN qq{$sql;\n};
		push @sqli,$sql;
		}
	close(SF);
	close(SFN);
	close(UPFN);
	unlink $updfile unless ($updcnt>0);			# Kill the UPDATE SQL file if we have no data to copy across
#
# Final stage, having assembled all the information and adjusted the D-files etc, we are ready to apply changes
#
	foreach my $src (keys %movers)
		{
		print " * Move $src => $movers{$src}\n" if ($opt_t);
		move $src,$movers{$src};
		}
# Assume they are atomic SQL cmds (no params) and either inserts or updates, so no data is returned
	if (!$isthere)
		{
		foreach my $sql (@sqli)
		 	{&db_do($sql);}
		}
	foreach my $sql (@sqlu)
		{&db_do($sql);}
	move ("$srcdir$zf","${srcdir}done/$zf");		# Move file out of the way for restartability
	rmtree(qq{$restdir/$id});					# Clean out temp files
	}
$e->I("Done: $zfcnt archive files processed");
&db_disc;
#
# Subroutines:
#
sub nextpwd
	{
	my $sid = shift;
	my $oldpwd = shift;
	my $newpwd = $cases{$sid}{PWD};		# Look up the new one
	if ($oldpwd)
		{
		$newpwd = '';
# Can we use the same password again instead of getting a new one?
		my $sql = "SELECT * FROM $config{index} where SID=? and PWD=?";
		my $th = &db_do($sql,$sid,$oldpwd);
		my $href = $th->fetchrow_hashref;
		print Dumper $href if ($opt_t);
		$newpwd = $oldpwd if (!$$href{PWD});
		$th->finish;
		}
	if (!$newpwd)
		{
		$newpwd = db_getnextpwd($sid);
		}
	print "Password for $sid=$newpwd\n" if ($opt_t);
	$newpwd;
	}
sub my_nextseq
	{
	my $sid = shift;
	my $newseq = $cases{$sid}{SEQ};
	if (!$newseq)
		{
		&nextseq();		
		$newseq = $seqno;
		}
	print "Seqno for $sid=$newseq\n" if ($opt_t);
	$newseq;
	}
sub splitsql
	{
	my $sql = shift;
	my %hash;
	my $table = $1 if ($sql =~ /INSERT INTO (\S+) /i);
	my (@keys,@values);
	$sql =~ s/null/'null'/g;		# It irks me to do this
	if ($sql =~ /\((.*?)\) VALUES \('(.*?)'\)/)
		{
		my ($k,$v) = ($1,$2);
		@keys = split(/,/,$k);
		@values = split(/','/,$v);
		for (my $i=0;$i<=$#keys;$i++)
			{
			$hash{$keys[$i]} = $values[$i];
			}
		}
	die "Error parsing SQL string: $sql (table=$table)\n" if (($table eq '') || !%hash);
	{table=>$table, hash => \%hash};
	}

sub my_cp
	{
	my $oldfile = shift;
	my $newfile = shift;
	if ($oldfile ne $newfile)
		{
		my $oldseq = shift;
		my $newseq = shift;
		my $oldpass = shift;
		my $newpass = shift;
		if (-f $oldfile)
			{
			print "Copy $oldfile => $newfile\n" if ($opt_t);
			open (IN,"<$oldfile") || die "Error $! while opening $oldfile\n";
			open (OU,">$newfile") || die "Error $! while opening $newfile\n";
			while (<IN>)
				{
				chomp;
				s/\r//g;
				s/\s*'seqno','\d+/\t'seqno','$newseq/ig;
				s/\s*'password','\w+/\t'password','$newpass/ig;
				s/\s*'password' => '\w+/\t'password','$newpass/ig;
				s/fs16 $oldseq\(/fs16 $newseq\(/ig;
				print OU "$_\n";
				}
			close IN;
			close OU;
			}
		else
			{
			$e->W("File not found $oldfile for copy operation");
			}
		}
	}
#
# End of file
#
1;
