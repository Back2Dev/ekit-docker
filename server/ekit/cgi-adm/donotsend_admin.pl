#!/usr/bin/perl
#$Id: donotsend_admin.pl,v 1.1 2006-03-01 02:48:36 triton Exp $
use strict;
use CGI::Carp qw (fatalsToBrowser);
use TPerl::CGI;
use TPerl::DoNotSend;
use TPerl::DBEasy;

my $dns = new TPerl::DoNotSend;
my $ez = $dns->ez;
my $q = new TPerl::CGI;
my %args = $q->args;
$args{table}='DONOTSEND';
my $fields = $dns->DONOTSEND_fields;
my $tablekeys = {DONOTSEND=>['DNS_ID']};

my $lf = new TPerl::LookFeel;

my $list_sql = 'select * from DONOTSEND';
my $list_params = undef;

if ($args{search}){
	my @wheres = ();
	foreach my $th (qw(PWD EMAIL)){
		my $arg = "search_$th";
		if ($args{$arg} ne ''){
			push @wheres, " upper($th) like upper(?) ";
			push @$list_params ,qq{%$args{$arg}%};
		}
	}
	foreach my $th (qw(SID)){
		my $arg = "search_$th";
		if ($args{$arg} ne ''){
			push @wheres, " $th=? ";
			push @$list_params ,$args{$arg};
		}
	}
	$list_sql .= ' where '.join ' AND ',@wheres if @wheres;
}

my $search_box = join "\n",
	$lf->srbox('Search Do Not Send list'),
	$q->start_form(-method=>'POST',-action=>$ENV{SCRIPT_NAME}),
	'SID:',
	$q->popup_menu(-name=>'search_SID',-override=>1,-default=>$args{search_SID},
		-values=>$fields->{SID}->{cgi}->{args}->{-values},-labels=>{''=>'Any'}),
	'<br>PWD:',
	$q->textfield(-name=>'search_PWD',-override=>1,-value=>$args{search_PWD}),
	'<br>Email:',
	$q->textfield(-name=>'search_EMAIL',-override=>1,-value=>$args{search_EMAIL}),
	'<BR>',
	$q->submit(-name=>'search',-value=>'Search'),
	$q->end_form,
	$lf->erbox;


my $res = $ez->edit(
	_obj=>$dns,
	_list_sql=>$list_sql,
	_list_params=>$list_params,
	_list_del=>1,
	_list_edit=>1,
	_fields=>$fields,
	_tablekeys=>$tablekeys,
	%args,
);

$q->mydie ($res->{err}) if $res->{err};
print join "\n",
	$q->header,
	$q->start_html(-title=>$0,-style=>{src=>"/admin/style.css"}),
	$res->{html},
	$search_box,
	# $q->dumper(\%args),
	$q->end_html;
