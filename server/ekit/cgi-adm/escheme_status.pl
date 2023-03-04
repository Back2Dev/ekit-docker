#!/usr/bin/perl
use strict;
use CGI::Carp qw (fatalsToBrowser);
use TPerl::CGI;
use TPerl::LookFeel;
use TPerl::EScheme;
use TPerl::Error;
use FileHandle;
use Data::Dumper;
use TPerl::Engine;

# Some stuff we need.
my $q = new TPerl::CGI;
my %args = $q->args;
my $eso = new TPerl::EScheme; # $eso = email_scheme_object.
my $lf = new TPerl::LookFeel;
my $e = new TPerl::Error (noSTDOUT=>1);

my $dbh = $eso->dbh;
my $ez = new TPerl::DBEasy(dbh=>$dbh);

my $ess_fields = $eso->EMAIL_SCHEME_STATUS_fields;
my $ets_fields = $eso->EMAIL_TRACK_STATUS_fields;
my $ems_fields = $eso->EMAIL_MSG_STATUS_fields;

my $t_keys = $eso->table_keys;

$args{EMAIL_SCHEME_STATUS_ID} ||='';

# Now some database edits.
if ($args{EMAIL_TRACK_STATUS_ID}){
	my $upf = {};
	foreach my $f (keys %$ets_fields){
		$upf->{$f} = $ets_fields->{$f} if exists $args{$f};
	}
	if (my $err = $ez->row_manip(table=>'EMAIL_TRACK_STATUS',action=>'update',fields=>$upf,vals=>\%args,keys=>$t_keys)){
		$q->mydie($err);
	}
}
if (exists $args{SCHEME_ACTIVE_FLAG}){
	my $upf={};
	foreach my $f (keys %$ess_fields){
		$upf->{$f} = $ess_fields->{$f} if exists $args{$f};
	}
	if (my $err = $ez->row_manip(table=>'EMAIL_SCHEME_STATUS',action=>'update',fields=>$upf,vals=>\%args,keys=>$t_keys)){
		$q->mydie($err);
	}
}


## Then we display stuff.
#
my $title = 'Email Scheme Status Viewer';

$ets_fields->{TRACK_READ_FLAG}->{pretty} = 'Read';
$ets_fields->{TRACK_STOP_FLAG}->{pretty} = 'Stopped';
$ets_fields->{TRACK_HOLD_FLAG}->{pretty} = 'On hold';

$ems_fields->{EMAIL_TRACK_STATUS_ID}->{cgi}->{func} = 'hidden';
$ems_fields->{CREATED_EPOCH}->{cgi}->{func} = 'hidden';
$ets_fields->{CREATED_EPOCH}->{cgi}->{func} = 'hidden';
$ess_fields->{EMAIL_SCHEME_ID}->{cgi}->{func} = 'hidden';
$ems_fields->{EMAIL_MSG_STATUS_ID}->{cgi}->{func} = 'texfield';


my $ess_sql = 'select * from EMAIL_SCHEME_STATUS where EMAIL_SCHEME_STATUS_ID=?';
my $ess_rows = $dbh->selectall_arrayref($ess_sql,{Slice=>{}},$args{EMAIL_SCHEME_STATUS_ID}) || 
	$q->mydie({sql=>$ess_sql,dbh=>$dbh,params=>[$args{EMAIL_SCHEME_STATUS_ID}]});

### Bit to put the scheme active form in the top box.
$ess_fields->{SCHEME_ACTIVE_FLAG}->{code} = {
	ref=>sub{
		my $scf = shift;
		my $id = shift;
		my $q = new TPerl::CGI('');
		my $confirm_js = qq/if (confirm ('Really change $ess_fields->{SCHEME_ACTIVE_FLAG}->{pretty} status now')){this.form.submit()}else{this.form.reset()}/;
		return join "\n",
			$q->start_form(),
			$q->popup_menu(-name=>'SCHEME_ACTIVE_FLAG',-defaults=>$scf,-values=>[0,1],-labels=>{0=>'No',1=>'Yes',label=>'Goose'},-onChange=>$confirm_js),
			$q->hidden(-name=>'EMAIL_SCHEME_STATUS_ID',-default=>$id),
			$q->end_form;
		},
	names=>[qw(SCHEME_ACTIVE_FLAG EMAIL_SCHEME_STATUS_ID)]
};

my ($search_box,$search_result);

{
	#search results
	if ($args{search}){
		my $fields = {};
		my $s_qs = join '&',map "$_=$args{$_}" ,qw /search_PWD search_SID/;
		$fields->{EDIT_SCHEME} = {
			sprintf=>{  fmt=>qq{<a href="$ENV{SCRIPT_NAME}?EMAIL_SCHEME_STATUS_ID=%s&$s_qs">Scheme Status</a},
						names=>['EMAIL_SCHEME_STATUS_ID']},
			order=>-1,
		};
		$fields->{$_} = $ess_fields->{$_} foreach keys %$ess_fields;
		my $wheres = [];
		my $params = [];
		if ($args{search_PWD}){
			# No spaces for mysql
			push @$wheres, "upper(PWD) like upper(?)";
			push @$params,"%$args{search_PWD}%";
		}
		if ($args{search_SID}){
			push @$wheres, "upper (SID) like upper(?)";
			push @$params,"%$args{search_SID}%";
		}
		my $sql = "select * from EMAIL_SCHEME_STATUS";
		$sql .= ' WHERE '.join (" AND ",@$wheres) if @$wheres;
		my $state = {};
		$state->{$_} = $args{$_} foreach qw /search_PWD search_SID search/;
		$search_result = $ez->lister_wrap(sql=>$sql,params=>$params,look=>$lf,fields=>$fields,form=>1,form_hidden=>$state,%args)|| $q->err($ez->err);
	}

	#Search box
	my $search_sid_list = TPerl::Engine->SID_list;
	unshift @$search_sid_list,'';
	$search_box = join "\n",
		$q->start_form(-method=>'POST',-action=>$ENV{SCRIPT_NAME}),
		'Search for emails<br>',
		'Password',
		$q->textfield(-name=>'search_PWD'),
		'<br>',
		'Job',
		$q->popup_menu(-name=>'search_SID',-values=>$search_sid_list,-labels=>{''=>'Any'}),
		'<br>',
		$q->submit(-value=>'Search',-name=>'search'),
		$q->hidden(-name=>'EMAIL_SCHEME_STATUS_ID',-value=>$args{EMAIL_SCHEME_STATUS_ID},-override),
		$q->endform;
}


print join "\n",
	$q->header,
	$q->start_html(-style=>{src=>"/admin/style.css"},-title=>$title),
	'<table><tr><td>',
	$lf->srbox($title. " $args{EMAIL_SCHEME_STATUS_ID}"),
	$ez->lister_wrap(_no_data=>'None Found',rows=>$ess_rows,look=>$lf,fields=>$ess_fields,_row_count=>' ',heads_in_trow=>1),
	$lf->erbox,
	'</td><td>',
	'&nbsp;',
	'</td><td>',
	$search_box,
	'</td><td>',
	$search_result,
	'</td></tr></table>',
	'<hr>';

## Now we want to step through any tracks.
$ets_fields->{TRACK_HOLD_FLAG}->{cgi}->{args}->{-onChange} = qq/if (confirm ('Really change $ets_fields->{TRACK_HOLD_FLAG}->{pretty} status now')){this.form.submit()}else{this.form.reset()}/;
my $ets_rows = [];
if ($ess_rows->[0]->{EMAIL_SCHEME_ID}){
	my $ets_sql = 'select * from EMAIL_TRACK_STATUS where EMAIL_SCHEME_STATUS_ID=? order by TRACK_INTERVAL';
	$ets_rows = $dbh->selectall_arrayref($ets_sql,{Slice=>{}},$ess_rows->[0]->{EMAIL_SCHEME_STATUS_ID}) ||
    	$q->mydie({sql=>$ets_sql,dbh=>$dbh,params=>[$ets_rows->[0]->{EMAIL_SCHEME_STATUS_ID}]});
	foreach my $ets_row (@$ets_rows){
		my $ems_sql = 'select * from EMAIL_MSG_STATUS where EMAIL_TRACK_STATUS_ID = ? order by START_EPOCH';
		my $ems_params = [$ets_row->{EMAIL_TRACK_STATUS_ID}];
		my $track_header = join "\n",
			$q->start_form(),
			map ($ets_fields->{$_}->{pretty} .':'.$ez->field2val(field=>$ets_fields->{$_},row=>$ets_row). '&nbsp;&nbsp;&nbsp;',
				qw (TRACK_STATUS_NAME TRACK_READ_FLAG TRACK_STOP_FLAG)),
			$ez->field2val(form=>1,field=>$ets_fields->{EMAIL_TRACK_STATUS_ID},row=>$ets_row),
			$q->hidden(-name=>'EMAIL_SCHEME_STATUS_ID',-value=>$args{EMAIL_SCHEME_STATUS_ID},-override=>1),
			map ($ets_fields->{$_}->{pretty} .':'.$ez->field2val(form=>1,field=>$ets_fields->{$_},row=>$ets_row),
				qw(TRACK_HOLD_FLAG)),
			# $q->submit(-value=>'Change'),
			$q->end_form()
			;
		print join "\n",
			# $q->dumper($ets_row),
			$lf->srbox($track_header),
			# $lf->srbox($ez->lister_wrap(rows=>[$ets_row],look=>$lf,fields=>$ets_fields,_row_count=>' ')),
			($ez->lister_wrap(_no_data=>'No Messages in this track',sql=>$ems_sql,params=>$ems_params,fields=>$ems_fields,look=>$lf,_row_count=>' ',heads_in_trow=>1)
				|| $q->dumper($ez->err())),
			$lf->erbox(),
			'<br>',
			;
	}
}

print join "\n",
	# $q->dumper(\%args),
	# $q->dumper($ess_rows),
	# $q->dumper($ems_fields),
	$q->end_html;
