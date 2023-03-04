package TPerl::ConfigIniFiles;
#$Id: ConfigIniFiles.pm,v 2.4 2005-06-10 01:10:42 triton Exp $
use strict;
use vars qw (@ISA);
use Config::IniFiles;
use List::Util qw(sum);


@ISA = qw (Config::IniFiles);

sub my_new {
	# A constructor for Config::IniFiles
	my $proto = shift;
	my $class = ref $proto || $proto;
	my %args = @_;
	my $file = $args{file};
	unless ($file){
		$@ = 'File arg not sent';
		return undef;
	}
	if (-e $file){
	}else{
		$@= "file '$file' does not exist";
		return undef;
	}
	if (my $ini = new Config::IniFiles(-file=>$file)){
		bless $ini,$proto;
		return $ini;
	}else{
		$@="Could not parse '$file' as an ini file";
		return undef;
	}
}

## I don;t like the <<EOT way of writing the ini file.
sub OutputConfig {
  my $self = shift;
  my($sect, $parm, @cmts);
  my $ors = $self->{line_ends} || $\ || "\n";           # $\ is normally unset, but use input by default
  my $notfirst = 0;
  local $_;
  foreach $sect (@{$self->{sects}}) {
    next unless defined $self->{v}{$sect};
    print $ors if $notfirst;
    $notfirst = 1;
    if ((ref($self->{sCMT}{$sect}) eq 'ARRAY') &&
        (@cmts = @{$self->{sCMT}{$sect}})) {
      foreach (@cmts) {
        print "$_$ors";
      }
    }
    print "[$sect]$ors";
    next unless ref $self->{v}{$sect} eq 'HASH';

    foreach $parm (@{$self->{parms}{$sect}}) {
      if ((ref($self->{pCMT}{$sect}{$parm}) eq 'ARRAY') &&
          (@cmts = @{$self->{pCMT}{$sect}{$parm}})) {
        foreach (@cmts) {
          print "$_$ors";
        }
      }

      my $val = $self->{v}{$sect}{$parm};
      next if ! defined ($val); # No parameter exists !!
      if (ref($val) eq 'ARRAY') {
        my $eotmark = $self->{EOT}{$sect}{$parm} || 'EOT';
        #AC print "$parm= <<$eotmark$ors";
        foreach (@{$val}) {
          #AC print "$_$ors";
		  print "$parm=$_$ors";
        }
        #AC print "$eotmark$ors";
      } elsif( $val =~ /[$ors]/ ) {
        # The FETCH of a tied hash is never called in 
        # an array context, so generate a EOT multiline
        # entry if the entry looks to be multiline
        my @val = split /[$ors]/, $val;
        if( @val > 1 ) {
          my $eotmark = $self->{EOT}{$sect}{$parm} || 'EOT';
#AC           print "$parm= <<$eotmark$ors";
#AC           print map "$_$ors", @val;
#AC           print "$eotmark$ors";
			print map "$parm=$_$ors",@val;
        } else {
           print "$parm=$val[0]$ors";
        } # end if
      } else {
        print "$parm=$val$ors";
      }
    }
  }
  return 1;
}

=head2 SectionExists ( $sect_name )

Returns 1 if the specified section exists in the INI file, 0 otherwise (undefined if section_name is not defined).

AC This is not in the windows  version of the Confiig::IniFiles

=cut

sub SectionExists {
    my $self = shift;
    my $sect = shift;

    return undef if not defined $sect;

    if ($self->{nocase}) {
        $sect = lc($sect);
    }
    
    return undef() if not defined $sect;
    return 1 if (grep {/^\Q$sect\E$/} @{$self->{sects}});
    return 0;
}

# AC This is not in the windows  version of the Confiig::IniFiles

sub DeleteSection {
    my $self = shift;
    my $sect = shift;

    return undef if not defined $sect;

    if ($self->{nocase}) {
        $sect = lc($sect);
    }

    # This is done, the fast way, change if delval changes!!
    delete $self->{v}{$sect};
    delete $self->{sCMT}{$sect};
    delete $self->{pCMT}{$sect};
    delete $self->{EOT}{$sect};
    delete $self->{parms}{$sect};

    @{$self->{sects}} = grep !/^\Q$sect\E$/, @{$self->{sects}};

    if( $sect =~ /^(\S+)\s+\S+/ ) {
        my $group = $1;
        if( defined($self->{group}{$group}) ) {
            @{$self->{group}{$group}} = grep !/^\Q$sect\E$/, @{$self->{group}{$group}};
        } # end if
    } # end if

    return 1;
} # end DeleteSection

sub newval_after {
	my $self = shift;
	my $sect = shift;
	my $parm = shift;
	my $after=shift;
	my @val = @_;

	$self->newval($sect,$parm,@val) or return undef;
	return 1 unless $after;
	return 1 if $parm eq $after;
	my $ary = $self->{'parms'}->{$sect};
	return 1 if $ary->[-1] ne $parm;
	my $found = undef;
	foreach my $i (0..$#$ary){
		$found = $i if $ary->[$i] =~ /^\Q$after\E$/;
		last if defined $found;
	}
	return 1 unless $found;
	# use Data::Dumper;print Dumper $ary;
	pop @$ary;
	splice @$ary,$found+1,0,$parm;
	# use Data::Dumper;print Dumper $ary;
}

sub cv_ini_section {
# makes writing the ini files for mikes CeeVee chart viewer.
# origianlly appeared in the fgi_tables.pl emba thing.

	my $self = shift;
    my %args = @_;

    my $s= $args{section};
    my $opts= $args{opts};
    my $traces = $args{traces};

    $self->AddSection ($s);
    $self->newval($s,$_,$opts->{$_}) foreach keys %$opts;
    my $count = 1;
    foreach my $t (@$traces){
        $self->newval ($s,"$_$count",$t->{$_}) foreach keys %$t;
        $count++;
    }

}

sub hist2trace {
	my $self = shift;
	my %args = @_;
	my $hist = $args{hist};
	my $labs = $args{labels};

	## This trace is confusing, but its what ends in the ini file
	my $trace = $args{trace} || 'bar';

	my @xlab = ();
	my @dat = ();
	my $cases = undef;

	foreach my $val (sort {$a <=> $b} keys %$labs ){
		push @xlab,$labs->{$val};
		my $dat = $hist->{$val} || 0;
		push @dat,$dat;
	}
	s/,/ /g foreach @xlab;
	return {trace=>$trace,data=>join(',',@dat),cases=>sum(@dat)},join ',',@xlab;
}

sub sanity_logging {
	# Just some stuff that logs what it going on.  Saves a few lines in the callers.
	my $self = shift;
	my %args = @_;
	my $e = $args{err} or new TPerl::Error;
	my $ini_sec = $args{ini_sec};
	my $ini_fn = $args{ini_fn};
	
	if (-f $ini_fn){
		$self->SetFileName($ini_fn);
		if ($self->ReadConfig){
			if ($self->SectionExists($ini_sec)){
				$e->I("Using [$ini_sec] in '$ini_fn' for extra messages");
			}else{
				$e->I("No [$ini_sec] in '$ini_fn'");
			}
		}else{
			$e->E("Could not open $ini_fn as an ini file");
		}
	}else{
		$e->I("'$ini_fn' does not exist");
	}
}

1;
