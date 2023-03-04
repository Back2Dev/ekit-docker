#!/usr/bin/perl
#$Id$
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::MAP;
use TPerl::LookFeel;
use TPerl::DBEasy;
use TPerl::Event;


my $q = new TPerl::CGI;
my $map = new TPerl::MAP;
my $dbh = $map->dbh;
my $ez = new TPerl::DBEasy(dbh=>$dbh);
my %args = $q->args;
my $ev = new TPerl::Event(dbh=>$dbh);
my $lf = new TPerl::LookFeel;

my $fields = $ev->fields('MAP001');
delete $fields->{$_} foreach qw(BROWSER BROWSER_VER OS OS_VER YR MON MDAY HR MINS);
$fields->{PWD}->{sprintf} = {
    fmt =>
      qq{<A href="/cgi-adm/pwikit_eventlog.pl?&SID=%s&PWD=%s&pwd=%s" target="_blank">%s</a>},
    names => [qw(SID PWD PWD PWD)]
};
my $codes = $args{codes}||[80,32];
my $days = $args{days} || 2;
my $title = "Events for the last $days day(s)";
my $code_labs = $fields->{EVENT_CODE}->{cgi}->{args}->{-labels};

print join "\n", $q->header,

  $q->start_html(
    -style => { src => '/admin/style.css' },
    -title => $title,
  ),
  # $q->dumper(\%args),
  # $q->dumper($ev->view(name=>'pwikit')),
  $q->start_form,
  'Last ',$q->textfield( -name => 'days', -value => $days,size=>3 ),'days',
  $q->checkbox_group(
    -name    => 'codes',
    -values  => $ev->view(name=>'pwikit'),
	-default => $codes,
	-labels=>$code_labs,
    -columns => 6,
	-override=>1,
  ),
  $q->submit(),
  $q->end_form,
  $ez->lister_wrap(
    rows   => $map->recent_events( days => $days, codes => $codes ),
    fields => $fields,
    look   => $lf,
    form   => 1,
	_state  => [qw(codes days)],
    %args
  ),
  $q->end_html;
