#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: getjs.pl,v 1.1 2012-11-29 01:59:11 triton Exp $
#
# Perl library for QT project
#
$copyright = "Copyright 2012 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# getjs.pl - retrieves a javascript document
#
#
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;

my $q = new TPerl::CGI;
my %args = $q->args;
my $name = getvarname(\%args);
my $jsfile = getfilename(\%args,$args{$name});
if (-f $jsfile)
	{
	if (!open (JS,"<$jsfile"))
		{
		print "Content-Type: text/html\n\n";
		print "<HTML>\n";
		die "Error $! opening file: $jsfile\n";
		}
	else
		{
		print "Content-Type: text/javascript\n\n";
		print "$name = ";
		while (<JS>)
			{
			print;
			}
		close(JS);
		}
	}
else
	{
	print "Content-Type: text/html\n\n";
	print "<HTML>\n";
	die"Sorry, I cannot open that file: $jsfile\n";
	}
sub getvarname {
	my $a = shift;
	my $n = "extras";							# Provide a default name
	$n = $$a{varname} if ($$a{varname});		# Have they supplied a varname?
	$n;
}
sub getfilename {
	my $a = shift;
	my $n = shift;
	my $f = qq{$ENV{DOCUMENT_ROOT}/$n} if (-f qq{$ENV{DOCUMENT_ROOT}/$n});
	$f;
}
1;
