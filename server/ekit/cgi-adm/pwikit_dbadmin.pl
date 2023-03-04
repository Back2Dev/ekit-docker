#!/usr/bin/perl
#$Id: pwikit_dbadmin.pl,v 1.3 2007-09-10 10:03:49 triton Exp $
# 
# Kwik script to manage PWIKit workshops, locations etc
#
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::LookFeel;
use TPerl::Dump;
use TPerl::ASP;
use TPerl::DBEasy;
use Data::Dump qw(dump);

my $q = new TPerl::CGI;
my $lf = new TPerl::LookFeel;

my $sulist = [qw(ac mikkel)];
my $uid = $ENV{REMOTE_USER};
my $stylesheet = '/pwikit/style.css';

# my $db = getro TPerl::Dump 'dbname.pl' or die "$@ $!";
my $db = 'pwikit';
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
# my $asp = new TPerl::ASP(dbh=>$dbh);
my $ez = new TPerl::DBEasy (dbh=>$dbh);

my %table_names = (
				PWI_EXEC => 'Staff Executive',
				PWI_ADMIN  => 'Administrator',
				PWI_WORKSHOP  => 'Workshop',
				PWI_LOCATION => 'Location',
				PWI_BATCH => 'Batch',
				);
				
sub pretty_table_list {
	my $list = shift;
	my $title = shift || 'Choose a table';
	
	my $out = join ' | ',map qq{<A href="$ENV{SCRIPT_NAME}?table=$_">$table_names{$_}</A>},@$list;
	return join "\n",
		$lf->sbox($title),
		$out,
		$lf->ebox;
}

#### First check that we are an SU
if (0){unless (grep $uid eq $_,@$sulist){
	print join "\n",
		$q->header,
		$q->start_html(-title=>"Error",-style=>{src=>$stylesheet}),
		$q->err("You are not a superuser"),
		$q->end_html;
	exit;
}}

my $tablekeys = {
	PWI_BATCH=>['BAT_KV'],
	PWI_ADMIN=>['ADMIN_KV'],
	PWI_EXEC=>['EXEC_KV'],
	PWI_WORKSHOP=>['WS_KV'],
	PWI_LOCATION=>['LOC_KV'],
};

my $tablesort = {
	PWI_BATCH=>['BAT_NO'],
	PWI_ADMIN=>['ADMIN_NAME'],
	PWI_EXEC=>['EXEC_NAME'],
	PWI_WORKSHOP=>['WS_ID'],
	PWI_LOCATION=>['LOC_ID'],
};

my %args = $q->args;

# my $table=$args{table} || 'MAP_CASES';
my $table=$args{table} || 'PWI_WORKSHOP';
my $new= $args{new};
my $delete = $args{delete};
my $edit = $args{edit};

my $fields;
my $new_button_tables = [qw(PWI_EXEC PWI_ADMIN PWI_BATCH PWI_WORKSHOP PWI_LOCATION)];
if ($table){
# print $q->header;
		my %cust = ();
		$fields = $ez->fields(table=>$table,%cust);
		$fields->{$_}->{cgi}->{func} = 'hidden' foreach @{$tablekeys->{$table}};
		if ($table eq 'PWI_WORKSHOP'){
		    $fields->{WS_LOCREF}->{cgi}->{func}='popup_menu';
            $fields->{WS_LOCREF}->{value_sql}->{sql} = 'select LOC_KV,LOC_CODE from PWI_LOCATION ORDER BY LOC_ID';
		    $fields->{WS_STATUSREF}->{cgi}->{func}='popup_menu';
            $fields->{WS_STATUSREF}->{value_sql}->{sql} = 'select WSS_KV,WSS_STATUS from PWI_WSSTATUS';
            $fields->{WS_ID}->{pretty} = 'ID';
            $fields->{WS_STATUSREF}->{pretty} = 'Status';
            $fields->{WS_LOCREF}->{pretty} = 'Location';
            $fields->{WS_STARTDATE}->{pretty} = 'Start Date';
            $fields->{WS_DUEDATE}->{pretty} = 'Due Date';
            $fields->{WS_REMDATE1}->{pretty} = 'Reminder 1';
            $fields->{WS_REMDATE2}->{pretty} = 'Reminder 2';
		}elsif ($table eq 'PWI_BATCH'){
            $fields->{BAT_NO}->{pretty} = 'Number';
            $fields->{BAT_STATUS}->{pretty} = 'Status';
#			$fields->{BAT_NAME}->{cgi}->{func} = 'hidden';
#            $fields->{BAT_NAME}->{pretty} = 'Batch name';
			$fields->{BAT_STATUS}->{cgi}->{func}='radio_group';
            $fields->{BAT_STATUS}->{value_sql}->{sql} = 'select WSS_KV,WSS_STATUS from PWI_WSSTATUS';
		}elsif ($table eq 'PWI_LOCATION'){
			$fields->{LOC_ID}->{pretty} = "ID";
			$fields->{LOC_NAME}->{pretty} = "Short name";
			$fields->{LOC_DISPLAY}->{pretty} = "Long name";
			$fields->{LOC_ACTIVE}->{pretty} = "Active";
			$fields->{LOC_FAX}->{pretty} = "Fax No";
#			$fields->{UID}->{cgi}->{func}='textfield';
#			$fields->{PWD}->{cgi}->{func}='password_field';
#			$fields->{CLID}->{cgi}->{func}='popup_menu';
#			$fields->{CLID}->{value_sql}->{sql} = 'select CLID,CLNAME from CLIENT';
		}elsif ($table eq 'PWI_WSDATES'){
			$fields->{WSDATE}->{cgi}->{func} = '';
		}
	}

# print $q->header,$q->dumper($fields);

if ($table && $edit==2){
	## Commit the edit or display validation/ database errors
	my $keys = $tablekeys->{$table};
	if (my $err = $ez->row_manip (dbh=>$dbh,action=>'update',table=>$table,vals=>\%args,fields=>$fields,keys=>$keys)){
		my $title;
		my $stuff;
		if (my $v = $err->{validate}){
			$stuff = $ez->form(fields=>$fields,table=>$table,new=>2,row=>\%args,valid=>$v);
			$title  = 'Please fix these errors';
		}else{
			$stuff = $q->dberr(dbh=>$dbh,sql=>$err->{sql});
		}
		print join "\n",
			$q->header,
			$q->start_html(-title=>$title,-style=>{src=>'/style/style.css'}),
			$stuff,
			$q->end_html;
	}else{
		print $q->redirect("$ENV{SCRIPT_NAME}?table=$table");
	}
}elsif ($table && $edit==1){
	# shpw the edit form
	my $title = "Edit $table_names{$table}";
	my $sql = "select * from $table where ";
	my @where = ();my @params = ();
	foreach my $k (@{$tablekeys->{$table}}){
		push @where, " $k=? ";
		push @params, $args{$k};
	}
	$sql .= join 'AND',@where;
	my $attr = $ez->sa_ar_slice();
	if (my $res = $dbh->selectall_arrayref($sql,$attr,@params)){
	# print $q->header()."vers = $DBI::VERSION res <PRE>".dump ($res).'</PRE>';
		print join "\n",
			$q->header,
			$q->start_html(-title=>$title,-style=>{src=>$stylesheet}),
			qq{<P class="heading">&nbsp;<BR>&nbsp;$title<BR>&nbsp;</P>},
			$ez->form(fields=>$fields,table=>$table,edit=>2,row=>$res->[0]),
			'<BR>',
			pretty_table_list([qw{PWI_EXEC PWI_ADMIN PWI_BATCH PWI_WORKSHOP PWI_LOCATION}]),
			$q->end_html;
	}else{
		die "db error getting row";
	}
}elsif ($table && $delete==1){
	## just do the delete.  sometimes i have a delete=2 to really delete and delete=1 means ask for comfirmation
	my $keys = $tablekeys->{$table};
	if (my $err = $ez->row_manip(dbh=>$dbh,keys=>$keys,vals=>\%args,table=>$table,action=>'delete',fields=>$fields)){
		print join "\n",
			$q->header,
			$q->dberr(dbh=>$dbh,%$err);
	}else{
		print $q->redirect("$ENV{SCRIPT_NAME}?table=$table");
	}
}elsif ($table && $new==2){
	# commit the insert
	# print "about to call row_manip ".$q->dumper({dbh=>$dbh,table=>$table,fields=>$fields,action=>'insert',vals=>\%args});
	my $err = $ez->row_manip(dbh=>$dbh,table=>$table,fields=>$fields,action=>'insert',vals=>\%args);
	if ($err){
		my $title;
		my $stuff;
		if (my $v = $err->{validate}){
			$stuff = $ez->form(fields=>$fields,table=>$table,new=>2,row=>\%args,valid=>$v);
			$title  = 'Please fix these problems';
			$stuff.=$q->dumper($v);
		}else{
			$stuff = $q->dberr(dbh=>$dbh,sql=>$err->{sql});
		}
		print join "\n",
			$q->header,
			$q->start_html(-title=>$title,-style=>{src=>$stylesheet}),
			"<h2>$title</h2>",
			$stuff,
			$q->end_html;
	}else{
		print $q->redirect("$ENV{SCRIPT_NAME}?table=$table");
	}

}elsif ($table && $new==1){
	# ask for the insert data
	my $title = "Create new $table_names{$table}";
	my $row = {};
	my $keys = $tablekeys->{$table};
#
# PROBLEM: next_ids assumes autoincrementing primary key
# SOLN don't call it unless you are going to use it
#
	unless (grep $table eq $_ , qw(TUSER VACCESS)){
		my $kvals = $ez->next_ids(dbh=>$dbh,table=>$table,keys=>$keys);
		
		unless ($kvals){
			print join "\n",
				$q->header,
				$q->start_html(-title=>$title,-style=>{src=>$stylesheet}),
				$q->dberr(dbh=>$dbh,err=>"Could not get next_ids for $table");
				$q->end_html;
			exit;
		}
		$row->{$keys->[$_]} = $kvals->[$_] foreach 0..$#$keys;
	}
	
	print join "\n",
		$q->header,
		$q->start_html(-title=>$title,-style=>{src=>$stylesheet}),
		qq{<P class="heading">&nbsp;<BR>&nbsp;$title<BR>&nbsp;</P>},
		$ez->form(fields=>$fields,table=>$table,new=>2,row=>$row),
		'<BR>',
		# $q->dumper($fields),
		pretty_table_list([qw{PWI_EXEC PWI_ADMIN PWI_BATCH PWI_WORKSHOP PWI_LOCATION}]),
#		pretty_table_list($asp->table_create_list),
		$q->end_html;
	
}elsif ($table){
	my $title = "Triton Database Admininstration Tool. Selected table: [$table_names{$table}]";

	# This is the primary key(s) for the table, in an array ref
	my $keys = $tablekeys->{$table};

	# Add in a edit and delete column
	$fields->{edit}->{sprintf}->{fmt} = qq{<A HREF="$ENV{SCRIPT_NAME}?edit=1&table=$table&}.
			join ('&',map"$_=%s",@$keys).qq{">Edit</A>};
	$fields->{edit}->{sprintf}->{names} = $keys;
	$fields->{edit}->{pretty} = 'Edit';

	$fields->{delete}->{sprintf}->{fmt} = qq{<A HREF="$ENV{SCRIPT_NAME}?delete=1&table=$table&}.
			join ('&',map"$_=%s",@$keys).qq{">Del</A>};
	$fields->{delete}->{sprintf}->{names} = $keys;
	$fields->{delete}->{pretty} = 'Del';

	### don't list the password field on the user table.
	delete $fields->{PWD} if ($table eq 'TUSER');

	### The $lister->{form} sends some params.
	my $page = $args{next} if $args{submit} =~ /next/i;
	$page = $args{previous} if $args{submit} =~ /prev/i;
	$page = $args{page} if $args{submit} =~ /go/i;

	### this is the SQL to use.
	my $sql = "Select * from $table";
	$sql = "$sql order by $_ " if $_ = join ',',@{$tablesort->{$table}};


	### all the table formatting gets done in the lister method
	
	my $lister = $ez->lister(sql=>$sql,form_hidden=>{table=>$table},
		fields=>$fields,look=>$lf,limit=>20,form=>1,page=>$page);
	my $box;
	my $new_button = join "\n",
		$q->start_form (-action=>$ENV{SCRIPT_NAME},-method=>'POST'),
		qq{<INPUT type="hidden" name="table" value="$table">},
		qq{<INPUT type="hidden" name="new" value="1">},
		$q->submit(-name=>"Create new [$table_names{$table}] record"),
		$q->end_form if grep $table eq $_,@$new_button_tables;
		
	
	if ($lister->{count}){
		$box = join "\n",@{$lister->{html}};
		$box .= join "\n",@{$lister->{form}};
	}elsif ($lister->{err}){
		$box = $q->dumper ($lister);
	}else{
		$box = join "\n",$lf->sbox($title),'No data',$lf->ebox;
	}
	print join "\n",
		$q->header(),
		$q->start_html(-title=>$title,-style=>{src=>$stylesheet}),
		$box,
		$new_button,
		'<BR>',
		# $q->dumper($fields),
			pretty_table_list([qw{PWI_EXEC PWI_ADMIN PWI_BATCH PWI_WORKSHOP PWI_LOCATION}]),
#		pretty_table_list($asp->table_create_list),
		$q->end_html;

}else{
# This never happens.  we hae a default table.
# 	my $title = 'ASP ADMIN';
# 	my $asptables = $asp->table_create_list;
# 	my @tables = $dbh->tables;
# 	foreach my $at (@$asptables){
# 		die "ASP table $at not in database $db (Do you need to asptables?)" unless grep uc($at) eq $_,@tables;
# 	}
# 	print join "\n",
# 		$q->header(),
# 		$q->start_html(-title=>$title,-style=>{src=>$stylesheet}),
# 		pretty_table_list([qw{PWI_EXEC PWI_ADMIN PWI_BATCH PWI_WORKSHOP PWI_LOCATION}]),
# #		pretty_table_list($asptables),
# 		$q->end_html;
}

