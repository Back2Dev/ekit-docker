#!/usr/bin/perl
#$Id: upload_data.pl,v 1.5 2012-01-19 01:06:27 triton Exp $
use strict;
use CGI::Carp qw (fatalsToBrowser);
use POSIX;
use Date::Manip;
use File::Copy;
use File::Touch;
use File::Touch;

use TPerl::CGI;
use TPerl::UploadData;
use TPerl::LookFeel;
use TPerl::Upload;
use TPerl::Survey;
use TPerl::TritonConfig;
use TPerl::TSV;
use TPerl::MyDB;
use TPerl::DBEasy;
use TPerl::StatSplit;
# use HTML::Tooltip::Javascript;

my $sulist = [qw(ac mikkel)];

my $q = new TPerl::CGI;
my %args = $q->args();

my $SID = $args{SID} or print ($q->noSID.$q->dumper(\%args)) and exit;
my $upd = new TPerl::UploadData(SID=>$SID,CGI=>$q);

unless ($ENV{PATH_INFO}){
	#$q->mydie( $q->frameset(qs=>"?SID=$SID"));
	print $q->frameset(qs=>"?SID=$SID");
	exit;
}
print ($upd->top()) and exit if $ENV{PATH_INFO} eq '/top';
print ($upd->left()) and exit if $ENV{PATH_INFO} eq '/left';
print ($upd->upload()) and exit if $ENV{PATH_INFO} eq '/upload';
print ($upd->file_manage()) and exit if $ENV{PATH_INFO} eq '/right';
print ($upd->table_edit()) and exit if $ENV{PATH_INFO} eq '/table_edit';

