#!/usr/bin/perl
#$Id: maillog_events.pl,v 1.2 2007-09-10 09:45:36 triton Exp $
use strict;
use TPerl::TritonConfig;
use TPerl::MyDB;
use TPerl::Error;
use TPerl::CmdLine;
use Getopt::Euclid;
use Data::Dumper;
use File::Slurp;
use Parse::Syslog::Mail;
use TPerl::Event;

=head1 SYNOPSIS

Gets the maillogs from the smtp_host and then parses them inserting events

=head1 VERSION $Revision: 1.2 $

=head1 OPTIONS

=item --[no]sync

Sync the files from smtp_host.

=for Euclid:
	false: --nosync

=cut

# print Dumper \%ARGV;

my $e = new TPerl::Error;

my $smtp_host = getConfig('smtp_host')
  or $e->F("Could not get 'smtp_host' from getConfig");
my $hroot = getConfig('HostRoot')
  or $e->F("Could not get 'HostRoot' from getConfig");
my $maillog_dir = "$hroot/maillogs/";

if ( $ARGV{'sync'} ) {

 # First sync the maillogs to here.
 # Look in the server.ini on $smtp_host vhost to find the userpasswd (puffin has
 # an old verison and the passwd is hard coded in the script.
    my $cmds = [
"wget -O - 'http://$smtp_host/master-sync-adm/sync_open.pl?pwd=sync!now'",
        "rsync -e ssh -tulvz root\@$smtp_host:/var/log/mail* $maillog_dir",
"wget -O - 'http://$smtp_host/master-sync-adm/sync_open.pl?pwd=sync!now&close=1'"
    ];
    foreach my $cmd (@$cmds) {
        my $exec = TPerl::CmdLine->execute( cmd => $cmd );
        $e->F( $exec->output ) unless $exec->success();
    }
}

my $dbh = dbh TPerl::MyDB;

my $scheme_sth = $dbh->prepare( '
Select SENDMAIL_ID,
       SID,
       PWD
From   EMAIL_MSG_STATUS,
       EMAIL_TRACK_STATUS,
       EMAIL_SCHEME_STATUS
Where  EMAIL_SCHEME_STATUS.EMAIL_SCHEME_STATUS_ID = EMAIL_TRACK_STATUS.EMAIL_SCHEME_STATUS_ID
       And EMAIL_TRACK_STATUS.EMAIL_TRACK_STATUS_ID = EMAIL_MSG_STATUS.EMAIL_TRACK_STATUS_ID
       And SENDMAIL_ID =?
' ) or $e->F( { errstr => $dbh->errstr } );

# my $scr = new Term::Screen;

my $event_codes = {
    sent    => 82,
    bounced => 32,
	'sender non-delivery notification'=>80,
    expired => 80,
};
my $ev = new TPerl::Event( dbh => $dbh );
my $ev_sths  = {};
my $sid_sths = {};

foreach my $f ( '/var/log/mail.log','/var/log/mail.log.1' ) {	# sort (read_dir($maillog_dir))
	next if $f =~/^\./;
	my $fn = $f;
    $fn = "$maillog_dir/$f" unless $f =~ m#^/# ;

    print "$fn\n";
    my $mlp = new Parse::Syslog::Mail($fn);

    my $line = 0;
    while ( my $r = $mlp->next ) {
        $line++;
        next unless my $id = $r->{id};
		next unless defined $r->{status};
        next if $r->{status} =~ /^deferred/;
        next if $r->{status} =~ /^skipped/;
        next if $r->{status} =~ /^removed/;
		# Defer messages from yahoo
		next if $r->{status} =~ m#http://help.yahoo.com/help/us/mail/defer/defer-06.html#;
		# Other wierd (malformed?) server responses
		next if $r->{status} =~ /lost connection with(.*?)while receiving the initial server greeting/;
		# This one is a delay too
		next if $r->{status} =~ /host(.*?) refused to talk to me:/;
		next if $r->{status} =~ /conversation with (.*?) timed out while sending end of data/;
		next if $r->{status} =~ /Temporarily rejected\. Try again later\./;
		next if $r->{status} =~ /Please try again later/;
		# This seems to be a transient thing we can ignore.
		next if $r->{status} =~ /host (.*) said: 451 Application error/;
		# This is a delay also.
		next if $r->{status} =~ /host (.*) said: 450/;

		# This is a warning we can ignore
		next if $r->{status} =~ /enabling PIX <CRLF>.<CRLF> workaround for/;


        my $s_rows =
          $dbh->selectall_arrayref( $scheme_sth, { Slice => {} }, $id );
        next unless @$s_rows;

        if( @$s_rows > 1){
        	$e->E( "Skipping: More than one row for SENDMAIL_ID '$id'" . Dumper $s_rows)
		}else{
			# postfix on yingyang is different.
			my ($lu) = $r->{status} =~ /^(sender non-delivery notification):/;
			if ($lu eq ''){
				($lu) = $r->{status} =~ /^(\S+)/;
			}
			$lu =~ s/\W$//;    # strip trailing puntuation 'expired,'

			unless ( $event_codes->{$lu} ) {
				$e->F("Can't find event for '$lu' in $r->{status}".Dumper $r);
				next;
			}

			# print $id.' '.Dumper $r;
			# print Dumper $s_rows;
			#$scr->puts("At line $line");

			# print "At line $line $s_rows->[0]->{SID} $r->{status}" .Dumper $r;
			# last if $line >16360;
			my $SID = $s_rows->[0]->{SID};
			my $pwd = $s_rows->[0]->{PWD};
			$ev_sths->{$SID} ||= $dbh->prepare("select count(*) from ${SID}_E where TS=? and EVENT_CODE=?");
			my $ev_count =  $dbh->selectcol_arrayref($ev_sths->{$SID},{RaiseError=>1,PrintError=>1},$r->{timestamp},$event_codes->{$lu}) ;
			# die Dumper $ev_count;
			if ($ev_count->[0] <1){
				$sid_sths->{$SID} ||= $dbh->prepare("select * from $SID where PWD=?");
				my $sid_row = $dbh->selectrow_hashref($sid_sths->{$SID},{RaiseError=>1,PrintError=>1},$pwd);
				$e->I( "At $f line $line $SID $pwd ($sid_row->{EMAIL}) $id code=$event_codes->{$lu} $r->{status}");
				my $hsh = {
					epoch => $r->{timestamp},
					SID   => $SID,
					pwd   => $pwd,
					msg   => $r->{status},
					code  => $event_codes->{$lu},
					email => $sid_row->{EMAIL},
				};
				# die Dumper {ev=>$hsh,srows=>$s_rows};
				my $err = $ev->I(%$hsh);
				$e->F($err) if $err;
			}
		}
    }
}

