#!/usr/bin/perl
# Copyright Triton Technology 2001
# $Id: map_report_data.pl,v 1.30 2012-11-27 00:22:29 triton Exp $
#
# This script does the assembly of the Management and Leadership Inventory (MLI) data.
# It takes the quantitative responses from the participant, his boss(es) and peers, 
# and puts them into a spreadsheet, which averages the responses, and plots some graphs 
# of the relative scores. The spreadsheet is used by the workshop leader to assess the
# participant.
#
# The peer responses (Q10) (both qual and quant) used to be assembled into individual documents, 
# but now this script puts them into one document for all the peers, and they are grouped by 
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
my $jobs = ['MAP002','MAP012','MAP010'];
my $m = new TPerl::MAP;
my $err = new TPerl::Error;
my $cmdl = new TPerl::CmdLine;

my (%opts,%cfg);
GetOptions (
	debug		=> \$opts{debug},
	'batch=s'	=> \$opts{batch},
) or die usage ('Bad Command line options');

sub usage{
	my $msg = shift;
	print "$msg\n";
	print <<MSG;
Usage $0 [options] ID ID1 ....
	where options include
	-debug	   	 	Show debugging output
	-batch=xxx.bat	Batch them all up into this filename
MSG
	exit;
}

usage "Error: No IDs supplied on command line" unless  @ARGV;

#
# There are different templates for different numbers of bosses
#
	my $templates = {
		0=>"MLIR0boss.xlt",
		1=>"MLIR1boss.xlt",
		2=>"MLIR2boss.xlt",
		3=>"MLIR3boss.xlt",
		4=>"MLIR4boss.xlt",
		5=>"MLIR5boss.xlt",
		6=>"MLIR6boss.xlt",
		7=>"MLIR7boss.xlt",
		8=>"MLIR8boss.xlt",
	};
$cfg{troot} = getConfig ('TritonRoot');
$cfg{xlspath} = getConfig('xlspath');
$cfg{txtpath} = getConfig('txtpath');
$cfg{dosbin} = getConfig('dosbin');
$cfg{dosbin} =~ s/[\/\\]$//;			# Get rid of trailing slash on this
$cfg{dosbin} =~ s/\//\\/g;			# DOS format for cmd itself
$cfg{dosroot} = getConfig('dosroot');
$cfg{dosroot} =~ s/[\/\\]$//;		# Get rid of trailing slash on this
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
my $bfh;
my $filename = ($opts{batch}) ? $opts{batch} : "mli.bat";
my $bfile = qq{$cfg{troot}/MAP101/html/admin/$filename};
open $bfh,">$bfile" || die "Error $! encountered while writing to file: $bfile\n";
foreach my $id (@ARGV)
	{
	# for each id make a report
	my $edf = $m->excel_data_file (id=>$id,
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
	my $tmpl = $templates->{$edf->{bosses}};	# Template file to use
	$err->I("ID $edf->{id} ($edf->{participant}) has $edf->{bosses} boss(es) and $edf->{peers} peer(s), using template $tmpl");
	my $cmd = qq{perl ../scripts/mergertf.pl MAP010A  -template=MLIpeer.rtf -data=w$edf->{id}.pl -target=$edf->{id}.rtf};
	my $exec = $cmdl->execute (cmd=>$cmd);
	my $out = $exec->output;
	$out =~ s/\n/<BR>/g;
	print $out;

#	unless (-e $cfg{txtpath})
#		{
#		mkpath ($cfg{txtpath},1) or 
#			$err->F("Could not make '$cfg{txtpath}' :$!\n");
#		}
	if ($opts{batch})		# Do we want everything in a humungous DOS batch file ?
		{
		my $when = localtime();
		my $fillfile = "$cfg{txtpath}/$edf->{id}_MLI.txt";		# Resultant output file
		my $destxls = "$cfg{xlspath}/$edf->{targetname}-MLI.xls";		# Resultant output file
		$fillfile =~ s/\//\\/g;
		my $template = qq{$cfg{dosroot}\\MAP101\\templates\\$tmpl};
		my $drive = $cfg{dosbin};
		if ($drive =~ /^(\w:)/)
			{
			$drive = $1;
			print $bfh qq{$drive\n};
			}
		print $bfh qq{cd $cfg{dosbin}\n};
		my $cmd = qq{$cfg{dosbin}\\Excel_Filler $template $fillfile $destxls};
		print $bfh qq{\@echo # MAP ID=$edf->{id} DOS COMMAND=$cmd >$fillfile\n};
		open FILL,"<$edf->{file}" || warn "Error $! encountered while reading file: $edf->{file}\n";
		while (<FILL>)
			{
			chomp;
			s/\r//;
			s/\&/^&/g;
			print $bfh qq{\@echo $_ >>$fillfile\n};
			}
		close FILL;
		print $bfh qq{$cmd\n};
		}
	}
