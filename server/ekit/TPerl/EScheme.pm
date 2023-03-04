package TPerl::EScheme;
#$Id: EScheme.pm,v 1.21 2007-09-06 03:03:40 triton Exp $

use strict;
use Carp qw(confess);
use vars qw(@ISA);
use TPerl::TableManip;
use Data::Dumper;
use TPerl::TransactionList;
use TPerl::Engine;

@ISA = qw(TPerl::TableManip);

=head1 SYNOPSIS

This is how we make emails that must get through.

 # A new object;
 my $eso = new TPerl::EScheme;
 
 # Do some Click Throughs
 my $tracks = $eso->click_through( pwd => '1234' ) || die Dumper $eso->err;
 
 # DIY events. this module is about schemes.  events are at the map level.
 # in recent versions of TPerl/Event.csv MAIL_CLICK_THROUGH is 217
 my $ev = new TPerl::Event;
 foreach my $track (@$tracks) {
     $ev->I(
         msg  => "Click Through for track $track->{EMAIL_TRACK_STATUS_ID}",
         code => 217,
         pwd  => 1234,
         SID  => 'MAP???',
         uid  => '????',
     );
 }

 # things also work from the command line
 perl -MTPerl::EScheme -MData::Dumper -e 'print Dumper (TPerl::EScheme->active_tracks(pwd=>"YEGSTCDK"))'
 perl -MTPerl::EScheme -MData::Dumper -e 'print Dumper (TPerl::EScheme->click_through(pwd=>"YEGSTCDK"))'

=head1 DETAIL

A picture is worth a thousand words, but here goes.

First you set up an EMAIL_SCHEME, with a specific goal, say  'June 2005
workshop sign up'.  Each EMAIL_SCHEME may have 1 or more EMAIL_TRACKS, say
Invite, Reminder1 and Reminder2.  Each EMAIL_TRACK has a few EMAIL_MSG things.
For the EMAIL_TRACK called Invite, the first EMAIL_MSG may be a multipart
alternative with a plain and html parts that includes a banner, the second
EMAIL_MSG may be less 'spam like' without the BANNER in the html part. The
third EMAIL_MSG may be the plain version of the first part with no html.   Each
EMAIL_MSG can have its own set of headers etc.  See cgi-adm/escheme_edit.pl to
allow these to be set up without the complexity of raw database edits in say
cgi-adm/escheme_admin.pl

Second, once this framework is setup, you probably want to use it.  This
process is 'tearing off' a copy of the framework. Basically for each potential
respondent, you copy of the EMAIL_SCHEME and related EMAIL_TRACK  and EMAIL_MSG
entries into corresponding _STATUS tables.  In the process, you work out the
dates that each of the tracks should start and therefore the dates of each
EMAIL_MSG as well.  You also need to check that the ufile for the person has
enough info in it so that mail merges will not fail.    If you change things
between tear off and the action, then you could be in trouble.  We could have a
process that checks things out before each send looking for trouble.  See
cgi-adm/escheme_status.pl to see the progress of a particular tear-off, and to
be able tmanually control various part of the process.

There are a few levels of control for each torn off framework.  If the
goal of the EMAIL_SCHEME is acheived, no more emails for this
EMAIL_SHEME should be sent.  If an EMAIL_TRACK (an invitation) gets a
read or a click through, that track should stop, but the next
EMAIL_TRACK (a reminder for example) should keep going, until the aim
of the parent EMAIL_SCHEME is acheived.

Depending on the time frames involved, it is quite possible that we
will start a reminder EMAIL_TRACK before the invite EMAIL_TRACK is
completely over.

=head2 Fitting into existing surveys.

The tearing off process matches a record in JOB database table with one of the
EMAIL_SCHEME.  Records can be inserted into the JOB table with the
upload_csv_file mechanism, including filtering etc.  There may need to be a
PREAPRE ONLY option inserted into the system somewhere.


=head2 Logging

It is important that we trace the email as far though the system as possible.
We want to look for funny things in sendmail or postfix logs.  We want to be
able to easily identify each EMAIL_MSG in these log files.  We want to be able
to look an individual and see all the things that happen in an event log.  The
TPerl::Sender module is at time of writing the latest development of the
increasingly complex mail merge and send system.  It handles languages, headers
and versions of email templates.  It also logs SMTP info from the sending
conversations.  There are places in the EMAIL_MSG_STATUS table for any error
messages from TPerl::Sender, and for SMTP message ids.

Each message that goes out has its own ID.  We use banner that contain this ID
to indicate when a particular track is finished.  See cgi-mr/banner for details.

We need responders that look at returned mail and again attempt to
log these events also.

=head2 Languages

Each EMAIL_USER has language associated with them.  This 2 letter
lowercase mnemonic will be used at the time an EMAIL_MSG is sent to
alter the template name.

=head1 TESTING

The process of testing is long and complex.  A full test of a real world system
could take several weeks, as we wait for each email from each TRACK from each
SCHEME.  The system could be changed during this time, so that emails that may
have worked when a tear-off was done, may be rendered inoperable by changes to
templates or upload parameters.  It is nice to read the content of HTML emails,
without triggering the READ action, and altering the test.

=cut

sub table_create_list {
    return [
        qw(EMAIL_SCHEME EMAIL_TRACK EMAIL_MSG EMAIL_SCHEME_STATUS EMAIL_TRACK_STATUS EMAIL_MSG_STATUS)
    ];
}

sub table_keys {
    return {
        EMAIL_SCHEME        => ['EMAIL_SCHEME_ID'],
        EMAIL_TRACK         => ['EMAIL_TRACK_ID'],
        EMAIL_MSG           => ['EMAIL_MSG_ID'],
        EMAIL_SCHEME_STATUS => ['EMAIL_SCHEME_STATUS_ID'],
        EMAIL_TRACK_STATUS  => ['EMAIL_TRACK_STATUS_ID'],
        EMAIL_MSG_STATUS    => ['EMAIL_MSG_STATUS_ID'],
    };
}

sub EMAIL_SCHEME_fields {
    my $self   = shift;
    my $dbh    = $self->dbh;
    my $ez     = $self->ez;
    my $fields = $ez->fields( table => 'EMAIL_SCHEME' );
    $fields->{EMAIL_SCHEME_ID}->{cgi}->{func} = 'hidden';
    my $en = new TPerl::Engine;
    $fields->{SID}->{cgi} =
      { func => 'popup_menu', args => { -values => $en->SID_list } };
	$fields->{SID}->{pretty}='SID';
    $fields->{TEAR_EXISTS_FLAG}->{cgi}->{args}->{ -values } = [ 1, 2, 3, 4 ];
    $fields->{TEAR_EXISTS_FLAG}->{cgi}->{args}->{-labels} = {
        1 => 'Send Single',
        2 => 'Send All',
        3 => 'Do Nothing',
        4 => 'Delete existing send all'
    };
    return $fields

}

sub EMAIL_TRACK_fields {
    my $self   = shift;
    my $dbh    = $self->dbh;
    my $ez     = $self->ez;
    my $fields = $ez->fields( table => 'EMAIL_TRACK' );
    $fields->{EMAIL_SCHEME_ID}->{cgi}->{func} = 'popup_menu';
    $fields->{EMAIL_SCHEME_ID}->{value_sql}->{sql} =
      'select EMAIL_SCHEME_ID,SCHEME_NAME from EMAIL_SCHEME';
    $fields->{EMAIL_TRACK_ID}->{cgi}->{func} = 'hidden';
    return $fields;
}

sub EMAIL_MSG_fields {
    my $self   = shift;
    my $dbh    = $self->dbh;
    my $ez     = $self->ez;
    my $fields = $ez->fields( table => 'EMAIL_MSG' );
    $fields->{EMAIL_TRACK_ID}->{cgi}->{func} = 'popup_menu';
    $fields->{EMAIL_TRACK_ID}->{value_sql}->{sql} =
      'select EMAIL_TRACK_ID,TRACK_NAME from EMAIL_TRACK';
    $fields->{EMAIL_MSG_ID}->{cgi}->{func} = 'hidden';
    return $fields;
}

sub EMAIL_SCHEME_STATUS_fields {
    my $self   = shift;
    my $dbh    = $self->dbh;
    my $ez     = $self->ez;
    my $fields = $ez->fields( table => 'EMAIL_SCHEME_STATUS' );
    $fields->{EMAIL_SCHEME_STATUS_ID}->{cgi}->{func} = 'hidden';
    $fields->{EMAIL_SCHEME_ID}->{cgi}->{func}        = 'popup_menu';
    $fields->{EMAIL_SCHEME_ID}->{value_sql}->{sql} =
      'select EMAIL_SCHEME_ID,SCHEME_NAME from EMAIL_SCHEME';
    my $en = new TPerl::Engine;
    $fields->{SID}->{cgi} =
      { func => 'popup_menu', args => { -values => $en->SID_list } };
    $fields->{TEAR_EXISTS_FLAG}->{cgi}->{args}->{ -values } = [ 1, 2, 3, 4 ];
    $fields->{TEAR_EXISTS_FLAG}->{cgi}->{args}->{-labels} = {
        1 => 'Send Single',
        2 => 'Send All',
        3 => 'Do Nothing',
        4 => 'Delete existing send all'
    };
    return $fields;
}

sub EMAIL_TRACK_STATUS_fields {
    my $self   = shift;
    my $dbh    = $self->dbh;
    my $ez     = $self->ez;
    my $fields = $ez->fields( table => 'EMAIL_TRACK_STATUS' );
    $fields->{TRACK_STATUS_NAME}->{pretty}           = 'Track';
    $fields->{EMAIL_TRACK_STATUS_ID}->{cgi}->{func}  = 'hidden';
    $fields->{EMAIL_SCHEME_STATUS_ID}->{cgi}->{func} = 'popup_menu';
    $fields->{EMAIL_SCHEME_STATUS_ID}->{value_sql}->{sql} =
        'select EMAIL_SCHEME_STATUS_ID,SCHEME_STATUS_NAME '
      . ' from EMAIL_SCHEME_STATUS';
    return $fields;
}

sub EMAIL_MSG_STATUS_fields {
    my $self   = shift;
    my $dbh    = $self->dbh;
    my $ez     = $self->ez;
    my $fields = $ez->fields( table => 'EMAIL_MSG_STATUS' );
    $fields->{EMAIL_MSG_STATUS_ID}->{cgi}->{func}   = 'hidden';
    $fields->{EMAIL_TRACK_STATUS_ID}->{cgi}->{func} = 'popup_menu';
    $fields->{EMAIL_TRACK_STATUS_ID}->{value_sql}->{sql} =
      'select EMAIL_TRACK_STATUS_ID,TRACK_STATUS_NAME from EMAIL_TRACK_STATUS';
    return $fields;
}

sub table_sql {
    my $self  = shift;
    my $table = shift;

    my $tables = {
        EMAIL_SCHEME => q{
		create table EMAIL_SCHEME (
			EMAIL_SCHEME_ID			INTEGER NOT NULL,
			SCHEME_NAME				VARCHAR(100) NOT NULL,
			SID						VARCHAR(12) NOT NULL,
			STOP_FIELD				VARCHAR(20),
			CHECK_STATUS_FLAG 		INTEGER DEFAULT 1 NOT NULL,
			TEAR_EXISTS_FLAG		INTEGER DEFAULT 1 NOT NULL,
			UNIQUE (SID,SCHEME_NAME),
			PRIMARY KEY (EMAIL_SCHEME_ID)
		)
	},
        EMAIL_TRACK => q{
		create table EMAIL_TRACK (
			EMAIL_TRACK_ID	INTEGER NOT NULL,
			EMAIL_SCHEME_ID	INTEGER NOT NULL,
			TRACK_NAME		VARCHAR(100) NOT NULL,
			TRACK_INTERVAL	INTEGER NOT NULL,
			FOREIGN KEY (EMAIL_SCHEME_ID) REFERENCES EMAIL_SCHEME(EMAIL_SCHEME_ID),
			PRIMARY KEY (EMAIL_TRACK_ID)
		)
	},
        EMAIL_MSG => q{
		create table EMAIL_MSG (
			EMAIL_MSG_ID	INTEGER NOT NULL,
			EMAIL_TRACK_ID	INTEGER NOT NULL,
			MESSAGE_NAME	VARCHAR(100) NOT NULL,
			MESSAGE_INTERVAL INTEGER NOT NULL,
			TEMPLATE		VARCHAR(100) NOT NULL,
			USE_HTML_FLAG			INTEGER  DEFAULT 1,
			USE_PLAIN_FLAG			INTEGER  DEFAULT 1,
			ALERT_FLAG				INTEGER  DEFAULT 0,
			ALERT_EMAIL				VARCHAR(250),
			FOREIGN KEY (EMAIL_TRACK_ID) REFERENCES EMAIL_TRACK(EMAIL_TRACK_ID),
			PRIMARY KEY (EMAIL_MSG_ID)

		)
	},
        EMAIL_SCHEME_STATUS => q{
		create table EMAIL_SCHEME_STATUS (
			EMAIL_SCHEME_STATUS_ID		INTEGER NOT NULL,
			SCHEME_STATUS_NAME					VARCHAR(100) NOT NULL,
			CREATED_EPOCH				INTEGER NOT NULL,
			SID							VARCHAR(12) NOT NULL,
			STOP_FIELD					VARCHAR(20),
			CHECK_STATUS_FLAG 			INTEGER DEFAULT 1 NOT NULL,
			TEAR_EXISTS_FLAG			INTEGER DEFAULT 1 NOT NULL,
			PWD							VARCHAR(12) NOT NULL,
			LANGUAGE					VARCHAR(2),
			SCHEME_DONE_EPOCH			INTEGER,
			SCHEME_ACTIVE_FLAG			INTEGER DEFAULT 1 NOT NULL,
			EMAIL_SCHEME_ID				INTEGER NOT NULL,
			FOREIGN KEY (EMAIL_SCHEME_ID) REFERENCES EMAIL_SCHEME(EMAIL_SCHEME_ID),
			PRIMARY KEY (EMAIL_SCHEME_STATUS_ID)
		)
	},
        EMAIL_TRACK_STATUS => q{
		create table EMAIL_TRACK_STATUS (
			EMAIL_TRACK_STATUS_ID		INTEGER NOT NULL,
			EMAIL_SCHEME_STATUS_ID		INTEGER NOT NULL,
			TRACK_STATUS_NAME      VARCHAR(100) NOT NULL,
			TRACK_INTERVAL	INTEGER NOT NULL,
			CREATED_EPOCH	INTEGER NOT NULL,
			TRACK_READ_FLAG		INTEGER DEFAULT 0,
			TRACK_STOP_FLAG		INTEGER DEFAULT 0,
			TRACK_HOLD_FLAG		INTEGER DEFAULT 0,
			FOREIGN KEY (EMAIL_SCHEME_STATUS_ID) REFERENCES EMAIL_SCHEME_STATUS(EMAIL_SCHEME_STATUS_ID),
			PRIMARY KEY (EMAIL_TRACK_STATUS_ID)
		)
	},
        EMAIL_MSG_STATUS => q{
		create table EMAIL_MSG_STATUS(
			EMAIL_MSG_STATUS_ID			INTEGER NOT NULL,
			EMAIL_TRACK_STATUS_ID		INTEGER NOT NULL,
			MESSAGE_STATUS_NAME		VARCHAR(100) NOT NULL,
			WORKING_TEMPLATE							VARCHAR(100) NOT NULL,
			USE_HTML_FLAG          INTEGER NOT NULL,
			USE_PLAIN_FLAG          INTEGER NOT NULL,
			ALERT_FLAG				INTEGER  DEFAULT 0,
			ALERT_EMAIL				VARCHAR(250),
			CREATED_EPOCH	INTEGER NOT NULL,
			START_EPOCH	INTEGER NOT NULL,
			DONE_EPOCH	INTEGER,
			SENT_MSG				VARCHAR(250),
			SENT_ERROR				VARCHAR(250),
			SENDMAIL_ID				VARCHAR(250),
			RETURN_MSG				VARCHAR(250),
			FOREIGN KEY (EMAIL_TRACK_STATUS_ID) REFERENCES EMAIL_TRACK_STATUS(EMAIL_TRACK_STATUS_ID),
			PRIMARY KEY (EMAIL_MSG_STATUS_ID)
		)
	},
    };
    my $sql = $tables->{$table};
    $sql =~ s/#.*//;
    return $sql;
}

####Thats the basic functions and crap out of the way.

# This looks a bit complex, but its just recursion, with each level just
# different enough to make it too tricky for real recursion.
#
# It gets a little more tricky, when we tear off.  we need to alter the
# dst_tables for each copy, and rename some fields and pass in a few more
# values, but its still the same idea.
# Also compolicated by the fact that now we have TEAR_EXISTS_FLAG to specify what to do.
# Seems like a good time to re-write this to use transactions lists....
#
# The trouble with trasactionLists is that you don't know what the ID of the parent record is untill you do it
# Lets pre-allocate them and hope for the best.
#

sub duplicate_scheme {

    my $self = shift;
    my %args = @_;
    # Die with some programmer help....
    my $scheme_id = delete $args{scheme_id}
      || confess("Did not send a scheme_id");

    my $tear_off     = delete $args{tear_off};
    my $pwd          = delete $args{password};
    my $lang         = delete $args{language};
    my $scheme_start = delete $args{scheme_start};
    confess( 'Unrecognised args' . Dumper \%args ) if %args;

    if ( $tear_off and ( $pwd eq '' ) ) {
        # If we are tearing off, we need a password.  Everything else is
        # optional
        $self->err("no password sent in a tear_off");
        return undef;
    }

    my $ez = $self->ez;

    $scheme_start ||= 'now';
    my $scheme_start_epoch = $ez->text2epoch($scheme_start);
    unless ($scheme_start_epoch) {
        $self->err("Could not understand date scheme_start '$scheme_start'");
        return undef;
    }

    my $es = $ez->get_rows(
        table       => 'EMAIL_SCHEME',
        key         => { EMAIL_SCHEME_ID => $scheme_id },
        exactly_one => 1
    );
    unless ($es) {
        $self->err( $ez->err );
        return;
    }

    my $trl = new TPerl::TransactionList(dbh=>$self->dbh);

	my $send_single = '';

    if ($tear_off) {
        my $exists = $self->search_by_pwd(
            SID         => $es->{SID},
            pwd         => $pwd,
            scheme_name => $es->{SCHEME_NAME}
        );
        my $num_exists = scalar @$exists;
        if ($num_exists) {
            $send_single = 1 if $es->{TEAR_EXISTS_FLAG} == 1;
            return -3 if $es->{TEAR_EXISTS_FLAG} == 3;
            if ( $es->{TEAR_EXISTS_FLAG} == 4 ) {
                foreach my $exist (@$exists) {
                    $trl = $self->delete_scheme(
                        scheme_id => $exist->{EMAIL_SCHEME_STATUS_ID},
                        tear_off  => 1,
                        trl       => $trl,
                        want_trl  => 1
                    ) || return undef;
                }
            }
        }
    }

    $tear_off = '_STATUS' if $tear_off;
    my $new_es_id = $self->next_id( 'EMAIL_SCHEME', $tear_off ) || return undef;
    my $new_es = {};
    # Copy everything;
    $new_es->{$_} = $es->{$_} foreach keys %$es;
    if ($tear_off) {
        $new_es->{SCHEME_STATUS_NAME}     = delete $new_es->{SCHEME_NAME};
        $new_es->{EMAIL_SCHEME_STATUS_ID} = $new_es_id;
        $new_es->{SCHEME_ACTIVE_FLAG}     = 1;
        $new_es->{PWD}                    = $pwd;
        $new_es->{LANGUAGE}               = $lang;
        $new_es->{CREATED_EPOCH}          = $ez->text2epoch('now');
    } else {
        $new_es->{SCHEME_NAME}     = "Copy of $es->{SCHEME_NAME}";
        $new_es->{EMAIL_SCHEME_ID} = $new_es_id;
    }
    $trl->push_item(
        %{ $ez->insert( table => "EMAIL_SCHEME$tear_off", vals => $new_es ) } );

    ## Now down to 'recursion'...  How easy?
    #copy the EMAIL_SCHEME
    # find the child EMAIL_TRACKS
    # copy each of them
    # foreach email_track
    # find child EMAIL_MSG
    # copy each one.

    my $ets = $ez->get_rows(
        table => 'EMAIL_TRACK',
        key  => { EMAIL_SCHEME_ID => $scheme_id },
        order => [qw(TRACK_INTERVAL)]
    );
    unless ($ets) {
        $self->err( $ez->err );
        return undef;
    }
	my $new_et_id = $self->next_id( 'EMAIL_TRACK', $tear_off ) || return undef;
            my $new_em_id = $self->next_id( 'EMAIL_MSG', $tear_off ) || return undef;
    foreach my $et (@$ets) {
        my $new_et = {};
        $new_et->{$_} = $et->{$_} foreach keys %$et;
        if ($tear_off) {
            $new_et->{EMAIL_SCHEME_STATUS_ID} = $new_es_id;
            $new_et->{EMAIL_TRACK_STATUS_ID}  = $new_et_id;
            $new_et->{CREATED_EPOCH}          = $ez->text2epoch('now');
			$new_et->{TRACK_STATUS_NAME} = delete $new_et->{TRACK_NAME};
            $new_et->{$_}                     = 0
              foreach qw(TRACK_READ_FLAG TRACK_STOP_FLAG TRACK_HOLD_FLAG);
			delete $new_et->{$_} foreach qw(EMAIL_TRACK_ID EMAIL_SCHEME_ID);
        } else {
            $new_et->{EMAIL_TRACK_ID}  = $new_et_id;
            $new_et->{EMAIL_SCHEME_ID} = $new_es_id;
        }
        $trl->push_item( %{ $ez->insert(table=>"EMAIL_TRACK$tear_off",vals=>$new_et) } );
        my $ems = $ez->get_rows(
            table => 'EMAIL_MSG',
            key   => { EMAIL_TRACK_ID => $et->{EMAIL_TRACK_ID} },
            order => ['MESSAGE_INTERVAL'],
        );
        unless ($ems) {
            $self->err( $ez->err );
            return;
        }
        foreach my $em (@$ems) {
            my $new_em = {};
            $new_em->{$_} = $em->{$_} foreach keys %$em;
            if ($tear_off) {
                $new_em->{EMAIL_MSG_STATUS_ID}          = $new_em_id;
                $new_em->{EMAIL_TRACK_STATUS_ID} = $new_et_id;
                $new_em->{CREATED_EPOCH}         = $ez->text2epoch('now');
                $new_em->{START_EPOCH} =
                  $scheme_start_epoch + $et->{TRACK_INTERVAL} +
                  $em->{MESSAGE_INTERVAL};
                $new_em->{MESSAGE_STATUS_NAME} = delete $new_em->{MESSAGE_NAME};
                $new_em->{WORKING_TEMPLATE}    = delete $new_em->{TEMPLATE};
				delete $new_em->{$_} foreach qw(EMAIL_TRACK_ID MESSAGE_INTERVAL EMAIL_MSG_ID);
            } else {
                $new_em->{EMAIL_TRACK_ID} = $new_et_id;
                $new_em->{EMAIL_MSG_ID}   = $new_em_id;
            }
			# print Dumper $new_em;
            $trl->push_item(
                %{
                    $ez->insert(
                        table => "EMAIL_MSG$tear_off",
                        vals  => $new_em
                    )
                  }
            );
			last if $send_single;
			$new_em_id++;
        }
		last if $send_single;
		$new_et_id++;
    }
	$self->dbh->begin_work;
	$trl->dbh_do;
	if (my $errs = $trl->errs()){
		$trl->dbh_rollback_messages($self->dbh->rollback);
		$self->err($trl->msg_summary(list=>$errs));
		return;
	}else{
		$self->dbh->commit;
    	return $new_es_id;
	}
}

sub next_id {
    # escheme wrapper around TPerl::DBEasy->next_ids...
    my $self     = shift;
    my $table    = shift;
    my $tear_off = shift;

    my $stat = '_STATUS' if $tear_off;

    my $id = $self->ez->next_ids(
        table    => "$table$stat",
        only_one => 1,
        keys     => $self->table_keys()
    );
    if ($id) {
        return $id;
    } else {
        $self->err( $self->ez->err );
        return;
    }
}

sub delete_scheme {

    # this deletes a hierarchy of EMAIL_SCHEME EMAIL_TRACK and EMAIL_MSG.
    # Also does the _STATUS versions if tear_off is specified.

    my $self = shift;
    my %args = @_;

    my $scheme_id    = delete $args{scheme_id};
    my $tear_off     = delete $args{tear_off};
    my $want_list    = delete $args{want_trl};
    my $trl          = delete $args{trl} || new TPerl::TransactionList;
    my $leave_scheme = delete $args{leave_scheme};

    confess( "Unrecognised args:" . Dumper \%args ) if %args;
    confess("Did not send a 'scheme_id'") unless $scheme_id;

    my $tear_ext = '_STATUS' if $tear_off;
    my $ez       = $self->ez;
    my $dbh      = $self->dbh;

    my $es = $ez->get_rows(
        table       => "EMAIL_SCHEME$tear_ext",
        key         => "EMAIL_SCHEME${tear_ext}_ID",
        val         => $scheme_id,
        exactly_one => 1,
        allow_none  => 1,
    ) || ( $self->err( $ez->err ) and return );

    if ( ref($es) eq 'ARRAY' and @$es == 0 ) {
        $self->err("There is no SCHEME$tear_ext with ${tear_ext}id=$scheme_id");
        return;
    }

    my $et_sql =
        "select EMAIL_TRACK${tear_ext}_ID from EMAIL_TRACK$tear_ext"
      . " where EMAIL_SCHEME${tear_ext}_ID=?";
    my $et_ids = $dbh->selectcol_arrayref( $et_sql, {}, $scheme_id )
      || ( $self->err( { sql => $et_sql, params => [$scheme_id], dbh => $dbh } )
        and return );
    # print Dumper $et_ids;
	my $es_str = "SCHEME$tear_off '$es->{SCHEME_NAME}($es->{SCHEME_ID})' in '$es->{SID}'";
    foreach my $et_id (@$et_ids) {
        $trl->push_item(
            dbh => $dbh,
            sql => "delete from EMAIL_MSG$tear_ext"
              . " where EMAIL_TRACK${tear_ext}_ID=?",
            params => [$et_id],
            pretty => "deleting $es_str TRACK$tear_off $et_id messages"
        );
    }
    $trl->push_item(
        dbh => $dbh,
        sql => "delete from EMAIL_TRACK$tear_ext"
          . " where EMAIL_SCHEME${tear_ext}_ID=?",
        params => [$scheme_id],
        pretty => "Deleting $es_str tracks."
    );
    $trl->push_item(
        dbh => $dbh,
        sql => "delete from EMAIL_SCHEME$tear_ext"
          . " where EMAIL_SCHEME${tear_ext}_ID=?",
        params => [$scheme_id],
        pretty => "Deleting $es_str $es->{SCHEME_NAME}"
    ) unless $leave_scheme;

    return $trl if $want_list;

    $dbh->begin_work;
    $trl->dbh_do;
    if ( my $errs = $trl->errs ) {
        $trl->dbh_rollback_messages( $dbh->rollback );
        $self->err( $trl->msg_summary( rollback => 1 ) );
        return;
    } else {
        $dbh->commit;
        return $trl;
    }

}

sub cascade_delete {
    my $self = shift;
    my %args = @_;

    my $scheme_id = delete $args{scheme_id};
    my $track_id  = delete $args{track_id};
    my $msg_id    = delete $args{msg_id};
    my $tear_off  = delete $args{tear_off};
    # my $items = delete $args{items};

    confess( "Unrecognised args" . Dumper \%args ) if %args;

    my $tear_ext = '_STATUS' if $tear_off;
    my $dbh = $self->dbh || return undef;

    if ($scheme_id) {
        # confess "Work needed to return items for a scheme_id" if $items;
        return $self->delete_scheme(
            scheme_id => $scheme_id,
            tear_off  => $tear_off
        );
    } elsif ($track_id) {
        my $tr = new TPerl::TransactionList( dbh => $dbh );
        $tr->push_item(
            sql => "delete from EMAIL_MSG$tear_ext"
              . " where EMAIL_TRACK${tear_ext}_ID=?",
            params => [$track_id],
            pretty => 'Deleting Message$tear_ext'
        );
        $tr->push_item(
            sql => "delete from EMAIL_TRACK$tear_ext"
              . " where EMAIL_TRACK${tear_ext}_ID=?",
            params => [$track_id],
            pretty => 'Deleting Track$tear_ext'
        );
        $tr->dbh_do;
        my $errs = $tr->errs || [];
        if (@$errs) {
            $self->err($errs);
            $self->err( $errs->[0]->err() ) if @$errs == 1;
            return undef;
        } else {
            return 1;
        }
    } elsif ($msg_id) {
        my $sql =
          "delete from EMAIL_MSG$tear_ext" . " where EMAIL_MSG${tear_ext}_ID=?";
        if ( $dbh->do( $sql, {}, $msg_id ) ) {
            return 1;
        } else {
            $self->err( { dbh => $dbh, sql => $sql, params => [$msg_id] } );
            return undef;
        }
    } else {
        confess("Unrecognised args to cascade_delete");
        return undef;
    }
}

sub search_by_pwd {
    # perl -MTPerl::EScheme -MData::Dumper -e 'print Dumper (TPerl::EScheme->search_by_pwd(pwd=>"YEGSTCDK"))'
    # Mike wants to know if there is torn off scheme for a passwd in a job.

    my $self        = shift;
    my %args        = @_;
    my $pwd         = $args{pwd} || confess("'pwd' is a required arg");
    my $dbh         = $self->dbh || return undef;
    my $SID         = $args{SID};
    my $scheme_name = $args{scheme_name};

    my $keys = { PWD => $pwd };
    $keys->{SID}                = $SID         if $SID;
    $keys->{SCHEME_STATUS_NAME} = $scheme_name if $scheme_name;

    my $r = $self->ez->get_rows( table => 'EMAIL_SCHEME_STATUS', key => $keys );
    return $r if $r;
    $self->err( $self->ez->err );
    return;
}

sub search_by_name {
	# perl -MTPerl::EScheme -e 'print "id is ".TPerl::EScheme->search_by_name(SID=>"MAP011",name=>"participant%")."\n"'
    # This returns the EMAIL_SCHEME_ID of a scheme after looking up its name.
    # Note that a wildcard (%) in the name causes a SQL LIKE clause to be used (instead of an exact match)
    #
    my $self = shift;
    my %args = @_;

    my $name = delete $args{name} || confess("'name' is a required arg");
    my $SID  = delete $args{SID}  || confess("'SID' is a required arg");

    confess( "Unrecognised args" . Dumper \%args ) if %args;

	my $ez = $self->ez;

    if (
        my $r = $ez->get_rows(
			exactly_one  => 0,
            table        => 'EMAIL_SCHEME',
            ignore_cases => 'SCHEME_NAME',
            keys         => { SCHEME_NAME => $name, SID => $SID }
        )
      )
    {
        return $r;
    } else {
        $self->err( $ez->err );
        return;
    }
}

sub id_by_name {
	# perl -MTPerl::EScheme -e 'print "id is ".TPerl::EScheme->id_by_name(SID=>"MAP011",name=>"bOsS",exact=>0)."\n"'
    # This returns the EMAIL_SCHEME_ID of a scheme after looking up its name.
    #
    my $self = shift;
    my %args = @_;

    my $name = delete $args{name} || confess("'name' is a required arg");
    my $SID  = delete $args{SID}  || confess("'SID' is a required arg");

    confess( "Unrecognised args" . Dumper \%args ) if %args;

	my $ez = $self->ez;

    if (
        my $r = $ez->get_rows(
			exactly_one  => 1,
            table        => 'EMAIL_SCHEME',
            ignore_cases => 'SCHEME_NAME',
            keys         => { SCHEME_NAME => $name, SID => $SID }
        )
      )
    {
        return $r->{EMAIL_SCHEME_ID};
    } else {
        $self->err( $ez->err );
        return;
    }
}


sub delete_by_pwd {
    # This will delete all the torn off schemes for a given password.
    # Useful when deleteing a batch.

    my $self = shift;
    my %args = @_;
    my $pwd  = $args{pwd} || confess("'pwd' is a required arg");
	# SID is not required.  You may want to delete all trace if a pwd.
    my $SID  = $args{SID} ; # || confess("'SID' is a required arg");

    my $dbh  = $self->dbh || return undef;

    my $sql = 'select * from EMAIL_SCHEME_STATUS where PWD=?';
    my $recs = $self->search_by_pwd(SID=>$SID,pwd=>$pwd) || return undef;

    my $res   = [];
    my $fails = [];
    foreach my $rec (@$recs) {
        if (
            $self->delete_scheme(
                tear_off  => 1,
                scheme_id => $rec->{EMAIL_SCHEME_STATUS_ID}
            )
          )
        {
            push @$res,
              "Deleted $rec->{SCHEME_STATUS_NAME} scheme for $rec->{PWD}";
        } else {
            push @$fails, $self->err;
        }
    }
    if (@$fails) {
        $self->err($fails);
        return ;
    } else {
        return join "\n", @$res;
    }
}


sub dump_scheme {
    # dumps a scheme.  If you pass an zip=>new Archive::Zip in then we'll
    # grab any templates referenced and whack them in the zip file.  The
    # names are put into zip_already hash.
    my $self      = shift;
    my $ez        = $self->ez;
    my %args      = @_;
    my $list      = delete $args{list};
    my $es        = delete $args{scheme_row};
    my $dump_head = delete $args{dump_head};
    # These next ones are needed if we are using the zip file.
    my $zip         = delete $args{zip};
    my $zip_already = delete $args{zip_already};
    my $troot       = delete $args{troot};

    confess "Unrecognised args" . Dumper \%args if %args;

    $troot = "$troot/" if $troot and $troot !~ m#/$#;

    $ez->row_freeze(
        list => $list,
        row  => $es,
        head => "$dump_head:EMAIL_SCHEME"
    );
    my $ets = [];
    if ( exists $es->{EMAIL_SCHEME_ID} ) {
        $ets = $ez->get_rows(
            table    => 'EMAIL_TRACK',
            key      => 'EMAIL_SCHEME_ID',
            val      => $es->{EMAIL_SCHEME_ID},
            order => 'TRACK_INTERVAL',
        ) || ( $self->err( $ez->err ) && return );
    }

    foreach my $et (@$ets) {
        $ez->row_freeze(
            list  => $list,
            row   => $et,
            level => 2,
            head  => "$dump_head:EMAIL_TRACK"
        );
        my $ems = $ez->get_rows(
            table    => 'EMAIL_MSG',
            key      => 'EMAIL_TRACK_ID',
            val      => $et->{EMAIL_TRACK_ID},
            order => 'MESSAGE_INTERVAL',
        ) || ( $self->err( $ez->err ) && return );
        foreach my $em (@$ems) {
            $ez->row_freeze(
                list  => $list,
                row   => $em,
                level => 3,
                head  => "$dump_head:EMAIL_MSG"
            );
            if ( $zip or $zip_already ) {
                my $ts = new TPerl::Sender(
                    SID     => $es->{SID},
                    name    => $em->{TEMPLATE},
                    lang    => lc( $em->{LANGUAGE} ),
                    noplain => !$em->{USE_PLAIN_FLAG},
                    nohtml  => !$em->{USE_HTML_FLAG}
                );
                my $fnl = $ts->filenames_list
                  || ( $self->err( $ts->err ) && return );
                foreach my $fn (@$fnl) {
                    unless ( $zip_already->{$fn} ) {
                        my $zname = $fn;
                        $zname =~ s/$troot//;
                        $zip->addFile( $fn, $zname )
                          if $zip
                          and !$zip->memberNamed($zname);
                        $zip_already->{$fn} = $zname;
                    }
                }
            }
        }
    }
    return 1;
}

sub click_through {
  # we want to stop tracks being sent when people read or click through a survey
  # stop all the tracks that have started at this point in time for the PWD
  #
  # DIY events.  This module is about schemes, it does not now about MAP or bosses or anything.
  
    my $self = shift;
    my %args = @_;

    my $pwd = delete $args{pwd};
    my $when_pretty = delete $args{when} || 'now';
    confess( "Unrecognised args:" . Dumper \%args ) if %args;
    confess("'pwd' is a required arg") unless $pwd;

    my $recs = $self->active_tracks( when => $when_pretty, pwd => $pwd )
      || return undef;

    my $dbh = $self->dbh || return;
    my $sql =
'update EMAIL_TRACK_STATUS set TRACK_READ_FLAG = 1 where EMAIL_TRACK_STATUS_ID =?';
    foreach my $r (@$recs) {
        if ( $dbh->do( $sql, {}, $r->{EMAIL_TRACK_STATUS_ID} ) ) {
            $r->{EVENT_MSG} =
              "Set READ=YES for Track $r->{EMAIL_TRACK_STATUS_ID}";
        } else {
            $self->err(
                {
                    dbh    => $dbh,
                    sql    => $sql,
                    params => [ $r->{EMAIL_TRACK_STATUS_ID} ]
                }
            );
            return;
        }
    }
    return $recs;
}

sub active_tracks {
# This is a wrapper round sql that returns the tracks that have messages
# around the given time.
# To test from command line
# perl -MTPerl::EScheme -MData::Dumper -e 'print Dumper (TPerl::EScheme->active_tracks(pwd=>"YEGSTCDK"))'
    my $self = shift;
    my %args = @_;

    my $pwd = delete $args{pwd};
    my $when_pretty = delete $args{when} || 'now';
    confess( "Unrecognised args:" . Dumper \%args ) if %args;
    confess("'pwd' is a required arg") unless $pwd;

    my $dbh = $self->dbh;
    unless ($dbh) {
        $self->err("No dbh");
        return undef;
    }
    my $ez   = $self->ez;
    my $when = $ez->text2epoch($when_pretty);
  # build a list of tracks to stop based on the PWD the SID and the current time
    my $sql = '
		select 
			EMAIL_MSG_STATUS.EMAIL_TRACK_STATUS_ID,
			min(START_EPOCH) as TRACK_START,
			max(START_EPOCH) as TRACK_END
		from EMAIL_MSG_STATUS,EMAIL_TRACK_STATUS,EMAIL_SCHEME_STATUS
		where 
			EMAIL_MSG_STATUS.EMAIL_TRACK_STATUS_ID=EMAIL_TRACK_STATUS.EMAIL_TRACK_STATUS_ID
			and EMAIL_SCHEME_STATUS.EMAIL_SCHEME_STATUS_ID = EMAIL_TRACK_STATUS.EMAIL_SCHEME_STATUS_ID
			and EMAIL_SCHEME_STATUS.PWD=?
		group by EMAIL_MSG_STATUS.EMAIL_TRACK_STATUS_ID
		having min(START_EPOCH) < ? and max(START_EPOCH) > ?
	';
    my $recs =
      $dbh->selectall_arrayref( $sql, { Slice => {} }, $pwd, $when, $when );
    unless ($recs) {
        $self->err( { sql => $sql, dbh => $dbh } );
        return undef;
    }
    map {
        $_->{TRACK_START_PRETTY} = $ez->epoch2text( $_->{TRACK_START} );
        $_->{TRACK_END_PRETTY}   = $ez->epoch2text( $_->{TRACK_END} )
    } @$recs;
    return $recs;
}

1;

