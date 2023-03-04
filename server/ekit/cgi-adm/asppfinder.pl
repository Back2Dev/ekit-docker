#!/usr/bin/perl
#$Id: asppfinder.pl,v 1.5 2005-12-08 03:53:21 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::TritonConfig;
use TPerl::CGI;
use TPerl::LookFeel;
use TPerl::DBEasy;
use TPerl::MyDB;
use TPerl::Event;
use TPerl::PFinder;

my $lf = new TPerl::LookFeel;
my $q = new TPerl::CGI;

my %args = $q->args;
my $SID= $args{SID};

# You must provide a Job ID.
unless ($SID){
	print $q->noSID;
	exit;
}

### This is a frames page that lets you search for a person in the
# table, to update any status values, and then to examine any events
# from the event log for that person.
#
# left is the frame with the search form
# right1 if the result of the search 
# right2 is the event log view.

# This works by using the path info to select the frame we want to make.
unless ($ENV{PATH_INFO}){
	my $qs = "?SID=$SID";
	print $q->header,
	qq{
		<HTML>
		<HEAD>
		<TITLE>$SID Person Finder</TITLE>
		</HEAD>
		<FRAMESET ROWS="135,*" NORESIZE BORDER="0">
			<FRAME NAME="top" SRC="$ENV{SCRIPT_NAME}/top$qs" >
			<FRAMESET COLS="200,*"  BORDER="2">
				<FRAME NAME="left" SRC="$ENV{SCRIPT_NAME}/left$qs" BORDER="0" >
				<FRAMESET ROWS="300,*"  BORDER="0">
					<FRAME NAME="right1" SRC="$ENV{SCRIPT_NAME}/right1$qs" BORDER="0">
					<FRAME NAME="right2" SRC="$ENV{SCRIPT_NAME}/right2$qs" BORDER="0">
				</FRAMESET>
			</FRAMESET>
		</FRAMESET>
		<NOFRAMES>
				Your browser does not support frames. 
				Please click <A HREF="$ENV{SCRIPT_NAME}/left$qs" >here </A> to continue
		</NOFRAMES>
		</HTML>
	};
	exit;
}

### make the database connection.
my $dbh = dbh TPerl::MyDB (attr=>{RaiseError=>0,PrintError=>0}) or die "Could not connect:".TPerl::MyDB->err();

my $pf = new TPerl::PFinder(dbh=>$dbh,cgi=>$q,look=>$lf,SID=>$SID);

### If we get here then we have some path info.  print the appropriate bit
print join "\n",
	$q->header,
	$q->start_html (-title=>"$SID Person Finder",-style=>{src=>"/$SID/style.css"});
print $pf->top() if $ENV{PATH_INFO} eq '/top';
print $pf->left() if $ENV{PATH_INFO} eq '/left';
print $pf->right1(%args) if $ENV{PATH_INFO} eq '/right1';
print $pf->right2(%args) if $ENV{PATH_INFO} eq '/right2';
print $pf->right3(%args) if $ENV{PATH_INFO} eq '/right3';
print $q->end_html;

