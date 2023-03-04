#!/usr/bin/perl
# Copyright Triton Technology 2001
# $Id: pwikit.jam.pl,v 1.3 2013-05-13 23:28:03 triton Exp $
#
# This script jams the peer and boss verbatims (Q10) into one file
# and now this script puts them into one document for all the peers, and they are grouped by 
# question number, which makes it easier for the workshop leader to digest.
#
use strict;									
use TPerl::MAP; 							
use TPerl::CmdLine; 						
use TPerl::TritonConfig qw (getConfig); 	
use TPerl::Error; 							
use TPerl::MyDB;                            
use TPerl::Object;							

use Data::Dumper; 							
use constant; 								
use DBI; 									
use Getopt::Long; 							
use Cwd; 									
                                            
use File::Path; 							
use File::Temp;                             
use File::Slurp;                            
use FileHandle;   

$| = 1;

#### vars,

my $err = new TPerl::Error;
my $jobs = ['MAP001','MAP010'];
my $m = new TPerl::MAP;
my $err = new TPerl::Error;
my $cmdl = new TPerl::CmdLine;

my (%opts,%cfg);
GetOptions (
	debug		=> \$opts{debug},
) or die usage ('Bad Command line options');

sub usage{
	my $msg = shift;
	print "$msg\n";
	print <<MSG;
Usage $0 [options] ID ID1 ....
	where options include
	-debug	   	 	Show debugging output
MSG
	exit;
}

usage "Error: No IDs supplied on command line" unless  @ARGV;

$cfg{troot} = getConfig ('TritonRoot');

# Check for all configuration parameters being present...
my $errcnt;
print Dumper \%cfg if ($opts{debug});
foreach my $item (keys %cfg) {
	$err->E("Missing config parameter: $item - This is for the target machine (usually Win32) which assembles the MLI spreadsheets") if (!$cfg{$item});
}
#
# Need to be able to look up the latest dfile in a job using the token (passwd)
#
my $tok2dfile = $m->token2dfile (troot=>$cfg{troot}, jobs=>$jobs);

my $dbh = dbh TPerl::MyDB () or die TPerl::MyDB->err;
foreach my $id (@ARGV)
	{
	# for each id make a report
	my $edf = $m->jam_written (id=>$id,
									dbh=>$dbh, 
									token2dfile=>$tok2dfile,
									troot=>$cfg{troot},
									debug=>$opts{debug},
									written=> qq{$cfg{troot}/MAP010A/web/w$id.pl},
									err=>$err);
	die "Error while processing id '$edf->{id}', $edf->{err}\n" if ($edf->{err});
	print "Id $edf->{id} ($edf->{participant}) has $edf->{bosses} boss(es) and $edf->{peers} peer(s), and the file is at $edf->{file}\n" if ($opts{debug});
	unless ($edf->{completes})
		{
		$err->W("ID $edf->{id} ($edf->{participant}) has no complete responses. Skipping");
		next;
		}
	my $cols = $edf->{bosses}+$edf->{peers}+1;
	my $limit = 17;
	$err->E("id $edf->{id} ($edf->{participant}) has more than $limit colums, data after column $limit will be ignored") if $cols>$limit;
	my $cmd = qq{perl ../scripts/mergertf.pl MAP010A  -template=MLIpeer.rtf -data=w$edf->{id}.pl -target=$edf->{id}.rtf};
	my $exec = $cmdl->execute (cmd=>$cmd);
	my $out = $exec->output;
	$out =~ s/\n/<BR>/g;
	print $out;

	}

my $when = localtime();
$err->I("$when Finished") if ($opts{debug});
