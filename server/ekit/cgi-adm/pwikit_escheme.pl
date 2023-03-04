#!/usr/bin/perl
use strict;

# use warnings;
use CGI::Carp qw (fatalsToBrowser);
use TPerl::MyDB;
use TPerl::CGI;
use TPerl::LookFeel;
use TPerl::DBEasy;

my $dbh = dbh TPerl::MyDB( attr => { PrintError => 0, RaiseError => 1 } );
my $lf  = new TPerl::LookFeel;
my $q   = new TPerl::CGI;
my $ez  = new TPerl::DBEasy( dbh => $dbh );
my %args = $q->args;

my $def_select_order = [
    qw(
      EMAIL_SCHEME_STATUS_ID
      SCHEME_STATUS_NAME
      SID
      FULLNAME
      SCHEME_STATUS_FLAT.PWD
      STOP_FIELD
      CHECK_STATUS_FLAG
      TEAR_EXISTS_FLAG
      LANGUAGE
      SCHEME_DONE_EPOCH
      SCHEME_ACTIVE_FLAG
      EMAIL_SCHEME_ID
      EMAIL_TRACK_STATUS_ID
      TRACK_STATUS_NAME
      TRACK_INTERVAL
      TRACK_READ_FLAG
      TRACK_STOP_FLAG
      TRACK_HOLD_FLAG
      EMAIL_MSG_STATUS_ID
      MESSAGE_STATUS_NAME
      WORKING_TEMPLATE
      USE_HTML_FLAG
      USE_PLAIN_FLAG
      ALERT_FLAG
      ALERT_EMAIL
      CREATED_EPOCH
      START_EPOCH
      DONE_EPOCH
      SENT_MSG
      SENT_ERROR
      SENDMAIL_ID
      RETURN_MSG
      UID
      CNT
      ISREADY
      Q1
      Q2
      Q3
      Q4
      Q5
      Q6
      Q7
      Q8
      Q9
      Q10A
      Q10
      Q11
      Q12
      Q18
      BATCHNO
      EXECNAME
      LOCID
      LOCNAME
      WSID
      WSDATE
      WSDATE_D
      DUEDATE
      DUEDATE_D
      NBOSS
      NPEER
      CREDIT_CARD_HOLDER
      CCT_ID
      CREDIT_CARD_NO
      CREDIT_CARD_REC
      CREDIT_EXP_DATE
      EARLY_ARRIVAL
      EARLY_ARRIVAL_DATE
      EARLY_ARRIVAL_TIME
      WITH_GUEST
      GUEST_DINNER_DAY1
      GUEST_DINNER_DAY2
      DIETARY_RESTRICT
      REVISED_FULLNAME
      OCCUPANCY
      LAST_UPDATE_TS
      CMS_STATUS
      CMS_FLAG

      )
];

my $def_select_on = {
    EMAIL_SCHEME_STATUS_ID   => 1,
    SCHEME_STATUS_NAME       => 1,
    SID                      => 1,
    STOP_FIELD               => 0,
    CHECK_STATUS_FLAG        => 0,
    TEAR_EXISTS_FLAG         => 0,
    LANGUAGE                 => 0,
    SCHEME_DONE_EPOCH        => 1,
    SCHEME_ACTIVE_FLAG       => 1,
    EMAIL_SCHEME_ID          => 0,
    EMAIL_TRACK_STATUS_ID    => 0,
    TRACK_STATUS_NAME        => 1,
    TRACK_INTERVAL           => 0,
    TRACK_READ_FLAG          => 1,
    TRACK_STOP_FLAG          => 1,
    TRACK_HOLD_FLAG          => 1,
    EMAIL_MSG_STATUS_ID      => 0,
    MESSAGE_STATUS_NAME      => 0,
    WORKING_TEMPLATE         => 1,
    USE_HTML_FLAG            => 1,
    USE_PLAIN_FLAG           => 1,
    ALERT_FLAG               => 0,
    ALERT_EMAIL              => 0,
    CREATED_EPOCH            => 0,
    START_EPOCH              => 1,
    DONE_EPOCH               => 1,
    SENT_MSG                 => 1,
    SENT_ERROR               => 1,
    SENDMAIL_ID              => 1,
    RETURN_MSG               => 0,
    UID                      => 0,
    'SCHEME_STATUS_FLAT.PWD' => 1,
    CNT                      => 0,
    ISREADY                  => 0,
    Q1                       => 0,
    Q2                       => 0,
    Q3                       => 0,
    Q4                       => 0,
    Q5                       => 0,
    Q6                       => 0,
    Q7                       => 0,
    Q8                       => 0,
    Q9                       => 0,
    Q10A                     => 0,
    Q10                      => 0,
    Q11                      => 0,
    Q12                      => 0,
    Q18                      => 0,
    FULLNAME                 => 1,
    BATCHNO                  => 0,
    EXECNAME                 => 0,
    LOCID                    => 0,
    LOCNAME                  => 0,
    WSID                     => 0,
    WSDATE                   => 0,
    WSDATE_D                 => 1,
    DUEDATE                  => 0,
    DUEDATE_D                => 0,
    NBOSS                    => 0,
    NPEER                    => 0,
    CREDIT_CARD_HOLDER       => 0,
    CCT_ID                   => 0,
    CREDIT_CARD_NO           => 0,
    CREDIT_CARD_REC          => 0,
    CREDIT_EXP_DATE          => 0,
    EARLY_ARRIVAL            => 0,
    EARLY_ARRIVAL_DATE       => 0,
    EARLY_ARRIVAL_TIME       => 0,
    WITH_GUEST               => 0,
    GUEST_DINNER_DAY1        => 0,
    GUEST_DINNER_DAY2        => 0,
    DIETARY_RESTRICT         => 0,
    REVISED_FULLNAME         => 0,
    OCCUPANCY                => 0,
    LAST_UPDATE_TS           => 0,
    CMS_STATUS               => 0,
    CMS_FLAG                 => 0,
};

my $table = 'SCHEME_STATUS_FLAT Left Join PWI_STATUS On SCHEME_STATUS_FLAT.PWD = PWI_STATUS.PWD';

my $wheres = {};
foreach my $a ( keys %args ) {
    if ( my ($f) = $a =~ /^where_(.*)/ ) {
        my $vals = [];
        $vals = $args{$a} if exists $args{$a};
        $vals = [$vals] unless ref($vals) eq 'ARRAY';
        # $q->mydie({v=>$vals,a=>\%args});
		my @ors = ();
		my @vas = ();
		foreach my $v (@$vals){
			if ($v eq 'NULLNULL'){
				push @ors, "$f is NULL";
			}elsif ($v eq 'NOTNULLNULL'){
				push @ors, "$f is not NULL";
			}else{
				push @ors,"$f=?";
				push @vas,$v;
			}
		}
        $wheres->{$f}->{vals} = \@vas;
        $wheres->{$f}->{sql} = join ' OR ', @ors;
    }
}
# $q->mydie({wheres=>$wheres,args=>\%args});


# Some where fields get distinct values from the database
my $where_fields     = [qw(SID SCHEME_STATUS_NAME TRACK_READ_FLAG TRACK_STATUS_NAME WSDATE_D)];
my $distincts_vals   = {};
my $distincts_labels = {};
foreach my $wf (@$where_fields) {
    my $saved_where = delete $wheres->{$wf};
    my $where_sql = join ' AND ', map "( $wheres->{$_}->{sql} )", keys %$wheres;
    $where_sql = 'WHERE ' . $where_sql if $where_sql;
    my $where_par = [];
    push @$where_par, @{ $wheres->{$_}->{vals} } foreach keys %$wheres;
    my $sql = "select distinct($wf) from $table $where_sql order by 1";

    $distincts_vals->{$wf} = $dbh->selectcol_arrayref( $sql, {}, @$where_par )
      || $q->mydie( { sql => $sql, params => $where_par, dbh => $dbh } );
    foreach ( @{ $distincts_vals->{$wf} } ) {
        unless ( defined($_) ) {
            $_ = 'NULLNULL';
            $distincts_labels->{$wf}->{$_} = '_null_';
        }
        $distincts_labels->{$wf}->{$_} ||= $_ || '_blank_';
    }
    $wheres->{$wf} = $saved_where if defined $saved_where;
}
# Some get NULL NOTNULL explicitly
foreach my $wf (qw(SENDMAIL_ID)){
	push @$where_fields,$wf;
	$distincts_vals->{$wf} = [qw(NULLNULL NOTNULLNULL)];
	$distincts_labels->{$wf} = {NULLNULL=>'empty',NOTNULLNULL=>'not empty'};
}

# $q->mydie({list=>$where_fields,distincts=>$distincts_vals,labs=>$distincts_labels});


my $where_sql = join ' AND ', map "( $wheres->{$_}->{sql} )", keys %$wheres;
$where_sql = 'WHERE ' . $where_sql if $where_sql;
my $where_par = [];
push @$where_par, @{ $wheres->{$_}->{vals} } foreach keys %$wheres;

my $sql = 'Select ' . join( ',', grep $def_select_on->{$_}, @$def_select_order ) . 
" from $table $where_sql";


# $q->mydie($sql);
my $sth = $dbh->prepare($sql) || $q->mydie(sql=>$sql,dbh=>$dbh);
$sth->execute(@$where_par);
my $fields = $ez->fields( sth => $sth );
foreach my $f ( keys %$distincts_labels ) {
    $distincts_labels->{$f} = $fields->{$f}->{cgi}->{args}->{-labels}
      if exists $fields->{$f} && exists $fields->{$f}->{cgi}->{args}->{-labels};
}
# $q->mydie({f=>$fields->{TRACK_READ_FLAG},distincts=>$distincts_vals,labs=>$distincts_labels});

$fields->{EMAIL_SCHEME_STATUS_ID}->{sprintf} = {
    fmt =>
      qq{<a target="_blank" href="/cgi-adm/escheme_status.pl?EMAIL_SCHEME_STATUS_ID=%d">Status %d</a>},
    names => [qw(EMAIL_SCHEME_STATUS_ID EMAIL_SCHEME_STATUS_ID)]
};
# $fields->{PWD}->{sprintf} = {
#     fmt =>
#       qq{<a target="_blank" href="/cgi-adm/escheme_status.pl?search_PWD=%s&search=search"<%s></a>},
#     names => [qw(PWD PWD)]
# };
# $q->mydie($fields);

my $where_cols = 4;

print join "\n", 
	$q->header(),
	$q->start_html( -title => 'PWI escheme stats',-style=>{src=>'/cgi-adm/style.css'} ),
	# $sql,
	# $q->dumper(\%args),
	'<table><tr><form>',
    map ( qq{<td class="options">$fields->{$_}->{pretty}:}
          . $q->checkbox_group(
            -name    => "where_$_",
            -values  => $distincts_vals->{$_},
            -labels  => $distincts_labels->{$_},
            -columns => $where_cols,
          )
          . '</td>',
        @$where_fields ),
    sprintf(
        qq{<tr><td align="center" class="options2" colspan="%d">%s</td></tr>},
        scalar(@$where_fields),
        $q->submit( -name => 'filter', -value => 'Filter' )
      ),
	'</form></tr></table>',

	$ez->lister_wrap( sth => $sth,look=>$lf,fields=>$fields ),
	$q->end_html;
