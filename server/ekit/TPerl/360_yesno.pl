#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_yesno.pl,v 1.1 2012-04-11 12:47:00 triton Exp $
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 360_yesno.pl - Approves / rejects a form
#
# Assumes require's have been done already
#
use CGI::Carp qw(fatalsToBrowser);

use TPerl::Event;
use TPerl::CmdLine;
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 1;
#--------------------------------------------------------------------------------------------
# Subroutines
#



#--------------------------------------------------------------------------------------------
# Start of main code 
#
our $q = new TPerl::CGI;
our %input = $q->args;
#
print "Content-Type: text/plain\n\n";
&db_conn;
#
# This is really simple, just decode the incoming URL and update the database to suit, 
#
#print "$ENV{PATH_INFO}\n";
my ($null,$SID,$action,$pwd,$uid) = split(/\//,$ENV{PATH_INFO});
die "Missing SID\n" if (!$SID);
die "Missing Action\n" if (!$action);
die "Missing PWD\n" if (!$pwd);
die "Missing UID\n" if (!$uid);

my %config = ( 	approve => {number => 1, echo => 'Approved',},
				reject =>  {number => 2, echo => 'Rejected'},
			);
my $newnumber = $config{$action}{number};
my $newvalue = $config{$action}{echo};

# then echo OK=<PWD> to let the web page know it was OK
my $sql = qq{UPDATE $SID SET APPROVED=$newnumber where PWD="$pwd"};
&db_do($sql);
#
# Update the status data
#
my $cmdline = new TPerl::CmdLine;
my $cmd = qq{perl ../scripts/pwikit_prime_status.pl -only=$uid};
#print "$cmd\n";
my $exec = $cmdline->execute(cmd=>$cmd);
if ($exec->sucess){
}else{
#$err->E( "Not OK ".$exec->output );
#print " ".$exec->output."<br>\n";
}

print "$pwd=$newvalue\n";
#
# OK, we're done now
#
&db_disc;
1;
