#!/usr/bin/perl
# $Id: aspbatchstatus.pl,v 1.10 2008-12-18 02:10:55 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::LookFeel;
use TPerl::DBEasy;
use TPerl::ASP;
use TPerl::PFinder;
use List::Util qw (sum);

my $q = new TPerl::CGI;
my %args = $q->args;
my $lf = new TPerl::LookFeel;

my $SID = $args{SID} || $args{survey_id};
$q->mydie("no SID sent") unless $SID;

my $dbh = dbh TPerl::MyDB() or $q->mydie("Cannot connect to database:".TPerl::MyDB->err);

my $ez = new TPerl::DBEasy (dbh=>$dbh);
my $pf = new TPerl::PFinder (dbh=>$dbh);

my $page = $args{next} if $args{submit} =~ /next/i;
$page = $args{previous} if $args{submit} =~ /prev/i;
$page = $args{page} if $args{submit} =~ /go/i;

my $asp = new TPerl::ASP (dbh=>$dbh);
my $bl = $asp->batch_list (SID=>$SID,table_only=>1);
my $rows = [];

my $sl = $pf->status_labels();
my $sql = "select stat,count(stat) from $SID where batchno=? group by stat";
my $sth = $dbh->prepare($sql) or $q->mydie ({sql=>$sql,dbh=>$dbh});

my $bounce_sql="select count(distinct(${SID}.pwd)),${SID}.batchno from ${SID},${SID}_E where ${SID}_E.pwd=${SID}.pwd and (${SID}_E.event_code = 32 or ${SID}_E.event_code=80) group by ${SID}.BATCHNO";
my $bounce_counts = $dbh->selectall_hashref($bounce_sql,'BATCHNO') || $q->mydie({sql=>$bounce_sql,dbh=>$dbh});
# $q->mydie($bounce_counts);

my $tot = {};
foreach my $bn (sort {$b <=> $a } keys %$bl){
	my $row = $bl->{$bn};
	$sth->execute ($bn) or $q->mydie(sql=>$sql,dbh=>$dbh);
	while (my $r=$sth->fetchrow_hashref()){
		$row->{"STAT$r->{STAT}"}=$r->{COUNT};
		$row->{"TOTAL"} += $r->{COUNT};
		$row->{BOUNCE} = $bounce_counts->{$bn}->{COUNT};
		$tot->{$r->{STAT}} += $r->{COUNT};
	}
	$tot->{BOUNCE} += $bounce_counts->{$bn}->{COUNT};
	$row->{BID} ||=$bn;
	push @$rows,$row;
}
my $tot_row = {TITLE=>'ALL ACTIVE BATCHES'};
$tot_row->{"STAT$_"} = $tot->{$_} foreach (0..8);
$tot_row->{TOTAL} += $tot->{$_} foreach (0..8);
$tot_row->{BOUNCE} = $tot->{BOUNCE};

my $fields = $asp->batch_fields;
$fields->{BID}->{cgi}->{func}='textfield';
delete $fields->{$_} foreach qw(ORIG_NAME GOOD BAD NAMES_FILE CLEAN_EPOCH DELETE_EPOCH);
$fields->{TOTAL} = {pretty=>'Total',name=>'TOTAL',order=>19};
$fields->{"STAT$_"} = {pretty=>$sl->{$_},name=>"STAT$_",order=>20+$_} foreach keys %$sl;
$fields->{BOUNCE} = {pretty=>'Bounced',name=>'BOUNCE',order=>30};

my $lister = $ez->lister(rows=>$rows,look=>$lf,form=>1,form_hidden=>{SID=>$SID},page=>$page,fields=>$fields);

delete $fields->{$_} foreach qw(UPLOADED_BY UPLOAD_EPOCH BID);

my $slister = $ez->lister(rows=>[$tot_row],look=>$lf,fields=>$fields);

print $q->header,$q->start_html(-style=>$q->adm_style($SID),-title=>"$SID Batch Summary", -class=>"body");
if ($slister->{count}){
    print join "",@{$slister->{html}};
}elsif ($slister->{err}){
    print $q->err ($lister);
}else{
    print "No Data";
}

print "<p>Detail by Batch</p>";
# print $q->dumper($tot);
# print $q->dumper($tot_row);
# print $q->dumper($bounce_counts);

if ($lister->{count}){
	# print $q->dumper($rows);
    print join "",@{$lister->{html}};
    print join '',@{$lister->{form}};
}elsif ($lister->{err}){
    print $q->err (sql=>$lister->{sql}, dbh=>$dbh);
}else{
    print "No Data";
}
print $q->end_html;

