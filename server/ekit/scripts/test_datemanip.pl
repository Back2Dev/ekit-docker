#!/usr/local/bin/perl
#
## $Id: test_datemanip.pl,v 1.4 2012-10-03 23:48:51 triton Exp $
#
#use Time::Local;                           #perl2exe
use Data::Dumper;                           #perl2exe
use Date::Manip;                            #perl2exe
#Date::Manip::Date_SetConfigVariable("TZ","EST");
# We might need this if we want to operate outside the US:
#Date_Init("DateFormat=Non-US");

my %stuff;
my $delta = "+6w +3d";
$stuff{today} = &ParseDate('today');
$stuff{todayplus6} = &DateCalc($stuff{today},$delta);
$stuff{todaystr} = UnixDate($stuff{today},"20%y-%m-%d");
$stuff{today6str} = UnixDate($stuff{todayplus6},"20%y-%m-%d");
$stuff{delta} = DateCalc($stuff{today},$stuff{todayplus6});
$stuff{minus3} = DateCalc($stuff{today},"-3 weeks");
$stuff{minus3w} = DateCalc($stuff{today},"-3w");
my $result = UnixDate($stuff{minus3},'%Y-%m-%d');
print "minus 3 weeks = $result\n";
my $result = UnixDate($stuff{minus3w},'%Y-%m-%d');
print "minus 3w = $result\n";
($stuff{deltadays}) = Delta_Format($stuff{delta},1,('%wt'));
for (my $i=1;$i<3;$i++)
    {
    my $d = "+${i}d";
    my $delta = &ParseDateDelta($d);
    print "$d delta$i = $delta\n";
    ($stuff{"delta$i"}) = Delta_Format($delta,1,('%wt'));
    ($stuff{"added$i"}) = Date_NextWorkDay($stuff{today},$i);
    }

$stuff{lastsunday} = &DateCalc($stuff{today},"previous sunday");
print Dumper \%stuff;
#foreach my $key (sort keys %stuff)
#   {
#   print "$key = $stuff{$key}\n";
#   }

foreach ('5-5-10', '5-5-2010', '2010-5-5', '5/5/10')
    {
    my $indate = $_;
	}

	my $wsdate = &ParseDate('2014-08-01');
    my $today = &ParseDate('today');
    my $delta = &DateCalc($today,$wsdate);
    $delta = ParseDateDelta($delta,'semi');
    my $togo = &Delta_Format($delta,1,"%wt");
    print "togo=$togo\n";

