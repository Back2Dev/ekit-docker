## $Id: Lookup.pm,v 1.17 2011-07-26 20:51:34 triton Exp $
package TPerl::Lookup;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(question_type_number qt_match);

use strict;
use String::Approx 'amatch';
use Data::Dumper;

my %question_numbers = (
        NUMBER           => 1,
        MULTI            => 2,
        ONE_ONLY         => 3,
		SINGLE			=> 3,
        YESNO            => 4,
        WRITTEN          => 5,
        PERCENT          => 6,
        INSTRUCT         => 7,
		INSTRUCTION		=> 7,
        EVAL             => 8,
		EVAL		=> 8,
        DOLLAR           => 9,
        RATING           => 10,
        UNKNOWN          => 11,
        FIRSTM           => 12,
        COMPARE          => 13,
        GRID             => 14,
        OPENS            => 15,
		TEXT			 => 15,
		DATE			=> 16,
		YESNOWHICH		=>	17,
		WEIGHT			=>	18,
		AGEONSET		=>	19,
		CODE			=> 20,
		CALC			=> 20,
		TALLY			=> 21,
		CLUSTER			=> 22,
		TALLY_MULTI		=> 23,
		GRID_TEXT		=> 24,
		GRID_MULTI		=> 25,
		GRID_PULLDOWN	=> 26,
		PERL_CODE		=> 27,
		REPEATER		=> 28,
		GRID_NUMBER		=>29,
		SLIDER			=>30,
		RANK			=>31,
);

sub question_type_number {
	my $type = shift;
	if (my ($num) = $type=~ /(\d+)/ ){
		return $num
	}else{
		return $question_numbers{uc($type)};
	}
};

sub qt_match {
	my $type = shift;
	my $debug = 0;
	print "type=$type\n" if $debug;
	if (my ($num) = $type =~ /(\d+)/ ){
		return $num if grep $_ eq $num ,values %question_numbers;
		return undef;
	}else{
		my $utype=uc($type);
		return $question_numbers{$utype} if exists $question_numbers{$utype};
		my @matches = amatch ($utype,keys %question_numbers);
		print "matches of $utype=".Dumper\@matches if $debug;
		return $question_numbers{$matches[0]} if @matches;
		return undef;
	}
}

