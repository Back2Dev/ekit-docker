#!/usr/bin/perl
#$Id: aspupdate_htaccess.pl,v 1.5 2007-05-08 04:45:15 triton Exp $
use strict;
use TPerl::TritonConfig;
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::CmdLine;
use TPerl::LookFeel;
use FindBin;
use File::Slurp;

my $sulist = [qw(mikkel ac)];
my $authdir = getConfig('authDir');
my $authfile = (-f "$authdir/.htaccess") ? "$authdir/.htaccess" : "$authdir/authdb";
my $dbh = dbh TPerl::MyDB ();
my $lf= new TPerl::LookFeel;

my $q = new TPerl::CGI;
my %args = $q->args;


my $uid = $ENV{REMOTE_USER};
$q->mydie ("Could not connect to db") unless $dbh;
$q->mydie ("No authDir entry from getConfig") unless $authdir;
$q->mydie ("authdir $authdir does not exist") unless -e $authdir;
$q->mydie ("$uid is not in the superuserlist") unless grep $uid eq $_,@$sulist;

my $sql = 'select UID,PWD from TUSER';
my $cmd = new TPerl::CmdLine;

$q->mydie ($q->dberr(sql=>$sql,dbh=>$dbh)) unless my $sth = $dbh->prepare($sql);
$q->mydie ($q->dberr(sql=>$sql,dbh=>$dbh)) unless $sth->execute();

my $htaccesfn = join '/',"$FindBin::Bin",'.htaccess';


print join "\n",
	$q->header,
	$q->start_html(-title=>'Updating htacess file',-style=>{src=>'style.css'}),'';
	
	unless (-e $htaccesfn){
		my $fqdn = getConfig('FQDN') or die "Could not get FQDN from getConfig";
		my $htcont = join "\n",
			qq{AuthUserFile  $authfile},
			qq{AuthName "$fqdn Administation Panel"},
			qq{AuthType Basic},
			qq{Require valid-user},'';
		print join "\n",
			$lf->sbox('making .htaccess file'),
			$htaccesfn,
			$htcont,
			$lf->ebox;

		write_file ($htaccesfn, $htcont) or die "Could not write $htaccesfn:$!";
	}
	
	print join "\n",'',$lf->sbox("Updating htpasswd file"),'';

while (my $row = $sth->fetchrow_hashref()){
	# print $q->dumper($row);
	my $flag = 'c' unless -e $authfile;
	my $htpwdcmd = ($^O =~ /Win32/i) ? qq{c:\\apps\\apache2\\bin\\htpasswd} : qq{htpasswd};
	my $exec = $cmd->execute(cmd=>"$htpwdcmd -b$flag $authfile $row->{UID} $row->{PWD}");
	if ($exec->success){
		print "updated user $row->{UID}<br>\n";
	}else{
		$q->mydie($exec->output);
	}
}
print $lf->ebox,$q->end_html;

