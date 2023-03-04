#!/usr/bin/perl 
# Copyright Triton Technology 2002
# $Id: aspmailer.pl,v 1.7 2005-09-26 02:07:03 triton Exp $

BEGIN {
	# need to be in the dir we are run from  to TPerl::TritonConfig.pm will work.
	use FindBin;
	chdir "$FindBin::Bin";
}

use strict;
use TPerl::MyDB;
use TPerl::ASP;
use Data::Dumper;
use Getopt::Long;

my $db = '';
my $debug = 1;
my $show_only = 0;

GetOptions (
	'debug+'=>\$debug,
	'db:s'=>\$db,
	'show_only!'=>\$show_only,
) or die qq{
	usage:$0 [options]
		options include 
		-debug
		-db='ib'
		--show_only
};

my $dbh = dbh TPerl::MyDB (db=>$db);
my $asp = new TPerl::ASP (dbh=>$dbh);

my $err= $asp->email_work(debug=>$debug,show_only=>$show_only);
print "Errors occured ".Dumper $err if $err;

