#!/usr/bin/perl
#$Id: escheme_work.pl,v 1.15 2007-09-25 02:08:41 triton Exp $
use strict;
use Data::Dumper;
use Getopt::Long;
use Carp qw(confess);

use TPerl::DBEasy;
use TPerl::Engine;
use TPerl::Error;
use TPerl::EScheme;
use TPerl::Event;
use TPerl::PFinder;
use TPerl::TritonConfig;
use TPerl::Sender;

my $status_labs = status_labels TPerl::PFinder;

my $e = new TPerl::Error( ts => 1 );

my $debug           = 0;
my $doit            = 0;
my $itsnow          = '';
my $too_old         = '2 days ago';
my $problem_summary = 0;
my $search_pwd      = '';
my $SID;

## Lets pretend its in the future, and see if there would be any problems...

GetOptions(
    'debug!'   => \$debug,
    'doit!'    => \$doit,
    'itsnow:s' => \$itsnow,
    'tooold:s' => \$too_old,
    'summary!' => \$problem_summary,
    'SID:s'    => \$SID,
    'PWD:s'    => \$search_pwd,
) or $e->F("Bad options");

# A bit of sanity
$e->F("Can't pretend its the future and run doit.  That is insane")
  if $itsnow && $doit;

my $es         = new TPerl::EScheme( attr => { PrintError => 0 } );
my $dbh        = $es->dbh;
my $ez         = new TPerl::DBEasy( dbh => $dbh );
my $ev         = new TPerl::Event( dbh => $dbh );
my $SID_filter = 'and SID=?' if $SID;
my $pwd_filter = 'and PWD=?' if $search_pwd;
my $sql        = qq{
select *
 from EMAIL_SCHEME_STATUS , EMAIL_TRACK_STATUS , EMAIL_MSG_STATUS
 where
   EMAIL_SCHEME_STATUS.EMAIL_SCHEME_STATUS_ID = EMAIL_TRACK_STATUS.EMAIL_SCHEME_STATUS_ID
  and
   EMAIL_TRACK_STATUS.EMAIL_TRACK_STATUS_ID = EMAIL_MSG_STATUS.EMAIL_TRACK_STATUS_ID
  and
   START_EPOCH < ?
  and
   TRACK_HOLD_FLAG != 1
  and
   TRACK_STOP_FLAG != 1
  and
   TRACK_READ_FLAG != 1
  and
   SCHEME_ACTIVE_FLAG = 1
  and
   DONE_EPOCH is NULL
  $SID_filter
  $pwd_filter
 order by START_EPOCH ASC
};

my $ems_fields = $es->EMAIL_MSG_STATUS_fields
  || $e->F( "Could not get EMAIL_MSG_STATUS_fields:" . $es->err );

my $canonical_itsnow = $ez->epoch2text( $ez->text2epoch($itsnow), '%c' );
$e->I("Pretending its '$itsnow' ($canonical_itsnow)") if $itsnow;


$itsnow ||= 'now';
my $now_epoch = $ez->text2epoch($itsnow)
  || $e->F("Cannot understand now time '$itsnow'");

# Modify too_old based on itsnow...
my $offset_secs = $now_epoch - $ez->text2epoch('now');
$offset_secs = 0 if $offset_secs < 10;
# print "Offset=$offset_secs\n";
my $too_old_canon =
  $ez->epoch2text( $ez->text2epoch($too_old) + $offset_secs, '%c' );
my $too_old_epoch = $ez->text2epoch($too_old)
  || $e->F("Could not understand too_old date '$too_old'");
$too_old_epoch += $offset_secs;
# $e->I("Will ignore mail scheduled before '$too_old' ($too_old_canon)");


my $params = [$now_epoch];
push @$params, $SID if $SID_filter;
push @$params, $search_pwd if $pwd_filter;
my $recs = $dbh->selectall_arrayref( $sql, { Slice => {} }, @$params );
$e->F( "SQL Error" . $dbh->errstr ) unless $recs;

my $troot = getConfig('TritonRoot');

# For the purposes of reporting, lets have an option where
# we only give each error message once and then give a count
# or a summary depending on the number if times it happened.

my $row_messages = {};

sub row_message {
    my $type = shift;
    my $r    = shift;
    my $msg  = shift;
    confess("r is not a hash ref") unless ref($r) eq 'HASH';
    confess("message is empty") unless $msg;

    $msg = TPerl::Error->fmterr($msg);

    my $start = $ez->epoch2text( $r->{START_EPOCH} );
    my $id_str =
"EM_STAT_ID:$r->{EMAIL_MSG_STATUS_ID}|$r->{SID}|$r->{PWD}|$r->{LANGUAGE}|$r->{SCHEME_STATUS_NAME}|$r->{EMAIL_TRACK_STATUS_NAME}|$r->{MESSAGE_STATUS_NAME}|$r->{WORKING_TEMPLATE}|CHECK_STATUS_FLAG=$r->{CHECK_STATUS_FLAG}|$start";
    if ( $doit || !$problem_summary ) {
        $e->$type("$msg $id_str");
    }
    if ($problem_summary) {
        push @{ $row_messages->{$type}->{$msg} }, $r;
    }
}

sub row_prob {
    row_message( 'E', @_ );
}

sub row_success {
    row_message( 'I', @_ );
}

sub update_EMAIL_MSG_STATUS {
    my $update_vals = shift;

    # If there is a database error we die.
    # there should not be any database errors.
    # $ems_fields,$ez$e are script globals.

    my $new_fields = {};
    foreach my $f ( keys %$ems_fields ) {
        $new_fields->{$f} = $ems_fields->{$f} if exists( $update_vals->{$f} );
    }
    if ( exists( $update_vals->{SENT_ERROR} ) ) {
        $update_vals->{SENT_ERROR} =
          TPerl::Error->fmterr( $update_vals->{SENT_ERROR} );
    }
	$ez->field_force(vals=>$update_vals,fields=>$new_fields);
    $e->F($_)
      if $_ = $ez->row_manip(
        action => 'update',
        vals   => $update_vals,
        fields => $new_fields,
        keys   => ['EMAIL_MSG_STATUS_ID'],
        table  => 'EMAIL_MSG_STATUS',
      );
}

foreach my $r (@$recs) {
    # print Dumper $r;

    # These are the
    my $update_vals = {
        EMAIL_MSG_STATUS_ID => $r->{EMAIL_MSG_STATUS_ID},
        DONE_EPOCH          => 'now',
    };

    my $SID = $r->{SID};
    my $pwd = $r->{PWD};
    unless ($SID) {
        row_prob( $r, 'No SID' );
        $update_vals->{SENT_ERROR} = 'No SID';
        update_EMAIL_MSG_STATUS($update_vals) if $doit;
        next;
    }
    unless ($pwd) {
        row_prob( $r, "no PWD" );
        $update_vals->{SENT_ERROR} = 'No PWD';
        update_EMAIL_MSG_STATUS($update_vals) if $doit;
        next;
    }
    $e->I("Found %$r") if $debug;

    ## ufile read.
    my $engine = new TPerl::Engine();
    my $data = $engine->u_read( join '/', $troot, $SID, 'web', "u$pwd.pl" );
    unless ($data) {
        row_prob( $r, $engine->err );
        $update_vals->{SENT_ERROR} = $engine->err;
        update_EMAIL_MSG_STATUS($update_vals) if $doit;
        next;
    }
    my $send_args = {
        SID     => $r->{SID},
        name    => $r->{WORKING_TEMPLATE},
        lang    => lc( $r->{LANGUAGE} ),
        noplain => !$r->{USE_PLAIN_FLAG},
        nohtml  => !$r->{USE_HTML_FLAG},
    };
    ###Now look in the job table for the EMAIL address and FULLNAME, and overwrite the data hash.

    my $to_sql = "select * from $SID where PWD=?";
    my $recs = $dbh->selectall_arrayref( $to_sql, { Slice => {} }, $pwd );
    unless ($recs) {
        row_prob( $r, $dbh->errstr );
        $update_vals->{SENT_ERROR} = $dbh->errstr;
        update_EMAIL_MSG_STATUS($update_vals) if $doit;
        next;
    }
    if ( @$recs == 1 ) {
        # To address and email decision
        if ( $r->{ALERT_FLAG} ) {
            $data->{to} = $r->{ALERT_EMAIL};
        } else {
            if ( $recs->[0]->{EMAIL} eq '' ) {
                $update_vals->{SENT_MSG} = 'Blank email in SID table';
                row_prob( $r, $update_vals->{SENT_MSG} );
                update_EMAIL_MSG_STATUS($update_vals) if $doit;
                next;
            }
			$data->{to} = $recs->[0]->{EMAIL};
            $data->{to}       = qq{"$recs->[0]->{FULLNAME}" <$recs->[0]->{EMAIL}>} if $recs->[0]->{FULLNAME};
            $data->{fullname} = $recs->[0]->{FULLNAME};
        }
		if ($r->{CHECK_STATUS_FLAG}){
			# Check the status value from the table.
			# Need to look in the SCHEME for the STOP_FIELD.  Don't want to
			# join the EMAIL_SCHEME into the mail sql, as not having the entry
			# that it was torn off from should not make it stop.
			my $st_msg = '';
			if (my $f =  uc($r->{STOP_FIELD}) ) {
				if ( exists $recs->[0]->{$f} ) {
					if ( my $va = $recs->[0]->{$f} ) {
						$st_msg =
						  "Found value of '$va' in column '$f'.  Not sending";
					}
				} else {
					$st_msg =
					  "STOP_FIELD column '$f' not found in $SID. Not sending";
				}
			} else {
				my $stat = $recs->[0]->{STAT};
				my $stl  = $status_labs->{$stat};
				unless ( grep $_ == $stat, 0, 3 ) {
					$st_msg = "Status values of '$stl'. Not sending";
				}
			}
			if ($st_msg) {
				row_success( $r, $st_msg );
				$update_vals->{SENT_MSG} = $st_msg;
				update_EMAIL_MSG_STATUS($update_vals) if $doit;
				next;
			}
		}
        if ( $r->{START_EPOCH} < $too_old_epoch ) {
            my $msg = "Scheduled before '$too_old_canon'. Not sending";
            row_prob( $r, $msg );
            $update_vals->{SENT_MSG} = $msg;
            update_EMAIL_MSG_STATUS($update_vals) if $doit;
            next;
        }
    } elsif ( @$recs == 0 ) {
        row_prob( $r, "No record in $SID job table for pwd $pwd" );
        $update_vals->{SENT_ERROR} = "No record in $SID job table for pwd $pwd";
        update_EMAIL_MSG_STATUS($update_vals) if $doit;
        next;
    } else {
        row_prob( $r, "Too many records in $SID job table for pwd $pwd" );
        $update_vals->{SENT_ERROR} =
          "Too many records in $SID job table for pwd $pwd";
        update_EMAIL_MSG_STATUS($update_vals) if $doit;
        next;
    }
    ### Some special things need to go in the data.
    $data->{vhost} ||= getOtherConfig( 'server', 'FQDN', 1 );
    $data->{banner} ||=
qq{<img src="http://[%vhost%]/survey/banner/$r->{EMAIL_MSG_STATUS_ID}.gif">};
    $data->{SID}      = $SID;
    $data->{password} = $pwd;
    if ( $r->{ALERT_FLAG} ) {
        # replace the to in the data with the
    }
    $e->D( "Sender Args:" . Dumper $send_args) if $debug;
    my $s = new TPerl::Sender(%$send_args);
    if ($doit) {
        if ( my $stat = $s->send( data => $data ) ) {
            my $id   = $stat->sendmail_id;
            my $info = $stat->info;
            $stat->do_event( password => $pwd, dbh => $dbh );
            row_success( $r, "Sent:$id $info" );
            $update_vals->{SENT_MSG}    = $info;
            $update_vals->{SENDMAIL_ID} = $id;
        } else {
            $ev->E(
                SID   => $SID,
                code  => 20,
                email => $data->{to},
                msg   => $s->err,
                pwd   => $pwd
            );
            row_prob( $r, "Sender Error " . TPerl::Error->fmterr($s->err()) );
            $update_vals->{SENT_ERROR} = $s->err;
        }
        # Only update the database if you are actually sending emails.
        # Only send the fields we need to row_manip, so it builds shorter
        # update statements.
        update_EMAIL_MSG_STATUS($update_vals);
    } else {
        if ( my $stuff = $s->send_process( data => $data ) ) {
            # print Dumper $stuff;
            row_success( $r,
                "Would have sent an email to $stuff->{data}->{to}" );
        } else {
            row_prob( $r, $s->err );
        }
    }
}

if ($problem_summary) {
    foreach my $type ( keys %$row_messages ) {
        my $mh = $row_messages->{$type};
        $e->$type( sprintf "%s case(s) of $_", scalar( @{ $mh->{$_} } ) )
          foreach keys %$mh;
    }
}

