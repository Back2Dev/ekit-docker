#!/usr/bin/perl
#$Id: eventview_admin.pl,v 1.4 2007-09-10 10:03:49 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::Event;
use TPerl::LookFeel;

# This handles the EVENT_VIEW tables.  Its a bit crude because it blows away
# the entries in the EVENT_VIEW_LINK box before inserting new ones.  It should
# save the old ones and then use them, or the defaults.  Still this was always
# going to be a bit quick and dirty.  I'll fix this up when I find a nice drag
# and drop javascript library for changing the sort order.

my $q = new TPerl::CGI;
my $sulist = [qw(ac mikkel)];
my %args = $q->args();
my $ev = new TPerl::Event();
my $tables = $ev->table_create_list;
$args{table} ||=$tables->[0];
my $new_buttons = [qw(EVENT_VIEW_LINK  EVENTLOG)];

my $ez = new TPerl::DBEasy (dbh=>$ev->dbh);
$ev->canonical || $q->mydie($ev->err);
my $state = [qw(table)] ;
my $tablekeys = $ev->table_keys;
my $fields_function_name = "$args{table}_fields";
my $fields = $ev->$fields_function_name;
my $edit = $args{edit};
my $new = $args{new};
my $delete = $args{delete};

my $new = $args{new};
my $edit = $args{edit};
my $delete = $args{delete};

my $lf = new TPerl::LookFeel;

my ($list_edit,$list_del) = (1,1);

# Handle view creation.
if (exists($args{new_EVENT_NAME})){
	my $view_id = $ez->next_ids(table=>'EVENT_VIEW',keys=>$tablekeys)->[0];
	my $tr = new TPerl::TransactionList(dbh=>$ev->dbh);
	$tr->push_item(sql=>'insert into EVENT_VIEW (VIEW_ID, VIEW_NAME) values (?,?)',
		params=>[$view_id,$args{new_EVENT_NAME}],pretty=>'Insert into EVENT_VIEW');
	$args{new_EVENT_CODES} = [$args{new_EVENT_CODES}] unless ref($args{new_EVENT_CODES}) eq 'ARRAY';
	my $so = $ev->def_order();
	foreach my $ec (@{$args{new_EVENT_CODES}}){
		$tr->push_item(sql=>'insert into EVENT_VIEW_LINK (VIEW_ID,EVENT_CODE,SORT_ORDER) values (?,?,?)',
			params=>[$view_id,$ec,$so->{$ec}],pretty=>"Insert event '$ec' into EVENT_VIEW_LINK");
	}
	# $q->mydie($tr);
	$ev->dbh->begin_work;
	if ($tr->dbh_do){
		$ev->dbh->commit;
	}else{
		$ev->dbh->rollback;
		$q->mydie($tr->msg_summary(join=>'<BR>',list=>$tr->errs));
	}
}
# Handle view selections for a single row.  events come is as EVENTS_22 for
# VIEW_ID 22.  quite similar to above.  Could refactor into a TPerl::Event module.
foreach my $a (keys %args){
	if (my ($view_id) = $a =~ m/^EVENTS_(\d+)$/){
		# first save the old sort order so we can re-insert it.
		my $sql = 'select * from EVENT_VIEW_LINK where view_id=?';
		my $params = [$view_id];
		my $old_rows = $ev->dbh->selectall_hashref($sql,'EVENT_CODE',{},@$params) 
			|| $q->mydie({sql=>$sql,dbh=>$ev->dbh,params=>$params});
		my $tr = new TPerl::TransactionList(dbh=>$ev->dbh);
		$tr->push_item(sql=> 'delete from EVENT_VIEW_LINK where VIEW_ID = ?',
			params=>[$view_id],pretty=>"Delete existing events for view_id=$view_id");
		$args{$a} = [$args{$a}] unless ref ($args{$a}) eq 'ARRAY';
		my $do = $ev->def_order;
		foreach my $ec(@{$args{$a}}){
			$tr->push_item(sql=>'insert into EVENT_VIEW_LINK (VIEW_ID,EVENT_CODE,SORT_ORDER) values (?,?,?)',
				params=>[$view_id,$ec,$old_rows->{$ec}->{SORT_ORDER}||$do->{$ec}],pretty=>"Insert event '$ec' into EVENT_VIEW_LINK");
		}
		$ev->dbh->begin_work;
		if ($tr->dbh_do){
			$ev->dbh->commit;
		}else{
			$ev->dbh->rollback;
			$q->mydie($tr->msg_summary(join=>'<BR>',list=>$tr->errs));
		}
	}
}

# Handle re-ordering by drag and drop of the selected list.
foreach my $a (keys %args){
	if (my ($view_id) = $a =~ m/^serialize_list_(\d+)$/){
		if ($args{$a} ne ''){
			# lets just use the position in the list as the order,
			# so that the order is always what is specified.  Its easier and more reliable than 
			# shuffling the existing values.

			# scriptaculous serialises stuff so the arg for view_id 2 looks like
			# list_2[]=2_item_22&list_2[]=2_item_23&list_2[]=2_item_24&list_2[]=2_item_25&list_2[]=2_item_29
			my @kv=split '&',$args{$a};
			map s/^.*_item_//,@kv;
			# $q->mydie({kv=>\@kv});
			my $tr = new TPerl::TransactionList(dbh=>$ev->dbh);
			for (my $p=0;$p<=$#kv;$p++){
				my $so = $p+1;
				$tr->push_item(sql=>'update EVENT_VIEW_LINK set SORT_ORDER=? where EVENT_CODE=? and VIEW_ID=?',
					params=>[$so,$kv[$p],$view_id],pretty=>"Reorder list $view_id SORT_ORDER=$so for EVENT_CODE=$kv[$p]");
			}
			$ev->dbh->begin_work;
			if ($tr->dbh_do){
				$ev->dbh->commit;
			}else{
				$ev->dbh->rollback;
				$q->mydie($tr->msg_summary(join=>'<BR>',list=>$tr->errs));
			}
		}
	}
}


# Here we do the function that allows all the selected events to be displayed
# next to the view name in the EVENT_VIEW list.
my $event_view_creator;
if ($args{table} eq 'EVENT_VIEW' && !$edit && !$delete && !$new){
	$fields->{EVENTS}={
		name=>'EVENTS',
		order=>6,
		pretty=>'Selected Events',
		code=>{
			ref=>sub{
				my $view_id = shift;
				my $q1 = new TPerl::CGI('');
				my $on = $ev->dbh->selectcol_arrayref('select EVENT_CODE from EVENT_VIEW_LINK where VIEW_ID=?',{},$view_id);
				my $chkbox = $q1->checkbox_group(
					-name=>"EVENTS_$view_id",-values=>$ev->events,
					-labels=>$ev->names,-defaults=>$on,
					-columns=>6,-attributes=>{align=>'left'},
				);
				$chkbox =~ s/<tr>/<tr align="left">/g;
				return join "\n",
					$q1->start_form(),
					$chkbox,
					$q1->submit(-value=>'Alter selected events for this row only'),
					$q1->hidden(-name=>'table',-value=>$args{table}),
					$q1->end_form;
			},
			names=>['VIEW_ID']
		}
	};
	$fields->{EVENTS_SORT} = {
		name=>'EVENTS_SORT',
		order=>7,
		pretty=>'Sort Selected',
		code=>{
			ref=>sub{
				my $view_id = shift;
				my $view_name = shift;
				my $q1 = new TPerl::CGI('');
				my $on = $ev->view(name=>$view_name);
				my $events = $ev->events;
				my $labs = $ev->names;
				# $chkbox = $events;
				my $listname = "list_$view_id";
				return join "\n",
 					$q1->start_form(),
					$q1->hidden(-id=>"serialize_$listname",-name=>"serialize_$listname"),
					'<p>Drag and Drop to change order</p>',
					qq{<ul align="left" id="$listname">},
					map (qq{<li id="${listname}_item_$_">$labs->{$_}($_)</li>},@$on),
					'</ul>',
					'<script type="text/javascript" language="javascript">',
					'// <![CDATA[',
					qq{Sortable.create("$listname",{
			 			onChange:function(element){\$('serialize_$listname').value = Sortable.serialize(element.parentNode)}
					})
					},
					'// ]]>',
					'</script>',
 					$q1->submit(-value=>'Alter Event order for this view only'),
					$q1->hidden(-name=>'table',-value=>$args{table}),
 					$q1->end_form;

			},
			names=>['VIEW_ID','VIEW_NAME'],
		}
	};
	# Also draw the creator bit for the bottom of the form.
	$event_view_creator = join "\n",
		'<BR>',
		$lf->srbox('Make a new EventView'),
		$q->start_form(),
		"$fields->{VIEW_NAME}->{pretty}:",
		$q->textfield(-name=>'new_EVENT_NAME'),
		$q->checkbox_group(-name=>'new_EVENT_CODES',-values=>$ev->events,-labels=>$ev->names,-columns=>6),
		$q->submit(-value=>'Create a new view'),
		$q->hidden(-name=>'table',-value=>$args{table}),
		# $q->dumper($ev->events);
		# $q->dumper($ev),
		$q->end_form(),
		$lf->erbox,
}

# Lets handle the deletion.
if ($delete && $args{table} eq 'EVENT_VIEW'){
	$ev->delete_view($args{VIEW_ID}) || $q->mydie($ev->err);

	# Don't want the lister trying to do stuff too.  thats inefficient.
	$args{delete}=0;
}

my $import_result;
if (($args{import}) && ($args{table} eq 'EVENT_CODES')){
	my $msgs = $ev->read_from_csv() || $q->mydie($ev->err);
	$import_result = join "\n<BR>",values %$msgs
}



# Do the lister stuff.
my $list_sql = '';

# Might as well see events in a nice order.
$list_sql = "select * from $args{table} order by DEF_SORT_ORDER" 
	if $args{table} eq 'EVENT_CODES';

my $res = $ez->edit(_obj=>$ev,_new_buttons=>$new_buttons,
	_fields=>$fields,
	_list_sql=>$list_sql,
	# _list_params=>$list_params,
	_list_del=>$list_del,
	_list_edit=>$list_edit,
	_tablekeys=>$tablekeys,
	_state=>$state,%args);

if ($res->{err}){
	$q->mydie ($res->{err});
}else{
	print join "\n",
		$q->header,
		$q->start_html(
			-title=>$0,
			-style=>{src=>"/admin/style.css"},
			-script=>[ # The order is important.
				{-language=>'JAVASCRIPT',-src=>'/scriptaculous/prototype.js'},
				{-language=>'JAVASCRIPT',-src=>'/scriptaculous/scriptaculous.js'},
			],
			-class=>'body',),
		# $q->dumper(\%args),
		$import_result,
		$res->{html},
		join (' | ',map qq{<a href="$ENV{SCRIPT_NAME}?table=$_">$_</a>},@$tables),
		'<br>',
		($args{table} eq 'EVENT_CODES' ? 
			qq{<a href="$ENV{SCRIPT_NAME}?import=1">Import from CSV file</a>}:
			''),
		$event_view_creator,
		# $q->dumper(\%ENV),
		$q->end_html;
}

