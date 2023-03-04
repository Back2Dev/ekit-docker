#!/usr/bin/perl
#$Id: survey_stats.pl,v 1.9 2006-10-06 03:53:35 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::Graph;
use TPerl::Event;
use TPerl::DBEasy;
use TPerl::LookFeel;
use TPerl::Graph;

### stuff we always use.
my $q = new TPerl::CGI;
my %args = $q->args();
my $SID = $args{SID} or print ($q->noSID()) and exit;
my $dbh = dbh TPerl::MyDB (attr=>{RaiseError=>0,PrintError=>0});
my $ev = new TPerl::Event (dbh=>$dbh,SID=>$SID);
my $ez = new TPerl::DBEasy (dbh=>$dbh);
my $lf = new TPerl::LookFeel;


sub first_epoch {
	my $table = shift;
	my $sql = "select min(ts),max(ts) from $table where TS>0";
	my $res = $dbh->selectall_arrayref($sql,{}) or $q->mydie({sql=>$sql,dbh=>$dbh,params=>[$table]});
	# $q->mydie ($res);
	return (@{$res->[0]});

}

### some 'constants'
my $summ;
# my $ev_labels = $ev->pretty(table_only=>1);
my $tbl_only = $ev->view(name=>'table_only');
my $names = $ev->names;
my $ev_labels = {map {$_=>$names->{$_}} @$tbl_only};
# $q->mydie ({old=>$ev->pretty(table_only=>1),new=>$ev_labels});
my $do_graph = $args{graph};
my $events = $args{events};
my $interval = $args{interval} || 3600*24;
my $distinct = 1;
$distinct = $args{distinct} if exists $args{distinct};


my $table = "${SID}_E";
my ($first_ep,$last_ep) = first_epoch ($table);
$first_ep = $ez->text2epoch($args{pretty_start}) || $first_ep if $args{pretty_start};
$last_ep = $ez->text2epoch($args{pretty_end}) || $last_ep if $args{pretty_end};
$first_ep ||=0;
$last_ep ||= time();

my $pretty_start = $ez->epoch2text($first_ep);
my $pretty_end = $ez->epoch2text($last_ep);


$events = [$events] if $events ne '' and ref $events ne 'ARRAY';

if ($args{apost}){

	my $sql1 = "update $table set TP=(ts-$first_ep)/$interval where ts>=$first_ep and ts<=$last_ep";
	if ( $dbh->do ($sql1)){
	}else{
		my $sql2 = "alter table $table add TP integer";
		$dbh->do($sql2) or $q->mydie({sql=>$sql2,dbh=>$dbh});
		$dbh->commit;
		$q->mydie({sql=>$sql1,dbh=>$dbh});
	}

	my $ts_where = "(ts>=$first_ep) and (ts <= $last_ep)";
	my $ev_where = join ' OR ', map "event_code=$_" ,@$events if ref $events eq 'ARRAY';

	my $where = "where $ts_where";
	$where = "where ($ts_where) and ($ev_where)" if $ev_where;

	my $dis_phrase = 'PWD';
	$dis_phrase='distinct(PWD)' if $distinct;
	my $sql = "select event_code,count($dis_phrase) as CNT,TP from ${SID}_E $where group by TP,EVENT_CODE";
	# $summ = $ez->lister_wrap(form=>1,sql=>$sql,_page_args=>\%args,_state=>['SID']) || $q->mydie($ez->err);
	my $res = $dbh->selectall_arrayref($sql,{Slice=>{}});
	$q->mydie({sql=>$sql,dbh=>$dbh}) unless $res;
	my $tp_vals = {};
	my $max = 0;
	foreach my $r (@$res){
		$tp_vals->{$r->{TP}}->{$r->{EVENT_CODE}} = $r->{CNT};
		$max = $r->{CNT} if $r->{CNT} > $max;
	}
	# $q->mydie($tp_vals);
	my $rows = [];
	my $tp_labs = {};
	foreach my $tp (sort {$a <=> $b} keys %$tp_vals){
		my $row = $tp_vals->{$tp};
		$row->{TP} = $tp;
		$tp_labs->{$tp} = $ez->epoch2text($tp*$interval+$first_ep);
		push @$rows,$row;
	}
	# $q->mydie($rows);
	my $fields = {};
	$fields->{TP} = {pretty=>'Time Period',order=>-1,name=>'TP'};
	$fields->{TP}->{cgi}->{args} = {-labels=>$tp_labs};
	my $ev_list = $events || [keys %$ev_labels];
	$fields->{$_} = {pretty=>$ev_labels->{$_},order=>20+$_,name=>$_} foreach @$ev_list;

	if ($do_graph){
		$lf->trow_properties(align=>['','left']);
		my $gr = new TPerl::Graph(datamax=>$max);
		my $graph_code_ref = sub{
			my %data = ();
			@data{@$ev_list}=@_;
			return $gr->table(data=>\%data,labels=>$ev_labels);
		};
		$fields->{graph} = {pretty=>'Graph',code=>{ref=>$graph_code_ref,names=>$ev_list}};
	}
	# $q->mydie($lf);

	$summ = $ez->lister_wrap(look=>$lf,form=>1,rows=>$rows,_state=>['SID'],fields=>$fields) || $q->mydie($ez->err);
	# $summ = $ez->lister_wrap(look=>$lf,form=>1,rows=>$rows,_state=>['SID']) || $q->mydie($ez->err);
}else{
	$summ = 'For big jobs, this can take a while.  Here is an opportunity to change the defaults first';
}

my $intervals = {3600=>'1 hour',24*30*3600=>'30 Days',24*7*3600=>'Week',3600*12=>'12 Hours',3600*24=>'24 hours',3600*6=>'6 Hourly'};

print join "\n",
	$q->header,
	$q->start_html(-title=>"Stats for $SID",-style=>[{src=>'/admin/style.css'},{src=>'/pwikit/style.css'},{src=>"/$SID/style.css"}]),
	# $q->dumper(\%args),
	$summ,
	$lf->sbox('Customise'),
	$q->start_form (-action=>$ENV{SCRIPT_NAME},-method=>'POST'),
	$q->hidden(-name=>'SID',-value=>$SID),
	$q->hidden(-name=>'apost',-value=>1),
	'Start time:',
	$q->textfield(-name=>'pretty_start',-value=>$pretty_start),
	'End time:',
	$q->textfield(-name=>'pretty_end',-value=>$pretty_end),
    'Limit Events:'.$q->checkbox_group (-name=>'events',-values=>[sort {$a <=> $b} keys %$ev_labels],
        -labels=>$ev_labels,-override=>1,-defaults=>$events,-columns=>6),
    'Interval:'.$q->radio_group (-name=>'interval',-values=>[sort {$a <=> $b} keys %$intervals],
        -labels=>$intervals,-override=>1,-default=>$interval,-columns=>6),
    'Draw Graphs:'.$q->radio_group (-name=>'graph',-values=>[0,1],
        -labels=>{0=>'No',1=>'Yes'},-override=>1,-default=>$do_graph,-columns=>6),
 	'Group events for same passwords:'.$q->radio_group(-name=>'distinct',-override=>1,-defaults=>$distinct,
 		-columns=>6,-values=>[0,1],-labels=>{0=>'No',1=>'Yes'}),
    $q->submit(-value=>'Go'),
    $q->end_form,
	$lf->ebox,


	# $q->dumper({fields=>$fields,rows=>$rows}),
	$q->end_html;
