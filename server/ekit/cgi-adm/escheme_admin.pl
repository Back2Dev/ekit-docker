#!/usr/bin/perl
#$Id: escheme_admin.pl,v 1.5 2007-06-12 23:44:30 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::EScheme;
use TPerl::LookFeel;


my $q = new TPerl::CGI;
my $sulist = [qw(ac mikkel)];
my %args = $q->args();
my $SID = $args{SID};
my $eso = new TPerl::EScheme();
my $tables = $eso->table_create_list;
$args{table} ||=$tables->[0];

my $ez = new TPerl::DBEasy (dbh=>$eso->dbh);
my $state = [qw(table)] ;
my $tablekeys = $eso->table_keys;
my $fields_function_name = "$args{table}_fields";
my $fields = $eso->$fields_function_name;

my $new = $args{new};
my $edit = $args{edit};
my $delete = $args{delete};

my $lf = new TPerl::LookFeel;

if (my $es_id = $args{cd_es}){
	if ($eso->cascade_delete(scheme_id=>$es_id)){
 		print $q->redirect($ENV{SCRIPT_NAME});
 		exit;
	}else{
		$q->mydie($eso->err);
	}
}
if (my $es_id = $args{cd_ess}){
	if ($eso->cascade_delete(scheme_id=>$es_id,tear_off=>1)){
 		print $q->redirect("$ENV{SCRIPT_NAME}?table=EMAIL_SCHEME_STATUS");
 		exit;
	}else{
		$q->mydie($eso->err);
	}
}

# Filter by SID.
my ($filter_box,$list_sql,$list_params);

if (!$new && !$edit && !$delete){
	if ($args{table} eq 'EMAIL_SCHEME'){
		$fields->{CASCADE_DELETE} = {sprintf=>{
			fmt=>qq{<a href="$ENV{SCRIPT_NAME}?cd_es=%s">Cascade delete %s</a>},
			names=>['EMAIL_SCHEME_ID','EMAIL_SCHEME_ID']}};
		$fields->{EDIT_SCHEME} = {sprintf=>{
			fmt=>qq{<a target="_blank" href="escheme_edit.pl?EMAIL_SCHEME_ID=%s">edit scheme</a},
			names=>['EMAIL_SCHEME_ID']}};
	}
	if ($args{table} eq 'EMAIL_SCHEME_STATUS'){
		$fields->{CASCADE_DELETE} = {sprintf=>{
			fmt=>qq{<a href="$ENV{SCRIPT_NAME}?cd_ess=%s">Cascade delete %s</a>},
			names=>['EMAIL_SCHEME_STATUS_ID','EMAIL_SCHEME_STATUS_ID']}};
		$fields->{EDIT_SCHEME} = {sprintf=>{
			fmt=>qq{<a target="_blank" href="escheme_status.pl?EMAIL_SCHEME_STATUS_ID=%s">Scheme Status</a},
			names=>['EMAIL_SCHEME_STATUS_ID']}};
	}
	if (grep $_ eq $args{table},qw(EMAIL_SCHEME_STATUS EMAIL_SCHEME)){
		my $sql = "select distinct(SID) from $args{table}";
		my $SIDS = $eso->dbh->selectcol_arrayref($sql)||$q->my_die({sql=>$sql,dbh=>$eso->dbh});
		my $filter_SID = $args{filter_SID} || [];
		$filter_SID = [$filter_SID] unless ref $filter_SID eq 'ARRAY';
		if (@$SIDS){
			$filter_box = join "\n",
				$lf->sbox("Filter by SID"),
				$q->start_form(),
				$q->tradio_group(-name=>'filter_SID',-override=>1,-default=>$filter_SID->[0],-values=>$SIDS,
					-onClick=>q{this.form.submit();}),
				map ($q->hidden(-name=>$_,-value=>$args{$_}),  @$state),
				$lf->ebox,
				'<br>';
		}
		if (@$filter_SID){
			my $table = $args{table};
			my $order= " order by $_ DESC " if $_=join ',',@{$tablekeys->{$table}};
			$list_sql = "select * from $table where ".join (' OR ',map ("SID=?",@$filter_SID)). $order;
			$list_params = $filter_SID;
		}
	}
}

$fields->{EMAIL_SCHEME_ID}->{pretty} = 'Torn from scheme' if $args{table} eq 'EMAIL_SCHEME_STATUS';

my ($list_edit,$list_del) = (1,1);
$list_del = 0 if grep $args{table} eq $_,qw(EMAIL_SCHEME_STATUS EMAIL_SCHEME);

my $res = $ez->edit(_obj=>$eso,_new_buttons=>$tables,
	_fields=>$fields,
	_list_sql=>$list_sql,
	_list_params=>$list_params,
	_list_del=>$list_del,
	_list_edit=>$list_edit,
	_tablekeys=>$tablekeys,
	_state=>$state,%args);


if ($res->{err}){
	$q->mydie ($res->{err});
}else{
	print join "\n",
		$q->header,
		$q->start_html(-title=>$0,-style=>{src=>"/admin/style.css"},-class=>'body'),
		$res->{html},
		$filter_box,
		join (' | ',map qq{<a href="$ENV{SCRIPT_NAME}?table=$_">$_</a>},@$tables),
		# $q->dumper($fields),
		# $q->dumper(\%args),
		# $q->dumper(\%ENV),
		$q->end_html;
}

