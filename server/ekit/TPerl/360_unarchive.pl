#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_unarchive.pl,v 2.3 2012-04-24 17:10:21 triton Exp $
#
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# pwikit_unarchive.pl - Unarchive function
#
# This is a generic function - assumes require statements already done.
#
use CGI::Carp qw(fatalsToBrowser);
use File::Copy;
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 1;
$rolename = 'admin';

#--------------------------------------------------------------------------------------------
# Start of main code 
#
#&ReadParse(*input);
our $q = new TPerl::CGI;
our %input = $q->args;
#
print "Content-Type: text/html\n\n";
print "<HTML>\n";
&db_conn;
#
$survey_id = $config{master};			# This is a hack to use MAP101 as the central authentication spot
$resp{'survey_id'} = $survey_id;
$id = $input{'id'};
&add2hdr(qq{<TITLE>$config{title} </TITLE>});
&add2hdr(qq{   <META NAME="Triton Information Technology Software">}); 
&add2hdr(qq{   <META NAME="Author" CONTENT="Mike King (213) 488 2811">});
&add2hdr(qq{   <META NAME="Copyright" CONTENT="Triton Technology 1995-2003">});
&add2hdr(qq{<link rel="stylesheet" href="/$config{case}/style.css">});

my $arch = getServerConfig ('archive');
my $dest = getServerConfig ('TritonRoot');

my $sql = "select FULLNAME,PWD,SID from $config{index} where casename='$config{case}' and uid='$id'";
&db_do($sql);
my $aref = $th->fetchall_arrayref;
$th->finish;
my $n = 1;
foreach my $rrow (@{$aref})
	{
	my $fullname = $$rrow[0];
	my $pwd = $$rrow[1];
	my $sid = $$rrow[2];
	my $sql = "select stat,seq from $sid where pwd='$pwd'";
#	$dbt = 1;
	&db_do($sql);
	my @row = $th->fetchrow_array;
	my $stat = $row[0];
	my $seq = $row[1];
	&add2body("$n: $fullname $pwd $sid stat=$stat, seq=$seq<BR>\n");
	$srcfile = qq{$arch/$sid/web/u$pwd.pl};
	$dstfile = qq{$dest/$sid/web/u$pwd.pl};
	if (-f $dstfile)
		{
		&add2body("$dstfile exists, not copied<BR>\n");
		}
	elsif (!(-f $srcfile))
		{
		&add2body("$srcfile does not exist in archive, not copied<BR>\n");
		}
	else 
		{
		&add2body("$srcfile => $dstfile<BR>\n");
		copy($srcfile,$dstfile);
		}
	if ($seq > 0)
		{
		$srcfile = qq{$arch/$sid/web/D$seq.pl};
		$dstfile = qq{$dest/$sid/web/D$seq.pl};
		if (-f $dstfile)
			{
			&add2body("$dstfile exists, not copied<BR>\n");
			}
		elsif (!(-f $srcfile))
			{
			&add2body("$srcfile does not exist in archive, not copied<BR>\n");
			}
		else 
			{
			&add2body("$srcfile => $dstfile<BR>\n");
			copy($srcfile,$dstfile);
			}
		$srcfile = qq{$arch/$sid/doc/$seq.rtf};
		if (-f $srcfile)
			{
			$dstfile = qq{$dest/$sid/doc/$seq.rtf};
			if (-f $dstfile)
				{
				&add2body("$dstfile exists, not copied<BR>\n");
				}
			elsif (!(-f $srcfile))
				{
				&add2body("$srcfile does not exist in archive, not copied<BR>\n");
				}
			else 
				{
				&add2body("$srcfile => $dstfile<BR>\n");
				copy($srcfile,$dstfile);
				}
			}
		}
	$n++;
	}



&db_disc;
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;
1;
