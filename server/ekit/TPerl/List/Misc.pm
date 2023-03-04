package TPerl::List::Misc;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter;
$VERSION = "1.00";
@ISA = qw(Exporter);

@EXPORT_OK = qw (all_values first_value);

sub all_values {
    my ($scalar) = shift;
    if (!defined($scalar)) {
        return ();
    }
    if (ref($scalar) eq 'ARRAY') {
        return @{$scalar};
    }
    else {
        return ($scalar);
    }
}
sub first_value {
    my ($scalar) = shift;
    if (ref($scalar) eq 'ARRAY') {
        return $scalar->[0];
    }
    else {
        return $scalar;
    }
}
1;
