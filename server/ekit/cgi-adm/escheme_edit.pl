#!/usr/bin/perl 
use strict;
use CGI::Carp qw (fatalsToBrowser);
use TPerl::CGI;
use TPerl::LookFeel;
use TPerl::EScheme;
use TPerl::Sender;
use TPerl::Error;
use FileHandle;
use Data::Dumper;

# Some stuff we need.
my $q = new TPerl::CGI;
# a blank $q that does not use .cgifields, when we don't want it too...
my $bq   = new TPerl::CGI('');
my %args = $q->args;
my $eso  = new TPerl::EScheme;                  # $eso = email_scheme_object.
my $lf   = new TPerl::LookFeel;
my $e    = new TPerl::Error( noSTDOUT => 1 );

my $dbh = $eso->dbh;
my $ez = new TPerl::DBEasy( dbh => $dbh );

my $es_fields = $eso->EMAIL_SCHEME_fields;
my $et_fields = $eso->EMAIL_TRACK_fields;
my $em_fields = $eso->EMAIL_MSG_fields;

$args{EMAIL_SCHEME_ID} ||= '';

$args{SCHEME_NAME} = lc( $args{SCHEME_NAME} ) if exists( $args{SCHEME_NAME} );

### A whole lot of stuff to deciper the args and to updates and inserts
#needs to go here.    Its gunna be ugly.  lets keep the comments up

my @msgs = ();

### Did someone push a button?
if ( $args{action} ) {

    # Strip away the leading and trailing slashes.
    $args{$_} =~ s/^\s*(.*?)\s*$/$1/ foreach keys %args;

    my $tkeys = $eso->table_keys;

# sort the args into a hierarchy of things that can be used in row_manips.  ie
# $args{1_2_XXX} is moved to $h->{1}->{kids}->{2}->{XXX}.  Similarly $args{old_1_YYY}
# is moved to $o->{1}->{data}->{YYY}
    my $h = {};
    my $o = {};
    foreach my $arg ( keys %args ) {
        if ( my ( $t, $n, $f ) = $arg =~ /^X(\d+)_(\d+)_([A-Z].*)$/ ) {
            $h->{$t}->{kids}->{$n}->{$f} = $args{$arg};
        } elsif ( my ( $t, $f ) = $arg =~ /^(\d+)_([A-Z].*)$/ ) {
            $h->{$t}->{data}->{$f} = $args{$arg};
        } elsif ( my ( $t, $n, $f ) = $arg =~ /^old_X(\d+)_(\d+)_([A-Z].*)$/ ) {
            $o->{$t}->{kids}->{$n}->{$f} = $args{$arg};
        } elsif ( my ( $t, $f ) = $arg =~ /^old_(\d+)_([A-Z].*)$/ ) {
            $o->{$t}->{data}->{$f} = $args{$arg};
        }
    }
    # print $q->mydie({h=>$h,o=>$o});

    # Turn off AutoCommit and start a transaction.  Any errors
    # mean all inserts/updates are cancelled and report errors.
    $dbh->begin_work;

# If we made a new EMAIL_SCHEME_ID then all updates become inserts (ie a save as or a new..)
    my $did_new_es;

    # Deal with EMAIL_SCHEME table first.
    if ( ( $args{old_EMAIL_SCHEME_ID} eq '' ) || $args{action} eq 'saveas' ) {
        # An insert.
        delete $args{EMAIL_SCHEME_ID};
        if (
            my $err = $ez->row_manip(
                action => 'insert',
                table  => 'EMAIL_SCHEME',
                fields => $es_fields,
                vals   => \%args,
                keys   => ['EMAIL_SCHEME_ID']
            )
          )
        {
            $dbh->rollback;
            $q->mydie($err);
        }
        # Need the new EMAIL_SCHEME_ID for display purposes below.
        $args{EMAIL_SCHEME_ID} = $ez->vals->{EMAIL_SCHEME_ID};
        # push @msgs,"Made a new EMAIL_SCHEME with id $args{EMAIL_SCHEME_ID}";
        $did_new_es = 1;
    } elsif ( $args{EMAIL_SCHEME_ID}
        and ( $args{SID} eq '' or $args{SCHEME_NAME} eq '' ) )
    {
        # a delete.
        if ( $eso->delete_scheme( scheme_id => $args{EMAIL_SCHEME_ID} ) ) {
            # kill off all the stuff and do an empty form.
            %args = ( EMAIL_SCHEME_ID => '' );
            $h    = {};
            $o    = {};
        } else {
            $dbh->rollback;
            $q->mydie( $eso->err );
        }
    } else {
        # An update.
        if (    ( $args{SID} eq $args{old_SID} )
            and ( $args{SCHEME_NAME}       eq $args{old_SCHEME_NAME} )
            and ( $args{STOP_FIELD}        eq $args{old_STOP_FIELD} )
            and ( $args{TEAR_EXISTS_FLAG}  eq $args{old_TEAR_EXISTS_FLAG} )
            and ( $args{CHECK_STATUS_FLAG} eq $args{old_CHECK_STATUS_FLAG} ) )
        {
# push @msgs,"No changes necessary to EMAIL_SCHEME_ID=$args{EMAIL_SCHEME_ID}";
# '$args{SID}'eq'$args{old_SID}' and $args{SCHEME_NAME} eq $args{old_SCHEME_NAME}";
        } else {
            if (
                my $err = $ez->row_manip(
                    action => 'update',
                    table  => 'EMAIL_SCHEME',
                    fields => $es_fields,
                    vals   => \%args,
                    keys   => $tkeys
                )
              )
            {
                $q->mydie($err);
                $dbh->rollback;
            }
            # push @msgs,"Changed EMAIL_SCHEME_ID=$args{EMAIL_SCHEME_ID}";
        }
    }
    # Check for new/updated/deleted tracks.
    foreach my $tnum ( sort { $a <=> $b } keys %$h ) {
        my $et_vals = $h->{$tnum}->{data};
        my $et_olds = $o->{$tnum}->{data};
        # we need the parent relationship too.
        $et_vals->{EMAIL_SCHEME_ID} = $args{EMAIL_SCHEME_ID};
        if ( ( $et_olds->{EMAIL_TRACK_ID} eq '' ) or $did_new_es ) {
            if ( $et_vals->{TRACK_NAME} ) {
                # push @msgs, "Will insert from track $tnum";
                delete $et_vals->{EMAIL_TRACK_ID};
                if (
                    my $err = $ez->row_manip(
                        table  => 'EMAIL_TRACK',
                        action => 'insert',
                        keys   => $tkeys,
                        vals   => $et_vals
                    )
                  )
                {
                    $dbh->rollback;
                    $q->mydie($err);
                }
         # an insert means we have a new EMAIL_TRACK_ID.  don't use the old one.
                $et_vals->{EMAIL_TRACK_ID} = $ez->vals->{EMAIL_TRACK_ID};
                # push @msgs,"Inserted track $tnum ".$q->dumper($ez->vals);
            } else {
                # push @msgs ,"No $tnum TRACK_NAME not inserting";
            }
        } elsif ( $et_vals->{TRACK_NAME} eq '' ) {
            # delete the kids, then the track itself.
            if (
                $eso->cascade_delete( track_id => $et_vals->{EMAIL_TRACK_ID} ) )
            {
                #push @msgs,"Deleted EMAIL_TRACK_ID= and all kids";
            } else {
                $dbh->rollback;
                $q->mydie( $eso->err );
            }
        } else {
            # push @msgs ,"Will update from track $tnum";
            # push @msgs, $q->dumper({old=>$et_olds,new=>$et_vals});
            if (
                my $err = $ez->row_manip(
                    action => 'update',
                    table  => 'EMAIL_TRACK',
                    fields => $et_fields,
                    keys   => $tkeys,
                    vals   => $et_vals
                )
              )
            {
                $dbh->rollback;
                $q->mydie($err);
            }
        }

        # Now do the messages.
        foreach my $mnum ( sort { $a <=> $b } keys %{ $h->{$tnum}->{kids} } ) {
            my $em_vals = $h->{$tnum}->{kids}->{$mnum};
            my $em_olds = $o->{$tnum}->{kids}->{$mnum};
            # ensure the correct parent.
            $em_vals->{EMAIL_TRACK_ID}   = $et_vals->{EMAIL_TRACK_ID};
            $em_vals->{MESSAGE_INTERVAL} = '0'
              if $em_vals->{MESSAGE_INTERVAL} eq '';
            $em_vals->{TEMPLATE} = lc( $em_vals->{TEMPLATE} );
            if ( ( $em_olds->{EMAIL_MSG_ID} eq '' ) or $did_new_es ) {
                if ( $em_vals->{MESSAGE_NAME} ne '' ) {
                    delete $em_vals->{EMAIL_MSG_ID};
                    # push @msgs, "Track $tnum msg $mnum in an insert" ;
                    if (
                        my $err = $ez->row_manip(
                            action => 'insert',
                            table  => 'EMAIL_MSG',
                            keys   => $tkeys,
                            fields => $em_fields,
                            vals   => $em_vals
                        )
                      )
                    {
                        $dbh->rollback;
                        $q->mydie($err);
                    }
                } else {
             # push @msgs,"No insert: No MESSAGE_NAME at Track $tnum msg $mnum";
                }
            } elsif ( $em_vals->{MESSAGE_NAME} eq '' ) {
                # push @msgs,"Deleting msg $mnum in track $tnum";
                if (
                    $eso->cascade_delete( msg_id => $em_vals->{EMAIL_MSG_ID} ) )
                {
                    #push @msgs,"Deleted EMAIL_TRACK_ID= and all kids";
                } else {
                    $dbh->rollback;
                    $q->mydie( $eso->err );
                }
            } else {
                # push @msgs,"Will update from Track $tnum msg $mnum";
                if (
                    my $err = $ez->row_manip(
                        action => 'update',
                        table  => 'EMAIL_MSG',
                        keys   => $tkeys,
                        fields => $em_fields,
                        vals   => $em_vals
                    )
                  )
                {
                    $dbh->rollback;
                    $q->mydie( { err => $err, track => $tnum, mess => $mnum } );
                    $q->mydie($err);
                }
            }
        }
    }
    # lets not make any changes just yet...
    # $dbh->rollback;
    $dbh->commit;
}

## Then we display stuff.
#
my $title = 'Email Scheme Editor';

my $es_sql = 'select * from EMAIL_SCHEME where EMAIL_SCHEME_ID=?';
my $es_rows =
  $dbh->selectall_arrayref( $es_sql, { Slice => {} }, $args{EMAIL_SCHEME_ID} )
  || $q->mydie(
    { sql => $es_sql, dbh => $dbh, params => [ $args{EMAIL_SCHEME_ID} ] } );

$es_rows->[0]->{SID} ||= $args{SID} || 'SID';

my $jscript = qq{
	function valid_save (button){
		var form = button.form;
		if ((form.SCHEME_NAME.value == '') && (form.EMAIL_SCHEME_ID.value == '')){
			alert ('$es_fields->{SCHEME_NAME}->{pretty} cannot be left blank');
		}else{
			form.submit();
		}
	}
};

print join "\n", $q->header,
  $q->start_html(
    -style  => { src => "/admin/style.css" },
    -title  => $title,
    -script => $jscript
  ),
  # $q->dumper( \%args ),
  # $q->dumper($es_fields),
  $q->start_form( -action => $ENV{SCRIPT_NAME} ), join( "\n<BR>", @msgs ),
  $lf->srbox( $title . " $args{EMAIL_SCHEME_ID}" ), $lf->st, $lf->trow(
    [
        "$es_fields->{SID}->{pretty}:",
        $ez->field2val(
            field => $es_fields->{SID},
            row   => $es_rows->[0],
            form  => 1
          )
          . $bq->hidden(
            -name    => 'old_SID',
            -default => ( @$es_rows ? $es_rows->[0]->{SID} : '' )
          ),
        "$es_fields->{SCHEME_NAME}->{pretty}:",
        $ez->field2val(
            field => $es_fields->{SCHEME_NAME},
            row   => $es_rows->[0],
            form  => 1
          )
          . $bq->hidden(
            -name    => 'old_SCHEME_NAME',
            -default => ( @$es_rows ? $es_rows->[0]->{SCHEME_NAME} : '' )
          ),
        "$es_fields->{TEAR_EXISTS_FLAG}->{pretty}:",
        $ez->field2val(
            field => $es_fields->{TEAR_EXISTS_FLAG},
            row   => $es_rows->[0],
            form  => 1
          )
          . $bq->hidden(
            -name    => 'old_TEAR_EXISTS_FLAG',
            -default => ( @$es_rows ? $es_rows->[0]->{TEAR_EXISTS_FLAG} : '' )
          ),
        "$es_fields->{CHECK_STATUS_FLAG}->{pretty}:",
        $ez->field2val(
            field => $es_fields->{CHECK_STATUS_FLAG},
            row   => $es_rows->[0],
            form  => 1
          )
          . $bq->hidden(
            -name    => 'old_CHECK_STATUS_FLAG',
            -default => ( @$es_rows ? $es_rows->[0]->{CHECK_STATUS_FLAG} : '' )
          ),
        "$es_fields->{STOP_FIELD}->{pretty}:",
        $ez->field2val(
            field => $es_fields->{STOP_FIELD},
            row   => $es_rows->[0],
            form  => 1
          )
          . $bq->hidden(
            -name    => 'old_STOP_FIELD',
            -default => ( @$es_rows ? $es_rows->[0]->{STOP_FIELD} : '' )
          )
          . $ez->field2val(
            field => $es_fields->{EMAIL_SCHEME_ID},
            row   => $es_rows->[0],
            form  => 1
          )
          . $bq->hidden(
            -name    => 'old_EMAIL_SCHEME_ID',
            -default => @$es_rows ? $es_rows->[0]->{EMAIL_SCHEME_ID} : ''
          ),
        # If someone presses enter, lets save their changes.
    ]
  ),
  $lf->{_last_row} = 1, '<tr class = "options1">',
  map ( "<td>$_</td>",
    $bq->hidden( -name => 'action', value => 'save' ),
    $q->button(
        -id      => 'button',
        -value   => 'S A V E',
        -onclick => "this.form.action.value='save';valid_save(this);"
    ),
    '',
    $q->button(
        -id      => 'button',
        -value   => 'S A V E   A S',
        -onclick => "this.form.action.value='saveas';this.form.submit();"
      ) ),
  '</tr>', $lf->et,

  $lf->erbox, '<hr>';

## Now we want to step through any tracks.
my $et_rows = [];
if ( $es_rows->[0]->{EMAIL_SCHEME_ID} ) {
    my $et_sql =
'select * from EMAIL_TRACK where EMAIL_SCHEME_ID=? order by TRACK_INTERVAL';
    $et_rows = $dbh->selectall_arrayref(
        $et_sql,
        { Slice => {} },
        $es_rows->[0]->{EMAIL_SCHEME_ID}
      )
      || $q->mydie(
        {
            sql    => $et_sql,
            dbh    => $dbh,
            params => [ $et_rows->[0]->{EMAIL_SCHEME_ID} ]
        }
      );
}

###Default values for tracks.
if ( @$et_rows == 0 ) {
    push @$et_rows, { TRACK_NAME => 'Invite1', TRACK_INTERVAL => 0 },
      { TRACK_NAME => 'Reminder1', TRACK_INTERVAL => 7 * 24 * 3600 },
      {
        TRACK_NAME     => 'Reminder2',
        TRACK_INTERVAL => 14 * 24 * 3600
      };    # Blank rows on the end...
# }elsif (@$et_rows < 3 ){
# 	push @$et_rows, {TRACK_INTERVAL=>0},{TRACK_INTERVAL=>0};  # Blank rows on the end...
} else {
    push @$et_rows, { TRACK_INTERVAL => 0 };
}
my $tsend;
my $t_list;
if ( $args{EMAIL_SCHEME_ID} ) {
    $tsend = new TPerl::Sender( SID => $es_rows->[0]->{SID} );
    $t_list = $tsend->template_list
      || $q->mydie( "Issues with template list for $args{SID}" . $tsend->err );
    unshift @$t_list, '';    # a blank template...
}

my $track_num = 1;
foreach my $et_row (@$et_rows) {
    my $n_pre     = "${track_num}_";
    my $row_title = join "\n",
      $ez->field2val(
        field       => $et_fields->{EMAIL_TRACK_ID},
        row         => $et_row,
        form        => 1,
        name_prefix => $n_pre
      ),
      'Track Name:',
      $ez->field2val(
        field       => $et_fields->{TRACK_NAME},
        row         => $et_row,
        form        => 1,
        name_prefix => $n_pre
      ),
      'Track Interval',
      $ez->field2val(
        field       => $et_fields->{TRACK_INTERVAL},
        row         => $et_row,
        form        => 1,
        name_prefix => $n_pre
      ),
      # Some hiddens need raw values, and some need computed ones.
      map ( $bq->hidden( -name => "old_$n_pre$_", -default => $et_row->{$_} ),
        qw(EMAIL_TRACK_ID TRACK_NAME) ),
      map ( $bq->hidden(
            -name    => "old_$n_pre$_",
            -default => $ez->field2val(
                nonbsp => 1,
                field  => $et_fields->{$_},
                row    => $et_row
            )
        ),
        qw(TRACK_INTERVAL) ),
      ;
    $lf->{_last_row} = 1;
    print join "\n", $lf->srbox($row_title), $lf->st,
      $lf->trow(
        [
            'Message Name', 'HTML?', 'Text?', 'Alert?',
            'Alert Email',  'Delta', 'Template'
        ]
      ),
      ;
    ### Then get any messages and loop through them.
    my $em_rows = [];
    if ( $et_row->{EMAIL_TRACK_ID} ) {
        my $em_sql =
'select * from EMAIL_MSG where EMAIL_TRACK_ID = ? order by MESSAGE_INTERVAL';
        $em_rows = $dbh->selectall_arrayref(
            $em_sql,
            { Slice => {} },
            $et_row->{EMAIL_TRACK_ID}
          )
          || $q->mydie(
            {
                sql    => $em_sql,
                dbh    => $dbh,
                params => [ $et_row->{EMAIL_TRACK_ID} ]
            }
          );
    }
    if ( @$em_rows < 4 ) {
        while ( @$em_rows < 4 ) {
            push @$em_rows,
              {
                USE_HTML_FLAG    => 1,
                USE_PLAIN_FLAG   => 1,
                ALERT_FLAG       => 0,
                MESSAGE_INTERVAL => 0,
                TEMPLATE         => ''
              };
        }
    } else {
        push @$em_rows,
          {
            USE_HTML_FLAG    => 0,
            USE_PLAIN_FLAG   => 0,
            ALERT_FLAG       => 0,
            MESSAGE_INTERVAL => 0,
            TEMPLATE         => 'CHANGE THIS'
          };
    }
    my $em_num = 1;
    foreach my $em_row (@$em_rows) {
        my $n_pre = "X${track_num}_${em_num}_";
        # delete $em_fields->{MESSAGE_INTERVAL}->{cgi}->{args}->{-disabled};
        # $em_fields->{MESSAGE_INTERVAL}->{cgi}->{args}->{-disabled} = 1
        # if $em_num == 1;
        # Do some jiggery pokery to get the custom and list for the template.
        # $em_fields->{TEMPLATE}->{cgi}->{func} = 'hidden';
        my $name = "${n_pre}TEMPLATE";
        my $vals = [];
        @$vals = map $ez->field2val(
            row         => $em_row,
            form        => 1,
            field       => $em_fields->{$_},
            name_prefix => $n_pre
          ),
          qw(MESSAGE_NAME USE_HTML_FLAG USE_PLAIN_FLAG ALERT_FLAG ALERT_EMAIL MESSAGE_INTERVAL TEMPLATE);
        # Put the leading mnum in the field.
        $vals->[0] = "$em_num.&nbsp;$vals->[0]";
        # put the ID in the form too.
        $vals->[0] .= "\n"
          . $ez->field2val(
            row         => $em_row,
            form        => 1,
            field       => $em_fields->{EMAIL_MSG_ID},
            name_prefix => $n_pre
          );
     # do the old values.  only _INTERVALS and _EPOCHS need the field2val calls.
        $vals->[0] .= join "\n",
          map ( $bq->hidden(
                -name    => "old_$n_pre$_",
                -default => $ez->field2val(
                    row     => $em_row,
                    field   => $em_fields->{$_},
                    no_nbsp => 1
                )
            ),
            qw(MESSAGE_INTERVAL) ),
          map ( $bq->hidden(
                -name    => "old_$n_pre$_",
                -default => $em_row->{$_}
            ),
            qw(EMAIL_MSG_ID MESSAGE_NAME USE_HTML_FLAG USE_PLAIN_FLAG ALERT_FLAG ALERT_EMAIL TEMPLATE)
          );
        # Add the drop down list.
        $vals->[-1] .= $q->popup_menu(
            -name => "special$name",
            # -onChange=>"alert('$name='+this.form.special$name.value);",
            -onChange => "this.form.$name.value=this.form.special$name.value;",
            -override => 1,
            -default  => $em_row->{TEMPLATE},
            -values   => $t_list,
        ) if $tsend;
        ## Add the edit template link into the template.
        if ( $em_row->{TEMPLATE} ne 'CHANGE THIS' ) {
            my $SID = $es_rows->[0]->{SID};
            $vals->[-1] .=
qq{<a href="editemailMCE.pl?SID=$SID&template=$em_row->{TEMPLATE}" target="_blank">}
              . qq{<IMG border="0" src="/pix/edit.gif" alt="Edit Template"></a>};
        }

        $lf->{_last_row} = 2;
        print $lf->trow($vals);
        $em_num++;
    }
    print join "\n", $lf->etbox, $lf->erbox, '<br>',;
    $track_num++;
}

# my $dfh = new FileHandle (">> /tmp/escheme_edit1");
# print $dfh Dumper (\%args);

print join "\n", $q->end_form,
  # $q->dumper(\%args),
  # $q->dumper($es_rows),
  # $q->dumper($em_fields),
  $q->end_html;
