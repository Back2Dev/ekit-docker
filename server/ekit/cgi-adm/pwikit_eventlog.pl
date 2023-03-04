#!/usr/bin/perl
#$Id: pwikit_eventlog.pl,v 1.9 2007-10-08 06:16:34 triton Exp $
use strict;
use CGI::Carp qw /fatalsToBrowser/;
use TPerl::CGI;
use TPerl::LookFeel;
use TPerl::MyDB;
use TPerl::MAP;
use TPerl::Event;
our %config;
require 'TPerl/pwikit_cfg.pl';

my $map = new TPerl::MAP;
my $dbh = $map->dbh;
my $ez  = $map->ez;
my $ev  = new TPerl::Event( dbh => $dbh );

my $q    = new TPerl::CGI;
my %args = $q->args;
my $lf   = new TPerl::LookFeel( twidth => '0%' );

# See the print statement for the table layout of this page
# | banner						|
# | search_box | search result	|
# | event_log					|

# Here we get alot of stuff that lets us to the search box part of the page..
# pb_args lets us send stuff that comes from the pwikit_cfg.pl into my
# nice use strict modules...

my $pb_args = {

    # Here is how we lookup lc(ROLENAME) in MAP_CASES to get the SID where the
    # events are recorded.
    role2SID => {
        self => $config{participant},
        boss => $config{boss},
        peer => $config{peer}
    },

    # The names of the MAP_CASES table.
    index_table => $config{index},

    # the TPerl::Event object that allows us to do the event_count() group by
    # function.
    ev => $ev,

    # Here we could define the view needed to look at a subset of events in the
    # search box.  pwikit is the default in the module.
    # eventview=>'pwikit',
};
my $search_bits;
if (%args)
	{
	$search_bits = $map->pwikit_eventlog_bits( _config => $pb_args, %args ) || $q->mydie( $map->err );
	}
#print $q->dumper($search_bits),
# Here we draw the search box. The names of the fields are the same as those
# that are fed to pwikit_find.pl. Perhpas we can ad some js that alters the
# action of the form, to allow us to come into this page.
my $searchbox = join "\n", $lf->srbox('Search'), $q->start_form(), 'ID:<BR>',
  $q->textfield(
    -class   => 'small',
    -name    => 'id',
    -size    => 15,
    -default => $args{id}
  ),
  $q->submit( -class => 'small', -value => 'Go' ), 
  '<BR>Password:<BR>',
  $q->textfield(
    -class => 'small',
    -name  => 'pwd',
    -size  => 25
  ),

  '<BR>Name:<BR>',
  $q->textfield(
    -class => 'small',
    -name  => 'name',
    -size  => 25
  ),
  '<BR>Boss:<BR>',
  $q->textfield(
    -class => 'small',
    -name  => 'boss',
    -size  => 25
  ),
  '<BR>Peer:<BR>',
  $q->textfield(
    -class => 'small',
    -name  => 'peer',
    -size  => 25
  ),
  $q->end_form, $lf->erbox;

# Now we have the bits we need to produce some HTML for the search box part of
# the screen.  We need to have links that will show the eventlog for each item
# in the summary.  We use a query_string that will preserve the state (search
# terms) and will have the stuff that drives the eventlog added on.

my $search_state_qs = join '&', map "$_=$search_bits->{states}->{$_}",
  keys %{ $search_bits->{states} };
$search_state_qs = "&$search_state_qs" if $search_state_qs;

# The fields hash for the summary search results table will just display the
# numbers.  Here we customise the columns to add functionality.
my $sr_fields = $search_bits->{fields};

# clicking on the UID field will start a new search showing all members of
# that UID.
$sr_fields->{UID}->{sprintf} = {
    fmt   => qq{<a href="$ENV{SCRIPT_NAME}?id=%s">%s</a>},
    names => [qw(UID UID)]
};

# Clicking on the totals columns will show all the events for that password
$sr_fields->{EVENT_TOTAL}->{sprintf} = {
    fmt =>
      qq{<a href="$ENV{SCRIPT_NAME}?&SID=%s&PWD=%s$search_state_qs">%s</a>},
    names => [qw(SID PWD EVENT_TOTAL)],
};

# Clicking on the event code numbers will display those events for that
# password.
foreach my $f ( keys %$sr_fields ) {
    next unless my ($ec) = $f =~ /EVENT_(\d+)/;
    $sr_fields->{$f}->{sprintf} = {
        fmt =>
qq{<a href="$ENV{SCRIPT_NAME}?&SID=%s&PWD=%s&events=$ec$search_state_qs">%s</a>},
        names => [ qw(SID PWD), "EVENT_$ec" ]
    };
}

# Use the fields, the rows, and the lister to display the results.
my $searchresult = $ez->lister_wrap(
    _no_data   => 'No people matched the search',
    _row_count => '%s people match the search',
    look       => $lf,
    rows       => $search_bits->{rows},
    fields     => $search_bits->{fields},
    limit      => 20,
    form=>1,
) || $q->err( $ez->err );
$searchresult .= '<HR>' . $search_bits->{view_warning}
  if $search_bits->{view_warning};

# If they have clicked on one of the numbers in the  search summary, make an
# eventlog, that remembers the state of the search box stuff at the top.  Sort
# of cut and pasted from aspeventlog.pl
my $eventlog = '';
if ( $args{SID} ) {
    if ( my $bits = $ev->eventlog_bits(%args) ) {
        my $title = $bits->{title};
        my $state = [ keys %{ $bits->{state} } ];

        # Add the states for the search part of the form, so that paging
        # through results does not break your search.
        push @$state, ( keys %{ $search_bits->{states} } );

        # Pretty up the 'No data' and '23 rows' bits.
        my $row_count_sprintf = "%s events for $bits->{SID}";
        $row_count_sprintf .= "and password $bits->{pwd}" if $bits->{pwd} ne '';
        $eventlog = join "\n",
          $ez->lister_wrap(
            sql    => $bits->{sql},
            look   => $lf,
            fields => $bits->{fields},
            form   => 1,
            params => $bits->{params},
            _state => $state,
            limit  => 25,
            %args,
            _row_count => $row_count_sprintf,
            _no_data   => 'No Events',
          )
          || $q->mydie( $ez->err ), $lf->srbox($title),
          $q->start_form( -action => $ENV{SCRIPT_NAME}, -method => 'POST' ),
          $q->checkbox_group( %{ $bits->{event_args} }, override => 1 ),
          map ( $q->hidden( -name => $_, -value => $args{$_} ),
            grep $_ ne $bits->{events_name}, @$state ),
          '<BR>', $q->submit( -value => 'Select Events' ), $q->end_form,
          $lf->erbox,

          # Don't need these graphs here.  That would be too much...
          #qq{<a href="survey_stats.pl?SID=$SID">Time Series Event graphs</a>}
          # $q->dumper ($bits);
          ;
    }
    else {
        $eventlog = $q->err( $ev->err );
    }
}

# Now that all the pieces are made, lets print them out.  Gotta be a better way
# to build tables....
print join "\n", $q->header,
  $q->start_html(
    -title => 'PWIKit Event Search',
    style => { src => '/pwikit/style.css' }
  ),
  # $q->dumper($search_bits),

  # $q->dumper(\%args),
  qq{<TABLE border="0" cellpadding="0" cellspacing="0" width="100%">},
  '<TR><TD>', $q->img( { -src => '/pwikit/mapbanner.gif' } ), '</TD></TR>',
  '<TR><TD>', '<TABLE valign="top">', '<TR><TD>', $searchbox, '</TD><TD>',
  $searchresult, '</TD></TR>', '</TABLE>', '</TD></TR>', '<TR><TD>', $eventlog,
  '</TD></TR>', '</TABLE>',

  # $q->dumper($search_bits->{sr_rows}),
  # $q->dumper($sr_fields),
  $q->end_html;

