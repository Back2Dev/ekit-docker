#!/usr/bin/perl
#$Id: aspeventlog.pl,v 1.10 2006-06-06 04:05:25 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::Event;
use TPerl::DBEasy;
use TPerl::MyDB;
use TPerl::LookFeel;
use HTML::Entities;

my $q=new TPerl::CGI;
my %args = $q->args;
my $lf = new TPerl::LookFeel;
my $ev = new TPerl::Event;
my $ez = new TPerl::DBEasy(dbh=>$ev->dbh);

my $bits = $ev->eventlog_bits(%args) || $q->mydie($ev->err);

my $SID = $bits->{SID};
my $title= $bits->{title};
my $state=[keys %{$bits->{state}}];

print join "\n",
	$q->header,
	$q->start_html(-title=>$title,-style=>[{src=>'/admin/style.css'},{src=>'/pwikit/style.css'},{src=>"/$SID/style.css"}]),
	# $q->dumper($bits->{event_args}),
	# $q->dumper($bits),
	# $q->dumper($state),
	# $q->dumper(\%args),
	$ez->lister_wrap(sql=>$bits->{sql},look=>$lf,fields=>$bits->{fields},form=>1,params=>$bits->{params},
		_state=>$state,limit=>10,
		_row_count=>"%s events for $SID",
		_no_data=>'No events',%args)||$q->mydie($ez->err),
	$lf->sbox($title),
	$q->start_form (-action=>$ENV{SCRIPT_NAME},-method=>'POST'),
	$q->popup_menu(%{$bits->{pwd_args}}),
	$q->checkbox_group (%{$bits->{event_args}},override=>1),
	# Want all the state vars, except the events one.  Need to be able to turn off the limit.
	map ($q->hidden(-name=>$_,-value=>$args{$_}),grep !($_ eq $bits->{events_name} || $_ eq $bits->{pwd_name}),@$state),
	'<BR>',
	$q->submit(-value=>'Limit Events'),
	$q->end_form,
	$lf->ebox,
	qq{<a href="survey_stats.pl?SID=$SID">Time Series Event graphs</a>},
	$q->end_html;
