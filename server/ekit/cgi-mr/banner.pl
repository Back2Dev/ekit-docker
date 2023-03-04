#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: banner.pl,v 2.0 2004-03-29 02:21:10 triton Exp $
#
# Perl library for QT project
#
use strict;
our %input;
my $copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# ebanner.pl - Retrieves banner for survey and logs the email being read
#
#
require 'TPerl/cgi-lib.pl';

my $delim = '|';
#
# Start of main code 
#
&ReadParse(*input);

# Necessary Variables
my $basedir = $ENV{'DOCUMENT_ROOT'};		# It picks up the HTML DocumentRoot this way

# Options
my $uselog = 1; # 1 = YES; 0 = NO
my $logdir = "../triton/log";
if (!-d $logdir)		# If it's not there, auto-create it
		{
		mkdir($logdir,0777) || die "Cannot create log directory: $logdir\n";
		}
my $logfile = "$logdir/piclog";

# Done
##############################################################################

my $magic = $input{'id'};
my ($type,$survey_id,$pwd) = split(/-/,$magic);
open (TRACE,">> $logfile") || warn "Error $! opening trace file: $logfile\n";
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$mon++;
$year += 1900;
my $tss = "$year-$mon-$mday $hour:$min:$sec";
my $buf = join($delim,(time(),$tss,$type,$survey_id,$pwd,$ENV{'REMOTE_ADDR'},$ENV{'HTTP_USER_AGENT'}));
print TRACE "$buf\n";
close TRACE;
# Log Image
my $filename = "$basedir/$survey_id/banner.gif";
$filename = "$basedir/$survey_id/banner.jpg" if (!-f $filename);
$filename = "$basedir/pix/banner.gif" if (!-f $filename);		# Look for the default one
if (!open (IMG,"< $filename"))
	{
#	print LOG "Error $! reading file: $filename\n";
	die "\n";
	}
my $ftype = 'gif';
$ftype = 'jpeg' if ($filename =~ /\.jpg/);
print "Content-type: image/$ftype\n\n";
binmode(IMG);
binmode(IMG);
binmode(STDOUT);
while(<IMG>) 
	{
	print;
	}	
close(IMG);
1;
