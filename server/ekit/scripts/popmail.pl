#!/usr/bin/perl
#$Id: popmail.pl,v 2.9 2012-01-14 09:30:16 triton Exp $
use strict;
use Net::POP3;
use Net::IMAP::Simple;
use Email::Simple;
use FileHandle;
use Getopt::Long;
use File::Slurp;

use TPerl::Error;
use TPerl::TritonConfig;

sub usage {
    my $msg = shift;
    print qq{$msg
Usage $0 [options]
 options include
  --host          host
  --user          username
  --password      password
  --responder     scripts/asp_mail_responder.pl
  --nodelete      don't delete messages 
  --options       --SID=GOOSE123
  --one_only      only do one message per run.
  --debug         print out cmd.
  --imap          use IMAP instead of POP to fetch
};
    exit;

}
my $host         = 'puffin.triton-tech.com';
my $user         = '';
my $pass         = '';
my $delete       = 1;
my $nodelete;
my $one_only     = 0;
my $responder    = './asp_mail_responder.pl';
my $resp_options = [];
my $doit         = 1;
my $debug        = 0;
my $imap		 = 0;

GetOptions(
    'user:s'      => \$user,
    'password:s'  => \$pass,
    'responder:s' => \$responder,
    'options:s'   => $resp_options,
    'one_only!'   => \$one_only,
    'host:s'      => \$host,
    'nodelete!'     => \$nodelete,
    'debug!'      => \$debug,
	'imap'		  => \$imap,
) || usage('Bad options');

my $e = new TPerl::Error;

usage "user option not set"     unless $user;
usage "password option not set" unless $pass;
$delete = 0 if ($nodelete);
my $resp_cmd = $responder;
unless ( -e $resp_cmd ) {
    my $scriptsdir = getConfig('scriptsDir')
      || $e->F("Could not get 'scriptsDir' from getConfig");
    my $resp_cmd = join '/', $scriptsdir, $responder;
}
$e->F("responder ccommand '$resp_cmd' does not exist") unless -e $resp_cmd;
$e->F("'$resp_cmd' is not executable")                 unless -x $resp_cmd;

my ($pop,$msgs);
if (!$imap){	# default is to use POP3
	print "Connecting to POP3 server: $host\n" if $debug;
	$pop = new Net::POP3($host) or die "Could not connect to POP server: $host";
	$msgs = $pop->login( $user, $pass ) or die "Could not login to $host:$!";
} else {
	print "Connecting to IMAP server: $host\n" if $debug;
	$pop = Net::IMAP::Simple->new($host) ||
           die "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";
# Log on
    if(!$pop->login($user,$pass)){
        print STDERR "Login failed: " . $pop->errstr . "\n";
        exit(64);
    }
	$msgs = $pop->select('INBOX');
}
print "Found $msgs messages\n" if ($debug);

my $options = join ' ', @$resp_options;
my $cmd = "| $resp_cmd $options";
print "Responder = $cmd\n" if $debug;

foreach my $msgnum ( 1 .. $msgs ) {
	my $fh = new FileHandle($cmd) or $e->F("Could not open handle to $cmd");
	if (my $aref = $pop->get($msgnum)) {
		my $buf = join("",@$aref);
		$buf =~ s/\r//g;
		print "$buf\n" if ($debug);
		write_file("$msgnum.txt",$buf) if ($debug);
		print $fh $buf;
		$pop->delete($msgnum) if $delete;
		last if $one_only;
	} else {
		die "Could not get message number $msgnum";
	}
}
$pop->quit();
exit;

	my $imap = Net::IMAP::Simple->new($host) ||
           die "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";
# Log on
    if(!$imap->login($user,$pass)){
        print STDERR "Login failed: " . $imap->errstr . "\n";
        exit(64);
    }
	# print "mesgs=$msgs\n";
	my $options = join ' ', @$resp_options;
	my $cmd = "| $resp_cmd $options";
	print "$cmd\n" if $debug;

    my $nm = $imap->select('INBOX');

    for(my $msgnum = 1; $msgnum <= $nm; $msgnum++){
#        my $es = Email::Simple->new(join '', @{ $imap->top($msgnum) } );
#        printf("[%03d] %s\n", $msgnum, $es->header('Subject'));
		my $date = `date`;
		my $fh = new FileHandle($cmd) or $e->F("Could not open handle to $cmd");
		if ( my $aref = $imap->get( $msgnum) ) {
			$imap->get( $msgnum, $fh );
			print join("\n",$aref) if ($debug);
			write_file("$msgnum.txt",$aref) if ($debug);
#			print $fh,join("",$aref);
			$imap->delete($msgnum) if $delete;
			last                   if $one_only;
		} else {
			die "Could not get message number $msgnum";
		}

    }
    $imap->quit;

