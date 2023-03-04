#!/usr/bin/perl
#$Id: map_tables.pl,v 1.2 2007/02/24 11:35:36 triton Exp $
use strict;
use Getopt::Long;
use FileHandle;
use Data::Dumper;

use TPerl::MAP;
use TPerl::Error;
use TPerl::MyDB;

my $e = new TPerl::Error;

my $dump = 0;
my $read = 0;
my $dump_file = 'db_dump_MAP';
my $drop = 0;
my $create = 0;
my $db  ;
my $help = 0;
my $debug = 0;

GetOptions (
        'dump+'=>\$dump,
        'read+'=>\$read,
        'file:s'=>\$dump_file,
        'create+'=>\$create,
        'drop+'=>\$drop,
        'db:s'=>\$db,
        'help+'=>\$help,
		'debug!'=>\$debug,
) or $e->F("Bad Options");

my $thing = new TPerl::MAP;

my $tables = $thing->table_create_list;
my $dbh = $thing->dbh;
if ($dump){
	my $fh = new FileHandle ("> $dump_file") or die "canna open dump file for writing:$!";
	die "table4file error:$_" if $_ = $thing->tables2file(fh=>$fh,dbh=>$dbh);
}
my %args = ();
$args{create} = $tables if $create;
$args{drop} = $tables if $drop;

my $err = $thing->do_tables(%args);
print "do_tables error ".Dumper $err if $err;

if ($read){
	my $fh = new FileHandle $dump_file or $e->F("Could not open '$dump_file':$!");
	my $errs = $thing->file2tables(fh=>$fh);
	print Dumper $errs if $errs;
}
