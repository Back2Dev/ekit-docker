#!/usr/bin/perl
#$Id: asppfinder_cp.pl,v 1.3 2007-02-12 23:36:51 triton Exp $
# This is a wrapper round the stuff in asppfinder, except its designed to go into the 
# a single frame called 'right' and is accessed by the control panel

use strict;
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::TritonConfig;
use TPerl::CGI;
use TPerl::LookFeel;
use TPerl::MyDB;
use TPerl::Event;
use TPerl::PFinder;

my $lf = new TPerl::LookFeel;
my $q = new TPerl::CGI;

my %args = $q->args;
my $SID= $args{SID};

# You must provide a Job ID.
$q->mydie("No SID supplied") unless $SID;

my $dbh = dbh TPerl::MyDB or $q->mydie("Could not connect to database:".TPerl::MyDB->err);

my $pf = new TPerl::PFinder(dbh=>$dbh,cgi=>$q,look=>$lf,SID=>$SID);

print join "\n",
    $q->header,
	$q->start_html (-title=>"$SID Person Finder",-style=>{src=>"/$SID/style.css"});

my $pwd_sprintf = 
       {fmt=>qq{<a target="_self" href="$ENV{SCRIPT_NAME}/right2?SID=$SID&PWD=%s">%s</a>},
	   names=>[qw(PWD PWD)]};


print $pf->right1(%args,limit=>$args{limit}||10,pwd_sprintf=>$pwd_sprintf) if $ENV{PATH_INFO} eq '/right1';
print $pf->right2(%args,evlog_link=>0,do_head=>1) if $ENV{PATH_INFO} eq '/right2';
print $pf->right3(%args) if $ENV{PATH_INFO} eq '/right3';

print $q->end_html;

