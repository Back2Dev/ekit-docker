#### $Id: Quote.pm,v 1.2 2001-06-13 06:17:55 ac Exp $ 
package TPerl::Text::Quote;
use strict;

sub quote_quote {
	my $self = shift;
	my $thing = shift;
	$thing =~ s/'/\\'/g;
	return $thing;
}

sub quote_quote_array {
	my $self = shift;
	my @ary = @_;
	return '' unless @ary;
	foreach (@ary) { $_ = $self->quote_quote($_) }
	return q{'}. join ( q{','}, @ary ) . q{'};
}
1;

