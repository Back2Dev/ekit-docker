# Copyright 2002 Triton Technology
# $Id: Event.pm,v 1.28 2011-05-06 17:27:04 triton Exp $
package TPerl::Event;
use strict;
use TPerl::MyDB;
use TPerl::DBEasy;
use Data::Dumper;
use TPerl::TSV;
use Time::Local;
use Carp;
use String::Approx qw (amatch);
use TPerl::TableManip;
our ($AUTOLOAD);
our @ISA = qw (TPerl::TableManip);
use TPerl::TransactionList;

=head1 SYNOPSIS

make a new object.

 my $ev = new TPerl::Event (db=>'ib',dbh=>$dbh);

make an event table.  # this is on the todo list

 # my $err = $ev->table (SID=>'GOOSE123',drop=>1,create=>1);

do an I event (or a W or an E)
 
 $ev->W(SID=>'GOOSE123',msg=>'Made a Warning',pwd=>'12345',code=>'send reminder') or die $ev->error;

or from the command line

  perl -MTPerl::Event -e "TPerl::Event->I(SID=>'ABC123',code=>'survey start',msg=>'Fake start',pwd=>1234)"

get some DBEasy fields.  The fields for each table are cached in the $ev object
to save hitting the database too many times.

 my $fields = $ev->fields (SID);

use Sting::Approx to find if there is a match for event called 'del recip'

 my $text = 'del recip';
 if (my $num = $ev->number($text)){
 	my $pretty = $ev->names->{$num}
	print "The number for '$text' ($pretty) is $num\n";
 }else{
 	### $num is now 0 for UNKOWN
 	print "number for $text is $num ($pretty)\n";
 }

array ref for all events that match 'survey'

 my $match = $ev->match('survey');

=head1 DESCRIPTION

Replaces and enhances the db_add_info_event type functions in qt-db.pl uses
String::Approx to do closest matching of event names.  Uses DBEasy to make sure
string lengths are ok, and non nullable fields are filled in with something.
Use TPerl::MyDB to hold the definitions of the databases.  

Uses names parameters so you can pass all or no extra info to Events.

It provides a way to get the 'pretty names' of the events back for web form
display.

More specific info on methods follows.

=cut

### here we define the canonical source for event names and there numbers.
# %canonical is before we checked in TPerl/Event.csv and invented http://pwikit/cgi-adm/eventview_admin.pl to use it.

# my %canonical = (
# 	UNKNOWN 				 => 0,
# 	DELETE_RECIPIENT         => 15,
# 	PREP_BATCH               => 17,
# 	ADD_RECIPIENT            => 18,
# 	RESET_RECIPIENT          => 19,
# 	SEND_EMAIL               => 20,
# 	SEND_REMINDER            => 21,
# 	SEND_FAX                 => 22,
# 	REJECT_RECIPIENT         => 23,
# 	PREP_REMINDER            => 24,
# 	SEND_BATCH               => 25,
# 	
# 	MAIL_OOO             	=> 26,
# 	FAX_DELIVERY         	=> 27,
# 	MAIL_SERVICE_UNAVAILABLE       =>28,
# 	MAIL_FORWARD            =>29,
# 	MAIL_UNSUBSCRIBE        =>30,
# 	MAIL_SPAM               =>31, 
# 	MAIL_RETURN				=>32,
# 	MAIL_WARNING			=>81,
# 	MAIL_UNDELIVERABLE		=>80,
# 
# 	# This is from the new event scheme.
# 	MAIL_BANNER_READ		=>216,
# 
# 	SURVEY_START             => 33,
# 	SURVEY_SAVE              => 34,
# 	SURVEY_RESUME            => 35,
# 	SURVEY_FINISH            => 36,
# 	SURVEY_TERMINATE         => 37,
# 	FILE_UPLOAD              => 65,
# 	FILE_EXTRA_INFO          => 66,
# 	DB_CREATE_TABLE          => 129,
# 	DB_DROP_TABLE            => 130,
# 	DB_EMPTY_TABLE           => 131,
# 	DB_ALTER_TABLE           => 132,
# );

my %canonical = ();
eval { TPerl::Event->constants() };
if ($@){
	# Pull your socks up
	TPerl::Event->table_manip();
	TPerl::Event->read_from_csv();
}
%canonical = reverse %{TPerl::Event->constants()};	

=head2 new

you have to pass new a dbh or a db parameter.  for long running scripts, its
better to pass both.  The object will try and hang on to the database handle,
but if something happens, then the db param allows us to retry a connection.

See TPerl::MyDB man pages for values of the db parameter.

my $ev = new TPerl::Event (dbh=>$dbh,db=>'ib');

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	foreach (qw (dbh db SID)){
		$self->$_($args{$_});
	}
	# confess "Must supply a dbh or a dbh or a db" unless $args{db} || $args{dbh};
	return $self;
}

# sub SID {my $self = shift; return $self->{SID}=$_[0] if @_;return $self->{SID}}

sub table_create_list {
	return [qw(EVENT_CODES EVENT_VIEW EVENT_VIEW_LINK EVENTLOG)];
}

sub table_sql {
	my $self = shift;
	my $table = shift;
	my $tables = {
		EVENTLOG=>q{
			CREATE TABLE EVENTLOG (
				SID VARCHAR(12) NOT NULL,
				TS INTEGER NOT NULL, 
				EVENT_CODE INTEGER NOT NULL,
				SEVERITY CHAR(1) NOT NULL,
				WHO VARCHAR(10) NOT NULL,
				CAPTION VARCHAR(200),
				BROWSER     VARCHAR(12),
				BROWSER_VER VARCHAR(8),
				OS          VARCHAR(12),
				OS_VER      VARCHAR(8),
				IPADDR      VARCHAR(15),
				PWD         VARCHAR(12),
				EMAIL       VARCHAR(80),
				YR                  INTEGER ,
				MON                 INTEGER ,
				MDAY                INTEGER ,
				HR                  INTEGER ,
				MINS                INTEGER
				) },
		EVENT_CODES => q{
			CREATE TABLE EVENT_CODES (
				EVENT_CODE	INTEGER NOT NULL,
				CONSTANT_NAME VARCHAR(50) NOT NULL UNIQUE,
				EVENT_NAME	VARCHAR(50) NOT NULL UNIQUE,
				DESCRIPTION	VARCHAR(200),
				DEF_SORT_ORDER	INTEGER,
				PRIMARY KEY (EVENT_CODE)
				) },
		EVENT_VIEW=>q{
			CREATE TABLE EVENT_VIEW (
				VIEW_ID		INTEGER NOT NULL,
				VIEW_NAME	VARCHAR(50) NOT NULL  UNIQUE,
				PRIMARY KEY (VIEW_ID)
			) },
		EVENT_VIEW_LINK=>q{
			CREATE TABLE EVENT_VIEW_LINK (
				VIEW_ID		INTEGER	NOT NULL,
				EVENT_CODE	INTEGER	NOT NULL,
				SORT_ORDER	INTEGER		NOT NULL,
				# These foreign keys don't seem to work in interbase.
				FOREIGN KEY (VIEW_ID) REFERENCES EVENT_VIEW(VIEW_ID),
				FOREIGN KEY (EVENT_CODE) REFERENCES EVENT_CODES(EVENT_CODE),
				PRIMARY KEY (VIEW_ID,EVENT_CODE)
				) },
	};
	my $sql = $tables->{$table};
	$sql  =~ s/#.*//g;
	# die "sql=$sql";
	return $sql;
}
sub table_keys {
	my $self = shift;
	return {EVENT_CODES=>['EVENT_CODE'],EVENT_VIEW=>['VIEW_ID'],EVENT_VIEW_LINK=>['VIEW_ID','EVENT_CODE']};
}

sub EVENT_CODES_fields {	
	my $self=shift;
	return $self->ez->fields(table=>'EVENT_CODES');
}
sub EVENT_VIEW_fields {	
	my $self=shift;
	my $f= $self->ez->fields(table=>'EVENT_VIEW');
	$f->{VIEW_ID}->{cgi}->{func} = 'hidden';
	return $f;
}
sub EVENT_VIEW_LINK_fields {	
	my $self=shift;
	my $f= $self->ez->fields(table=>'EVENT_VIEW_LINK');
	$f->{VIEW_ID}->{value_sql}->{sql}= 'select VIEW_ID,VIEW_NAME from EVENT_VIEW';
	$f->{EVENT_CODE}->{value_sql}->{sql}= 'select EVENT_CODE,EVENT_NAME from EVENT_CODES';
	$f->{VIEW_ID}->{cgi}->{func} = 'popup_menu';
	$f->{EVENT_CODE}->{cgi}->{func} = 'popup_menu';
	return $f;
}
sub EVENTLOG_fields {	
	my $self=shift;
	return $self->ez->fields(table=>'EVENTLOG');
}

sub read_from_csv {
	my $self = shift;
	my $dbh = $self->dbh ||return undef;
	my $fn = 'TPerl/Event.csv';
	($self->err("File '$fn' does not exist") && return undef) unless -e $fn;
	my $tsv = new TPerl::TSV(file=>$fn,nocase=>1);
	my $hh = $tsv->header_hash || ($self->err("Could not get 'fn' headers:".$tsv->err) && return undef);

	my $import_heads = [qw(EVENT_CODE CONSTANT_NAME EVENT_NAME DESCRIPTION)];
	{
		my $bad = [];
		foreach my $i (@$import_heads){ push @$bad,$i unless $hh->{$i}; }
		($self->err("Could not find columns '@$bad' in '$fn'") && return undef) if @$bad;
	}
	my $existing = $dbh->selectall_hashref('select * from EVENT_CODES','EVENT_CODE') ||
		($self->err({sql=>'select * from EVENT_CODES',dbh=>$dbh}) && return undef);
	# $self->err($existing) && return undef;
	my $msgs = {};
	push @$import_heads,'DEF_SORT_ORDER';
	my $ins_sql = join '',
		'INSERT INTO EVENT_CODES (',
		join (',',@$import_heads),
		') values (',
		join (',',map '?',@$import_heads),
		')';
	my $ins_sth = $dbh->prepare($ins_sql) || 
		($self->err({sql=>$ins_sql,dbh=>$dbh}) && return undef);
	while (my $r = $tsv->row){
		$r->{DEF_SORT_ORDER} = $tsv->count()*5;
		$r->{$_} =~ s/^\s*(.*?)\s*$/$1/ foreach @$import_heads;
		next if $r->{EVENT_CODE} eq '';
		
		# $self->err($r) && return undef;
		if ($existing->{$r->{EVENT_CODE}}){
			$msgs->{$r->{EVENT_CODE}} = "$r->{EVENT_CODE} $r->{CONSTANT_NAME} $r->{EVENT_NAME} already exists";
		}else{
			$msgs->{$r->{EVENT_CODE}} = "Inserted $r->{EVENT_CODE} $r->{CONSTANT_NAME} $r->{EVENT_NAME}";
			$ins_sth->execute(map $r->{$_},@$import_heads) || ($self->err({sql=>$ins_sql,dbh=>$dbh}) && return undef);
		}
	}
	return $msgs;
}



sub match {
	my $self = shift;
	my $event = uc (shift);
	my @matches = amatch ($event,keys %canonical);
	return \@matches;
}

sub number {
	my $self = shift;
	my $event = uc (shift);
	return $canonical{$event} if exists $canonical{$event};
	my $match = $self->match($event);
	if (scalar (@$match)==1){
		return $canonical{$match->[0]};
	}else{
		return 0;
	}
}

sub delete_view {
	my $self = shift;
	my $view_id = shift;
	confess ("first param must be a view_id") unless $view_id;
	my $dbh = $self->dbh;
	my $tr = new TPerl::TransactionList(dbh=>$dbh);
	$tr->push_item(sql=> 'delete from EVENT_VIEW_LINK where VIEW_ID = ?',
		params=>[$view_id],pretty=>"Delete existing events for view_id=$view_id");
	$tr->push_item(sql=>'delete from EVENT_VIEW where VIEW_ID = ?',
		params=>[$view_id],pretty=>"Delete EVENT_VIEW with id $view_id");
	if ($tr->dbh_do){
		# do whatever you want with it.
		return $tr;
	}else{
		$self->err($tr->msg_summary());
		$self->{delete_view} = $tr;
		return undef;
	}
}

sub view {
	my $self=shift;

	my %args = @_;
	my $SID=$args{SID};
	my $view = $args{name};
	confess "'name' not supplied" unless $view;
	my $dbh = $self->dbh || return undef;

	# There are 2 'magic' views that do not need to be defined in the table.
	# table_only is the set of events that exist in a particular table.  all is
	# everything.
	# The table_only view can have a only_pwd=>'XGAHHHSA' params, that limits to a particular password.
	
	# returns the list of event codes in order.
	
	# Deal with magic view 'all';
	my $all = $self->events || return undef;
	return $all if $view eq 'all';

	# Deal with magic view 'table_only';
	if ($view eq 'table_only'){
		my $table = $self->table_name($SID);
		my $sql = "select distinct(EVENT_CODE) from $table";
		my $params = [];
		if (my $only_pwd = $args{only_pwd}){
			$sql.= ' where PWD=?';
			push @$params,$only_pwd;
		}
		my $h = $dbh->selectall_hashref($sql,'EVENT_CODE',{},@$params) ||
			($self->err({sql=>$sql,dbh=>$dbh,params=>$params}) && return undef);
		my $res = [];
		foreach my $ec (@$all){
			push @$res,$ec if $h->{$ec};
		}
		return $res;
	}

	# Otherwise lookup view in the table.
	my $sql = '
		select EVENT_CODE from EVENT_VIEW,EVENT_VIEW_LINK 
		where EVENT_VIEW.VIEW_ID = EVENT_VIEW_LINK.VIEW_ID
			and upper(VIEW_NAME) = upper(?)
		order by SORT_ORDER
	';
	my $res = $dbh->selectcol_arrayref($sql,{},$view) || 
		($self->err({sql=>$sql,dbh=>$dbh,params=>[$view]}) && return undef);
	($self->err("Either view '$view' does not exist or it has no events associated") &&
		return undef) if @$res == 0;
	return $res;
}

sub table_name {
	my $self=shift;
	my $SID = shift;
	$SID ||= $self->SID if ref($self);
	return $SID.'_E' if $SID;
	return 'EVENTLOG';
}

sub pretty {
	confess "This is no longer used by anything. Just comment this out if i'm wrong";
	my $self = shift;
	my %args = @_;
	my $table_only = $args{table_only};
	my $num = $args{num};
	my $pwd_only = $args{pwd_only};
	my $view = $args{view};

	$view='table_only' if ($table_only);
	$view||='all';

	my $SID=$args{SID} || $self->SID;

	my $found = {};
	if ($table_only){
		my $dbh = $self->dbh || return undef;
		confess "SID required if table_only is on" unless $SID;
		my $params = [];
		my $where;
		if ($pwd_only){
			$where = 'where PWD=?';
			push @$params,$pwd_only;
		}
		my $sql = "select distinct event_code from ${SID}_E $where";
		$found = $dbh->selectall_hashref($sql,'EVENT_CODE',{},@$params) or die "Problem with '$sql':".$dbh->errstr;
		# die Dumper $found;
	}

	my %dict = reverse %canonical;
	my $ret = {};
	foreach my $n (keys %dict){
		my $pretty = join (' ',map ucfirst(lc($_)), split /_/,$dict{$n});
		if ($table_only){
			$ret->{$n} = $pretty if $found->{$n};
		}else{
			$ret->{$n} = $pretty;
		}
	}
	if ($num ne ''){
		my $num = shift;
		return $ret->{$num}
	}else{
		return $ret;
	}
}

sub canonical {
	my $self = shift;
	# Hit the database and 'build' the canonical hash(es).
	# Leave useful bits lying around.
	# This also resets the cache, incase new events are read in.
	my $dbh = $self->dbh;
	my $sql = 'select * from EVENT_CODES order by DEF_SORT_ORDER';
	my $sth = $dbh->prepare($sql) ||
		($self->err({sql=>$sql,dbh=>$dbh}) && return undef);
	$sth->execute() || 
		($self->err({sql=>$sql,dbh=>$dbh}) && return undef);
	my $events = [];
	my $names = {};
	my $constants = {};
	my $descriptions = {};
	my $def_order = {};
	while (my $r = $sth->fetchrow_hashref()){
		push @$events,$r->{EVENT_CODE};
		$names->{$r->{EVENT_CODE}} = $r->{EVENT_NAME};
		$descriptions->{$r->{EVENT_CODE}} = $r->{DESCRIPTION};
		$constants->{$r->{EVENT_CODE}} = $r->{CONSTANT_NAME};
		$def_order->{$r->{EVENT_CODE}} = $r->{DEF_SORT_ORDER};
	}
	if (!@$events){
		$self->err("No events in table (you need read_from_csv)");
		return undef;
	}
	if (my $err = $dbh->errstr){
		$self->err({sql=>$sql,dbh=>$dbh});
		return undef;
	}
	# See AUTOLOAD for the names and internal keys..
	if (ref($self)){
		$self->{events} = $events;
		$self->{names} = $names;
		$self->{constants} = $constants;
		$self->{descriptions} = $descriptions;
		$self->{def_order} = $def_order;
		return 1 ;
	}else{
		return {
			events=>$events,
			names=>$names,
			constants=>$constants,
			descriptions=>$descriptions,
			def_order=>$def_order,
		};
	}
}

sub AUTOLOAD {
	my $self = shift;
	my $type = ref $self;
	my $name = $AUTOLOAD;
	$name =~ s/.*://;
	# print "in AUTOLOAD name=$name\n";
	if (grep $name eq $_,qw(names events constants descriptions def_order)){
		#These are read only functions, set by canonical().
		return $self->{$name} if $type && exists $self->{$name};
		my $vals = $self->canonical() || return undef;
		return $self->{$name} if $type;
		return $vals->{$name};
	}elsif (grep $name eq $_,qw()){
		## read only functions
		return $self->{$name};
	}elsif (grep $name eq $_,qw(db err SID)){
		## rw funcs
		if (ref($self)){
			return $self->{$name} = $_[0] if @_;return $self->{$name};
		}elsif ($_[0]){
			# Lets die if there was no object
			die $_[0];
			# confess "Can't set '$name' with $_[0] without an object";
		}else{
		}
	}elsif (grep $name eq $_,qw(I W E)){
		my %args = ();
		if (scalar(@_)==1){
			$args{msg} = shift;
		}else{
			%args = @_;
		}
		return $self->_event (%args,type=>$name);
	}else{
		croak "Can't access method '$name' of class '$type'";
	}
}

sub dbh {
	my $self = shift;
	if (@_){
		$self->{dbh} = shift;
	}
	return $self->{dbh} if ref($self) eq 'HASH' && $self->{dbh};
	my $db = $self->db;
	my $dbh = dbh TPerl::MyDB (db=>$db,attr=>{RaiseError=>0,PrintError=>0});
	return $dbh if $dbh;
	$self->err("Could not connect to database:".TPerl::MyDB->err);
	return undef;
}

=head2 Error, Warning, Information Events

there are 3 similar methods.  I W and E.  We use named parameters
so you can pass all or none of the optional fields.

the complusory params are 

	 msg

the optional values and their possible default values are 

	 who 	'system'
	 SID 	'EVENTLOG'
	 code 	0
	 pwd 
	 email

for eaxample 

 my $code = $ev->number('Sent Email');
 $ev->I(SID=>'GOSSE123',msg=>"Sent mail to $email",email=>$email, pwd=>$password,code=>$code);
 $ev->I(SID=>'GOOSE123',msg=>'Prepareing batch 23',code=>'prepare batch');

If you pass a numeric code, we don't do any 'expensive' matching lookups, or you can pass 
nice text strings to make your code more readable.

=cut

sub event_view_events {
	my $self = shift;

}

sub _event {
	my $self = shift;
	my %args = @_;
	my $SID = $args{SID};
	my $code = $args{code};

	#programmer help
	foreach (qw(type msg)){
		confess "$_ is required" unless $args{$_};
	}

	unless ($code =~ /^\d+$/){
		$code = $self->number($code);
	}
	my $table = $SID . "_E";
	$table = 'EVENTLOG' unless $SID;

	my $dbh = $self->dbh or return $self->err;
	my $ez = new TPerl::DBEasy;
	return $self->err unless my $fields = $self->fields($SID);
	my $row = {};

	# turn args into the database names.
	my $arg2row = {type=>'SEVERITY', who=>'WHO',msg=>'CAPTION',pwd=>'PWD',SID=>'SID'
		,email=>'EMAIL',epoch=>'TS'};
	foreach (keys %$arg2row){
		$row->{$arg2row->{$_}} = $args{$_} if defined $args{$_};
	}
	$self->epoch2vals (vals=>$row);
	$row->{WHO} ||= $ENV{REMOTE_USER};
	$row->{WHO} ||= 'system';
	$row->{BROWSER} ||= $ENV{HTTP_USER_AGENT};
	$row->{IPADDR} ||= $ENV{REMOTE_ADDR};
	$row->{EVENT_CODE} = $code;
	# print 'fields '.Dumper $fields;
	# confess "here" if $fields eq 'AC101_E';
	$ez->field_force(vals=>$row,fields=>$fields);
	my $ins = $ez->insert(fields=>$fields,table=>$table,vals=>$row);
	# print Dumper $ins;
	$dbh->do ($ins->{sql},{},@{$ins->{params}}) or 
		return Dumper {sql=>$ins->{sql},params=>$ins->{params},err=>$dbh->errstr};
	return undef;
}
sub table {
	die "Move the code from TPerl::Survey\n";
}

sub epoch2vals {
    my $self = shift;
	my $ez = new TPerl::DBEasy;
    my %args = @_;
    my $vals = $args{vals} || {};
    my $epoch = $vals->{TS} || $ez->text2epoch('now');
    my @times = localtime ($epoch);
    $vals->{TS} = $epoch;
    $vals->{MINS} = $times[1];
    $vals->{HR} = $times[2];
    $vals->{MDAY} = $times[3];
    $vals->{MON} = $times[4]+1;
    $vals->{YR} = $times[5]+1900;
 
    return $vals;
}


=head2 fields (SID)

this function provides a DBEasy fields hash, with the pretty names of the
EVENT_CODE filled in.  it also realizes that the TS field is an epoch seconds
field.  See the TPerl::DBEasy man page for more about what DBEasy gets you.

=cut

sub fields {
	my $self = shift;
	my $SID = shift;
	my %args = @_;
	
	# confess "SID is required" unless $SID;

	my $table = $SID . '_E';
	$table = 'EVENTLOG' unless $SID;

	return $self->{fields}->{$table} if ref($self) && $self->{fields}->{$table};
	my $ez = new TPerl::DBEasy;
	my $dbh = $self->dbh || return undef;
	
	my $pretty = $self->names;
	my %custom_info = ();
	$custom_info{TS}=$ez->field(type=>'epoch');
	my @tables = $dbh->tables;
	s/^\W*(.*?)\W$/$1/ foreach @tables;
# Case insensitive for Windowz benefit
	if (grep $table =~ /$_/i,@tables){
		my $fields = $ez->fields(table=>$table,dbh=>$dbh,%custom_info);
		$fields->{EVENT_CODE}->{cgi}->{func} = 'popup_menu';
		$fields->{EVENT_CODE}->{cgi}->{args} = {-values=>[keys %$pretty],-labels=>$pretty};
		$self->{fields}->{$table} = $fields if ref ($self);
		return $fields;
	}else{
		$self->err("No table called '$table'");
		return undef;
	}
}


sub chk_eventlog {
	my $self = shift;
	return $self->table_manip(make=>'EVENT_LOG');
}


# perl -MTPerl::Event -MData::Dumper -e 'my $ev = new TPerl::Event;print Dumper $ev->event_count(SID=>"MAP011",pwd=>"CSNFKHAD");print Dumper $ev->err'
# $VAR1 = {
#           '216' => {
#                      'pretty' => 'Mail Banner Read',
#                      'EVENT_CODE' => 216,
#                      'EV_COUNT' => 2
#                    },
#           '20' => {
#                     'pretty' => 'Send Email',
#                     'EVENT_CODE' => 20,
#                     'EV_COUNT' => 2
#                   }
#         };
sub event_count {
	my $self = shift;
	my %args = @_;
	my $SID = $args{SID};
	my $pwd = $args{pwd};

	my $table = 'EVENTLOG';
	$table = $SID.'_E' if $SID;
	$table = $self->table_name($SID);

	my $params = [];
	my $where = '';
	if ($pwd){
		$where = ' WHERE PWD=? ';
		push @$params,$pwd;
	}
	my $sql = "select EVENT_CODE,count(EVENT_CODE) as EV_COUNT from $table $where group by EVENT_CODE";
	my $dbh = $self->dbh;
	if (my $res = $dbh->selectall_hashref($sql,'EVENT_CODE',{},@$params)){
		my $pretty = $self->names;
		$res->{$_}->{pretty} = $pretty->{$_} foreach keys %$res;
		return $res;
	}else{
		$self->err({sql=>$sql,params=>$params,errstr=>$dbh->errstr});
		return undef;
	}
}

sub eventlog_bits {
	# So you want an event log in your page?
	# don't we all....
	# This does not do ANY html production.  
	# Just returns the things you need to use.
	
	my $self = shift;

	my $dbh=$self->dbh || return undef;
	my %args = @_;

	my $defaults = {
		# Names of the bits in the form
		events_name=>'events',
		pwd_name=>'PWD',
		sid_name=>'SID',

		# fields to get rid of
		delete_fields=>[qw(BROWSER BROWSER_VER OS OS_VER IPADDR YR MON MDAY HR MINS SID TP)],
	};
	my $config = $args{_config} || {};
	foreach (keys %$defaults){ $config->{$_} = $defaults->{$_} unless exists $config->{$_}; }

	# work begins.
	my $SID = $args{$config->{sid_name}} || ($self->err("No SID supplied") && return undef);
	my $pwd = $args{$config->{pwd_name}};
	my $events = $args{$config->{events_name}};

	# build the sql;
	my $params = [];
	my $where = "EVENT_CODE=$events" if $events ne '';
	$where = join ' OR ', map "EVENT_CODE=$_" ,@$events if ref $events eq 'ARRAY';
	if ($pwd){
		if ($where){
			$where = "($where) and (PWD=?)";
		}else{
			$where = "PWD=?";
		}
		push @$params,$pwd;
	}
	$where = "where $where" if $where;
	my $sql = "select * from ${SID}_E $where order by TS desc ";


	#Change the heading of the Customise box.
	my $lbtitle = 'Limit Events';
	$lbtitle .= " for Password '$pwd'" if $pwd;

	# Do the fields. 
	my $fields = $self->fields($SID);
	delete $fields->{$_} foreach @{$config->{delete_fields}};


	my $states = {$config->{sid_name}=>$args{$config->{sid_name}}};
	$states->{$config->{pwd_name}} = $args{$config->{pwd_name}} if $args{$config->{pwd_name}} ne '';
	$states->{$config->{events_name}} = $args{$config->{events_name}} if $args{$config->{events_name}} ne '';


	my $pwds = $self->pwd_list(SID=>$SID) || return undef;
	unshift @$pwds,'';
	
	return {
		SID=>$SID,
		pwd=>$pwd,
		sql=>$sql,
		params=>$params,
		delete_fields=>$config->{delete_fields},
		state=>$states,
		event_args=>{
			-name=>$config->{events_name},
			-values=>$self->view(SID=>$SID,name=>'table_only',only_pwd=>$pwd),
			-labels=>$self->names(),
			-defaults=>$args{$config->{events_name}},
		},
		title=>$lbtitle,
		fields=>$fields,
		pwd_name=>$config->{pwd_name},
		sid_name=>$config->{sid_name},
		events_name=>$config->{events_name},
		pwd_args=>{
			-name=>$config->{pwd_name},
			-values=>$pwds,
			-default=>$pwd,
			-labels=>{''=>'Any Password'},
		},
	};

}

sub pwd_list {
	# hit the database for a list of unique passwords.
	my $self = shift;
	my $dbh = $self->dbh || return undef;
	my %args = @_;
	my $SID=$args{SID} || $self->SID;
	
	my $table = 'EVENT_LOG';
	$table = "${SID}_E" if $SID;
	my $sql = "select distinct(PWD) as PWD from $table";
	if (my $list = $dbh->selectcol_arrayref($sql)){
		@$list = grep $_,@$list;
		return $list;
	}else{
		$self->err({sql=>$sql,dbh=>$dbh,errstr=>$dbh->errstr});
		return undef;
	}
}

sub DESTROY{
}
1;
