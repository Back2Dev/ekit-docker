#!/usr/bin/perl
#$Id: aspadmin.pl,v 1.20 2006-03-01 02:58:08 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::LookFeel;
use TPerl::Dump;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::DBEasy;
use TPerl::TritonConfig;
use Data::Dump qw(dump);
use Data::Dumper;

my $q = new TPerl::CGI;
my $lf = new TPerl::LookFeel;

my $sulist = [qw(ac mikkel)];
my $uid = $ENV{REMOTE_USER};

my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $ez = new TPerl::DBEasy (dbh=>$dbh);

sub pretty_table_list {
	my $list = shift;
	my $title = shift || 'Choose a table';
	
	my $out = join ' | ',map qq{<A href="$ENV{SCRIPT_NAME}?table=$_">$_</A>},@$list;
	return join "\n",
		$lf->sbox($title),
		$out,
		$lf->ebox;
}

#### First check that we are an SU
unless (grep $uid eq $_,@$sulist){
	print join "\n",
		$q->header,
		$q->start_html(-title=>"Error",-style=>{src=>'style.css'}),
		$q->err("You are not a superuser"),
		$q->end_html;
	exit;
}

my $tablekeys = {
	CLIENT=>['CLID'],
	VHOST=>['VID'],
	CONTRACT=>['COID'],
	TUSER=>['UID'],
	VACCESS=>[qw(UID VID)],
	JOB=>['SID'],
	EMAIL_WORK=>['EWID'],
	BATCH=>['SID','BID'],
};

my %args = $q->args;
my $table=$args{table} || 'JOB';
my $new= $args{new};
my $delete = $args{delete};
my $edit = $args{edit};

my $fields;
my $new_button_tables = [qw(CLIENT VHOST CONTRACT TUSER VACCESS)];
if ($table){
	if ($table eq 'EMAIL_WORK'){
		# my $targs = {hide=>['SID']} unless $new;
		my $targs = {};
		$fields=$asp->email_work_fields(%$targs);
	}elsif ($table eq 'BATCH'){
		$fields=$asp->batch_fields();
		$fields->{BID}->{cgi}->{func} = 'textfield';
		$fields->{SID}->{cgi}->{func} = 'textfield';
	}else{
		my %cust = ();
		if( $table eq 'VACCESS' ){
			$cust{$_} = $ez->field (type=>'yesno') foreach qw(J_READ J_CREATE J_DELETE J_USE);
		}
		$fields = $ez->fields(table=>$table,%cust);
		unless ($table eq 'JOB' and !$edit){
			$fields->{$_}->{cgi}->{func} = 'hidden' foreach @{$tablekeys->{$table}};
		}
		if ($table eq 'TUSER'){
			$fields->{UID}->{cgi}->{func}='textfield';
			$fields->{PWD}->{cgi}->{func}='password_field';
			$fields->{CLID}->{cgi}->{func}='popup_menu';
			$fields->{CLID}->{value_sql}->{sql} = 'select CLID,CLNAME from CLIENT';
			delete $fields->{PWD} unless $new || $edit || $delete;
		}elsif ($table eq 'CONTRACT'){
			$fields->{CLID}->{cgi}->{func}='popup_menu';
			$fields->{CLID}->{value_sql}->{sql} = 'select CLID,CLNAME from CLIENT';
			$fields->{VID}->{cgi}->{func}='popup_menu';
			$fields->{VID}->{value_sql}->{sql} = 'select VID,VDOMAIN from VHOST';
		}elsif ($table eq 'VACCESS'){
			$fields->{UID}->{cgi}->{func}='popup_menu';
			$fields->{UID}->{value_sql}->{sql} = 'select UID,UID from TUSER';
			$fields->{VID}->{cgi}->{func}='popup_menu';
			$fields->{VID}->{value_sql}->{sql} = 'select VID,VDOMAIN from VHOST';
		}elsif ($table eq 'JOB'){
			$fields->{VID}->{cgi}->{func}='popup_menu';
			$fields->{VID}->{value_sql}->{sql} = 'select VID,VDOMAIN from VHOST';
		}
	}
}
# print $q->header;

my $state = [qw(table)];

my $filter_box;
my ($list_sql,$list_params);
if (grep $table eq $_,qw(BATCH EMAIL_WORK)){
	my $sql = "select distinct(SID) from $table";
	my $res = $dbh->selectall_hashref($sql,'SID');
	# $q->mydie($res);
	$q->mydie({sql=>$sql,dbh=>$dbh}) unless $res;
	my $SIDS = [keys %$res];
	my $filter_SID = $args{filter_SID} || [];
	$filter_SID = [$filter_SID] unless ref $filter_SID eq 'ARRAY';
	if (@$SIDS and !$edit and !$new and !$delete){
		$filter_box = join "\n",
			$lf->sbox("Filter by SID"),
			$q->start_form(),
			# $q->checkbox_group(-name=>'filter_SID',-override=>1,-defaults=>$filter_SID,-values=>$SIDS),
			$q->tradio_group(-name=>'filter_SID',-override=>1,-default=>$filter_SID->[0],-values=>$SIDS),
			map ($q->hidden(-name=>$_,-value=>$args{$_}),  @$state),
			$q->submit(-value=>'Limit'),
			$lf->ebox;
		push @$state,'filter_SID';
	}
	if (@$filter_SID){
		my $order= " order by $_ DESC " if $_=join ',',@{$tablekeys->{$table}};
		$list_sql = "select * from $table where ".join (' OR ',map ("SID=?",@$filter_SID)). $order;
		$list_params = $filter_SID;
	}
}

my $limit = 15;
my $list_form = 1;
my ($list_edit,$list_delete)=(1,1);

if ($table eq 'VACCESS_NEEDS_WORK' and !$new and !$edit){
	$limit=5;
	$list_form=2;  # Put a form around the list as well as do the page stuff.
	my $updateable = [qw(J_READ J_CREATE J_DELETE J_USE VID)];

	### This bit handles the updates
	my $poss_updates = {};
	# my $e = new TPerl::Error(noSTDOUT=>1);
	foreach my $a (keys %args){
		if (my ($type,$f,$id) = $a =~/^(new|old)_(\w+?)___(.*)$/){
			$poss_updates->{$id}->{$f}->{$type} = $args{$a};
		}
	}
	foreach my $id (keys %$poss_updates){
		my $update_fields = {};
		my $vals = {};
		foreach my $f (@$updateable){
			if ($poss_updates->{$id}->{$f}->{old} ne $poss_updates->{$id}->{$f}->{new}){
				$update_fields->{$f} = $fields->{$f};
				$vals->{$f} = $poss_updates->{$id}->{$f}->{new};
			}
		}
		#$e->I($poss_updates);
		if (%$update_fields){
			my $keys = [];
			foreach my $pair ( split /__/,$id){
				my ($k,$v) = $pair =~ /^(.*?)=(.*)$/;
				$update_fields->{$k} = $fields->{$k};
				$vals->{$k} = $v;
				push @$keys,$k;
			}
			my $errs = [];
			if (my $err = $ez->row_manip(action=>'update',fields=>$update_fields,keys=>$keys,vals=>$vals,table=>$table)){
				push @$errs,$err;
			}else{
				#$e->D("updated ".Dumper( {action=>'update',fields=>$update_fields,keys=>$keys,vals=>$vals}));
			}
			$q->mydie($errs) if @$errs;
		}
	}


	### This bit prepares for the form editing.
	#We need each editable bit to have a unique name.  We also need to have the original 
	#values so we don;t hit the database when people are just paging through.
	my $keys = $tablekeys->{VACCESS};
	foreach my $f (@$updateable){
		my $fmt = "${f}___".join '__',map "$_=%s",@$keys;
		$fields->{$f}->{form_name} = {sprintf =>{fmt=>"new_$fmt",names=>$keys}};
		$fields->{$f}->{form} = 1;
 		$fields->{"orig_$f"}->{form} = 1;
 		$fields->{"orig_$f"}->{form_name} = {sprintf =>{fmt=>"old_$fmt",names=>$keys}};
		$fields->{"orig_$f"}->{sprintf} = {fmt=>'%s',names=>[$f]};
		$fields->{"orig_$f"}->{cgi}->{func}='hidden';
	}
}

my $res = $ez->edit(
	new_buttons=>$new_button_tables,
	table=>$table,
	_obj=>$asp,
	_list_sql=>$list_sql,
	_list_params=>$list_params,
	_list_limit=>$limit,
	_list_form=>$list_form,
	_list_edit=>$list_edit,
	_list_del=>$list_delete,
	_state=>$state,
	_new_buttons=>$new_button_tables,
	_tablekeys=>$tablekeys,
	_fields=>$fields,
	%args
);

$q->mydie($res->{err}) if $res->{err};
my $update_htaccess = join "\n",
	$q->start_form(-action=>'aspupdate_htaccess.pl',-method=>'POST'),
	$q->submit(-name=>'submit',-value=>'Update HTACCESS'),
	$q->end_form if $table eq 'TUSER';


print join "\n",
	$q->header,
	$q->start_html (-title=>'ASP admin',-style=>{src=>'/admin/style.css'}),
	$res->{html},
	$filter_box,
	$update_htaccess,
	pretty_table_list($asp->table_create_list),
	# $q->dumper(\%args),
	# $q->dumper($fields),
	$q->end_html;


