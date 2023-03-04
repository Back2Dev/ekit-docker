#$Id: RawFile.pm,v 2.4 2010-05-13 14:19:21 triton Exp $
package TPerl::RawFile;
use strict;
use Carp qw(confess);
use FileHandle;
use Data::Dumper;

=head1 SYNOPSIS

Parse input.raw files into transactions.

 use Data::Dumper;
 use TPerl::RawFile;
 my $rf = new TPerl::RawFile(file=>'...../ABC123/web/input.raw;);
 while (my $t=$rf->transaction){
 	## $t is a hashref with the transaction in it.
	print Dumper $t;
 }

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	confess ('file is a required arg') unless $args{file};

	$self->{file} = $args{file};
	return $self;
}

sub file { my $self = shift; return $self->{file}};

sub fh {
    my $self = shift;
    return $self->{fh} if $self->{fh};
    my $file = $self->file;
    my $mod = '';
    if (my $fh = new FileHandle ("$mod $file")){
        $self->{fh} = $fh;
        return $fh;
    }else{
        $self->err("Could not open file $mod $file:$!");
        return undef;
    }

}   
sub err {
    my $self = shift; 
    return $self->{err} = $_[0] if @_; 
    return $self->{err}; 
}

sub get_transaction_lines {
	my $self = shift;
	return undef unless my $fh = $self->fh;
	my @lines = ();
	my $started = 0;
	while (my $line = <$fh>){
		chomp ($line);
		$line =~ s/\r$//;
		$started++ if $line =~ /^# Begin/;
		push @lines,$line if $started;
		last if $line =~ /^#-+ End/;
	}
	return \@lines;
	return \@lines if $started;
	$self->err("Could not find a Begin line");
	return undef;
}

sub transaction {
	my $self = shift;
	my $debug = 0;
	if (my $lines = $self->get_transaction_lines()){
		return undef unless @$lines;
		my $vals = {};
		my $fl = $lines->[0];
		$vals->{hdr} = $fl;		# Save the header line too, so it can be preserved
		while ($fl =~ /(\w+)\s*=([\.\w]*)/g){
			$vals->{$1}=$2;
			print "PARSED FROM BEGIN: $1 = $2\n" if ($debug);
		}
		my @parseme = @$lines;
		shift @parseme;
		my $ll = pop @parseme;
		unless ($ll =~ /^#-+ End/){
			$self->err("Last line missing an '# End'".Dumper $lines);
			return undef;
		}
		# $debug = 1 if $vals->{ts} eq '1064207492';
		for (my $lnum=0;$lnum<=$#parseme;$lnum++){
			my $l = $parseme[$lnum];
			if (my ($key,$val) = $l =~ /(\w+)\s*=\s*'(.*?)',\s*$/){
				$vals->{$key} = $val;
				print "parsed $l\n" if $debug;
			}elsif ($lnum < $#parseme-1){
				# whack the line onto the start of the next line.
				$parseme[$lnum+1] = $parseme[$lnum] . $parseme[$lnum+1];
				$parseme[$lnum] = '';
				print "$lnum:$parseme[$lnum]\n\n$parseme[$lnum+1]\n\n" if $debug;
			}else{
				next if $l =~ /^\s*HTTP_USER_AGENT/;
				my $file = $self->file;
				$self->err("line problem :'$l' in ".Dumper (\@parseme)."\n");
				return undef;
			}
		}
		$vals->{ts_s} = scalar (localtime($vals->{ts})) if $vals->{ts} and !$vals->{ts_s};
		return $vals;
	}else{
		return undef;
	}
}

1;
