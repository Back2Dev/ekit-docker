package TPerl::Hash;
#$Id: Hash.pm,v 1.2 2005-06-02 01:07:14 triton Exp $
use strict;
use Tie::Hash;
use vars qw(@ISA);
@ISA = qw(Tie::StdHash);

=head1 SYNOPSIS

This is a case insensitive hash.  
 
 my %hash = ();
 tie %hash 'TPerl::Hash'

These 3 assignments all end up in the UPPERCASE key
 
 $hash->{goose} = 1;
 $hash->{Goose} = 2;
 $hash->{GOOSE} = 3;

So no matter how you ask for a goose

 print $hash->{GoOsE} 

You get 3

=cut

sub STORE {
    my ($self, $key, $value) = @_;
    return $self->{uc $key} = $value;
} 

sub FETCH {
    my ($self, $key) = @_;
    return $self->{uc $key};
}
sub EXISTS {
    my ($self, $key) = @_;
    return exists $self->{uc $key};
} 
sub DEFINED {
    my ($self, $key) = @_;
    return defined $self->{uc $key};
} 
sub DELETE {
	my ($self,$key) = @_;
	delete $self->{uc $key};
}
1;
