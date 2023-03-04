#!/usr/local/bin/perl
#
# unixstuff.pl
#
# This file contains stuff that is Unix specific - a regrettable move away from
# a universal solution, but necessary for ease of setup under NT.
#
# CVS $Id: ntstuff.pl,v 2.3 2004-11-03 04:31:41 triton Exp $

use TPerl::TritonConfig;
use Fcntl qw(:flock);

$virtual_cgi_bin = "/cgi-mr/";          # cgi-bin directory

our $t = getConfig ('EngineTrace');			# Trace mode - writes diagnostic stuff to /triton/log/triton.log
$mike = 1;		# Shows some stuff at the bottom of the HTML page
#$use_tnum = 1;
$use_q_labs = 1;
$dbt=getConfig('DbTrace');
$db_isib = 1 if lc(getdbConfig('EngineDB')) eq 'ib' ;		# Use Interbase on local machine
$chmod = 0660;
our $read_only = getConfig ('ReadOnly');

sub get_root
    {
    $extension = getServerConfig ('extension');
    $qt_root = getServerConfig ('TritonRoot');
    $qt_droot = getServerConfig ('TritonDRoot');
    my ($wkstid, $wkstid2) = GetWKSTID;
    $editor = getServerConfig ('editor');

# Interbase settings:
	$ib_db_file = getdbConfig('ib_db_file');
	$ib_db_user = getdbConfig('ib_db_user');
	$ib_db_password = getdbConfig('ib_db_password');
# master DB
	$ib_master_db_file = getdbConfig('ib_master_db_file');
	$ib_master_db_user = getdbConfig('ib_master_db_user');
	$ib_master_db_password = getdbConfig('ib_master_db_password');
# MySQL settings:
	$mysql_db_file = getdbConfig('mysql_db_file');
	$mysql_db_user = getdbConfig('mysql_db_user');
	$mysql_db_password = getdbConfig('mysql_db_password');
# Provide a soft landing if these params are missing (Workaround for bug in server.ini file as deployed in the field for QIMR)
$mysql_db_file = 'triton' if ($mysql_db_file eq '');
$mysql_db_user = 'triton' if ($mysql_db_user eq '');
$mysql_db_password = '' if ($mysql_db_password eq '');
# ODBC Settings:
	$odbc_db_file = getdbConfig('odbc_db_file');
	$odbc_db_user = getdbConfig('odbc_db_user');
	$odbc_db_password = getdbConfig('odbc_db_password');
    }

sub nextseq
    {
    &subtrace;
	my $inidir = getInidir || '/triton';
	my $filename = "$inidir/seqno.txt";		# Input file
	my $ofilename = "$inidir/seqno.txt";	# Output file
	unless (-e $filename){
		open SEQ_FILE,">$filename";
		close SEQ_FILE;
	}
	$filename = "seqno.txt" if (! -f $filename);	# read from local file if /cfg/seqno.txt not there
	# a race condition occurs if several processes call this function before the first one has had a chance
	# to rewrite the seqno file (hoever unlikeley this may seem)...
	# lets do some file locking and stop this
    &debug("Opening sequence no file: $filename");
    if (open (SEQ_FILE, "+<$filename"))
        {
		if (flock (SEQ_FILE,LOCK_EX))
            {
            $seqno = <SEQ_FILE>;
# Make it start at 800  to save possible seqno overlap problems
			$seqno ||= 799;
            $seqno++;
			seek (SEQ_FILE,0,0);
        	print SEQ_FILE "$seqno\n";
			flock (SEQ_FILE,LOCK_UN);
			close SEQ_FILE
            }
        }
    else
        {
        die "Please Try again later.\n(Cannot open file $filename for writing)\n";
        }
    &endsub;
    }
    
sub nextbatch
    {
    my $sid = shift;
    my $batchno;
    &subtrace('nextbatch',$sid);
    my $filename = "$qt_root/$sid/web/batch.txt";
    &debug("Opening batch no file: $filename");
    if (open (BATCH_FILE, "<$filename"))
        {
        while (<BATCH_FILE>)
            {
            $batchno = $_;
            $batchno++;
            last;
            }
        close(BATCH_FILE);
        }
    else
        {
#       print "Starting new batchno\n";
        $batchno = 100;
        }
#
# Now write the new number back to the file
#
    if (open (BATCH_FILE, ">$filename"))
        {
        print BATCH_FILE "$batchno\n";
        close(BATCH_FILE);
        }
    else
        {
#       print "Cannot open file $filename for writing\n";
        }
    &endsub;
    $batchno;
    }

#
# Needed for inclusion
#
1;

