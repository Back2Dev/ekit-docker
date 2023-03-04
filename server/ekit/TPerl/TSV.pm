####Copyright Triton Technology 2002
####$Id: TSV.pm,v 2.44 2010-09-13 05:25:27 triton Exp $
package TPerl::TSV;
use strict;
use File::Temp qw(tempfile);
use Carp qw(confess);
use FileHandle;
use Data::Dumper;
use Text::CSV_XS;
use TPerl::DBEasy;
use Data::Dump qw(dump);
use HTML::PullParser;
use File::Basename;

=head 1 SYNOPSIS

Deal with Tab separated files.  Skip lines that are blank or begin with \s*#

 use TPerl::TSV;
 use Data::Dumper;
 my $file = '/path/to/some/file';
 my $tsv = new TPerl::TSV (file=>$file,nocase=>1,dbhead=>1);
 while (my $row = $tsv->row ){
  # $row keys are the elements from the first line
  # they are UPPERCASE if nocase is true.
  # values are the values from the bottom line
 }
 
 # Check if the loop stopped because of an error
 # rather than running out of data.
 die 'An Error occured '.$tsv->err if $tsv->err;

Or maybe your TSV file is really a CSV file.
pass csv_args use Text::CSV_XS
 
 my $tsv = new TPerl::TSV (csv_args=>{binary=>1});
 my $csv = $tsv->csv

Or maybe you're files dont have headers, supply one to use instead.

 my $tsv= new TPerl::TSV(header=>[qw(name address goose)],nocase=>1);


## Get column data

 # get all the data from column ID and NAME
 my $data =  $tsv->columns(names=>[qw( ID NAME)]);
 my @IDS = @{ $data->{ID} };

 #average , sum and count?
 my $data1 = $tsv->columns(names=>['q13x4'],op=>'avg');
 my $avg = $data1->{q13x4}->{avg};

 ## avg implies sum, sum implies count.
 my $count = $data1->{q13x4}->{count};
 my $sum = $data1->{q13x4}->{sum};

 ## histogram? 
 #returns a hashref. Keys are the data that
 # occured.  Vals are the number of times

There are other methods too

 # reference to an array of the headings.
 print Dumper $tsv->header;

 # count of data rows read so far
 print $tsv->count,"\n";
 
 # the name of the file, or the filehandle
 $filename = $tsv->file;
 $fh = $tsv->fh

Data isn't rectangular ?
 - TSV automatically labels columns without column headings (NOTITLE1, NOTITLE2, etc.)
 - TSV automatically trims additional blank columns (outside the normal columns only)

Still need to deal with non-rectangular data:
 my $tsv = new TPerl::TSV (file=>$file,nocase=>1,dbhead=>1, notrectangular=>1);
 - this allows for odd shaped data, and simply passes it through

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
#	print "new\n";
#	print Dumper \%args;
	confess ('file is a required arg') unless $args{file} || $args{fh};
	$self->{fh} = $args{fh};
	
	my $rep = $args{replace};
	my $app = $args{append};

	$self->{replace_file} = $rep if $rep;
	$self->{append_file} = $app if $app;
	$self->{nocase} = 1 if $args{nocase};
	$self->{dbhead} = 1 if $args{dbhead};
	$self->{excelhead} = 1 if $args{excelhead};

	confess ("'replace' and 'append' cannot both be set") if $rep && $app;

	if ($args{file} =~ /csv$/i || $args{csv}){
		$args{csv_args} ||= {} 
	}elsif ($args{file} =~ /html?$/){
		$self->{html} = new HTML::PullParser(
			file=>$args{file},
			start=>'event, tagname, @attr',
			text=>'@{text}',
			end=>'event, tagname'
		);
	}else{
		$args{csv_args} ||= {sep_char=>"\t",quote_char=>undef,escape_char=>undef}
	}

	if (my $csvargs = $args{csv_args}){
		$csvargs->{binary} = 1 unless exists $csvargs->{binary};
		$self->{csv} = new Text::CSV_XS($csvargs);
	}

	$self->{header} = $args{header} if $args{header};

	$self->{file} = $args{file};
	return $self;
}

#
# Internal sub to do work for new
#
sub _new {
	my $self = shift;
	my %args = @_;
#	print "_new:\n";
#	print Dumper \%args;
	confess ('file is a required arg') unless $args{file} || $args{fh};
	$self->{fh} = $args{fh};
	
	my $rep = $args{replace};
	my $app = $args{append};

	$self->{replace_file} = $rep if $rep;
	$self->{append_file} = $app if $app;
	$self->{nocase} = 1 if $args{nocase};
	$self->{dbhead} = 1 if $args{dbhead};
	$self->{excelhead} = 1 if $args{excelhead};
	$self->{include_blankrows} = 1 if $args{include_blankrows};

	confess ("'replace' and 'append' cannot both be set") if $rep && $app;

	if ($args{file} =~ /csv$/i || $args{csv}){
		$args{csv_args} ||= {} 
	}elsif ($args{file} =~ /html?$/){
		$self->{html} = new HTML::PullParser(
			file=>$args{file},
			start=>'event, tagname, @attr',
			text=>'@{text}',
			end=>'event, tagname'
		);
	}else{
		$args{csv_args} ||= {sep_char=>"\t",quote_char=>undef,escape_char=>undef}
	}

	if (my $csvargs = $args{csv_args}){
		$csvargs->{binary} = 1 unless exists $csvargs->{binary};
		print "Opening csv file ".Dumper $csvargs if ($args{debug});
		$self->{csv} = new Text::CSV_XS($csvargs);
	}

	$self->{header} = $args{header} if $args{header};

	$self->{file} = $args{file};
	return $self;
}

#
# Method to open a TSV file, trying various formats... TSV, CSV, SCSV, PIPE
# Call with debug => 1 to get feedback as it tries different formats
#
sub try_new
	{
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	$self->{file} = $args{file};
# Make sure that we bring in any csvargs as supplied by the caller...
	my %csvargs = (eol=>"\015",escape_char=>undef, sep_char=>"\t");
	map {$csvargs{$_} = $args{csvargs}{$_}} (keys %{$args{csvargs}});
	my %tsvargs = (file=>$args{file}, nocase=>1, csv_args=>\%csvargs, dbhead=>1);
	if ($args{hdr})
		{
		my $header = $args{hdr};
		my @hdr = split(/[,;]/,$header);
		$tsvargs{header} = \@hdr;
		}
	my %ftypes = (TXT => "\t", CSV => ',', SCSV => ';', PIPE => '|');
#	my %ftypes = (TXT => "\t", );
	foreach my $key (keys %ftypes)
		{
# Need to remove header, cos otherwise it is assumed to be given
		$self->err("");
		$self->{header} = undef;
		print "Trying $key format [$ftypes{$key}]\n" if ($args{debug});
		$tsvargs{csv_args}{sep_char} = $ftypes{$key};
		if (($key =~ /^CSV$/i) || ($key =~ /^TXT$/i) )
			{
			$tsvargs{csv_args}{quote_char} = '"';
			}
		else
			{
			$tsvargs{csv_args}{quote_char} = qq{"};
			}
		$self->_new(%tsvargs);
#		print Dumper \%tsvargs;
		last if (($self->header) && (@{$self->header} > 1));
		}
	return $self;
	}

sub append {
	my $self = shift;
	return $self->_new (@_,append=>1);
}
sub replace {
	my $self = shift;
	return $self->new (@_,replace=>1);
}

## ro methods.
sub count { my $self = shift; return $self->{count}};
sub line { my $self = shift; return $self->{line}-1};
sub file { my $self = shift; return $self->{file}};
sub nocase { my $self = shift; return $self->{nocase}};
sub dbhead { my $self = shift; return $self->{dbhead}};
sub csv { my $self=shift; return $self->{csv}};
sub html { my $self=shift; return $self->{html}};

sub summary {
	my $self = shift;
	my %args = @_;
	my $hists = $args{hists};
	my $counts = $args{counts};
	my $means = $args{means};
}

sub columns {
	my $self = shift;
	my %args = @_;
	#my $cols = $args{names} || confess q{'names' is a required parameter};
	my $cols = $args{names} || $self->header;
	my $op = $args{op};
	my $limlo = $args{limlo};
	my $limhi = $args{limhi};
	my $groups = $args{groups};
	my $include_blanks = $args{include_blanks};
	my $ignore_missing = $args{ignore_missing};
	my $skip_zero = $args{skip_zero};

	if (($op ne 'thist') and $include_blanks){
		$self->err("Cannot 'include_blanks' if you are not doing a 'op=>thist'");
		return undef;
	}
	my $ret = {};
	my @missing=();
	my $head = $self->header;
	foreach my $col (@$cols){
		push @missing,$col unless grep $_ eq $col,@$head;
	}
	if (@missing){
		$self->err ('Column(s) ' .join (' ',@missing). ' do not exist in file '.$self->file);
		return undef unless $ignore_missing;
	}
	my $count =0;
	my $ez = new TPerl::DBEasy;
	while (my $row = $self->row){
		my $group_vals = {};
		if ($groups){
			#foreach row eval the value of the field
			foreach (keys %$groups){
				my $val = $ez->field2val(field=>$groups->{$_},row=>$row);
				$group_vals->{$_} = $val if $val ne '';
			}
			# print "Group vals ".dump ($group_vals) ."\n";
		}
		foreach my $col (@$cols){
			my $val = $row->{$col};
			next if $limlo and $val < $limlo;
			next if $limhi and $val > $limhi;
			if (grep lc $op eq $_, qw(sum avg) ){
				if ($groups){
					foreach (keys %$groups){
						$ret->{$col}->{$_}->{$group_vals->{$_}}->{sum}+=$val;
						$ret->{$col}->{$_}->{$group_vals->{$_}}->{count}++ if $val ne '';
					}
				}else{
					$ret->{$col}->{sum}+=$val;
					$ret->{$col}->{count}++ if $val ne '';
				}
			}elsif ( lc $op eq 'thist'){
				my $use = $include_blanks || ($val ne '');
				$use = 0 if $skip_zero && $val eq '0';
				if ($groups){
					foreach ( keys %$groups ){
							next if $group_vals->{$_} eq '';
						$ret->{$col}->{$_}->{$group_vals->{$_}}->{$val}++ if $use;
					}
				}else{
					$ret->{$col}->{$val}++ if $use;
				}
			}elsif ( lc $op eq 'hist'){
				if ($groups){
					foreach (keys %$groups){
						$ret->{$col}->{$_}->{$group_vals->{$_}}->{$val}++ if $val =~ /^\d+$/;
					}
				}else{
					$ret->{$col}->{$val}++ if $val =~ /^\d+$/;
				}
			}else{
				if ($groups){
					push @{$ret->{$col}->{$_}->{$group_vals->{$_}}},$val foreach keys %$groups;
				}else{
					push @{$ret->{$col}},$val;
				}
			}
		}
		# last if $count++ >100;
	}
	return undef if $self->err();
	return undef unless %$ret;
	if (lc $op eq 'avg'){
		foreach my $col (@$cols){
			if ($groups){
				foreach my $gn (keys %$groups){
					foreach my $g (keys %{$ret->{$col}->{$gn}}){
						my $ghsh = $ret->{$col}->{$gn}->{$g};
						# print "$col $gn $g".Dumper $ghsh;
						foreach my $g (keys %$ghsh){
							$ghsh->{avg} = $ghsh->{sum}/$ghsh->{count} if $ghsh->{count};
						}
					}
				}
			}else{
				$ret->{$col}->{avg} = $ret->{$col}->{sum} / $ret->{$col}->{count} if $ret->{$col}->{count};
				# print "avg for $col $ret->{$col}->{avg}\n";
			}
		}
	}
	return $ret;
}

sub row {
	my $self = shift;
	return undef unless my $head = $self->header;
	if (my $line = $self->_good_line() ){
		if (@$line > @$head){		# Try and fix it by killing trailing blanks
			my $k=scalar(@$line)-1;
			while ($k > @$head-1) {		
				$line->[$k] =~ s/^\s+$//g;
				if ($line->[$k] eq ''){
					delete ($line->[$k]);
#					print "(killed  $k)\n";
				} else {last;} 		# Jump out if we hit something real - that is still a problem...
				$k--;
			}
		}
		if (@$line > @$head){		# Is it still too wide ? (I think we can live with it being too narrow)
			push @{$self->{mismatches}},{row=>$self->{count},heads=>scalar(@$head),fields=>scalar(@$line),line=>$line};
			return $self->row;
		}
		my %line = ();
		@line{@$head}=@$line;
		$self->{count}++;
		return \%line;
	}else{
		if (my $list = $self->{mismatches}){
			$self->err(sprintf("Expected %d fields per row. Skipped %d records with ",scalar(@$head),scalar(@$list)).
				join ",",map "$_->{fields} after row $_->{row} '@{$_->{line}}'",@$list)
		}
		return undef;
	}
}

sub header_hash {
	my $self=shift;
	my $head = $self->header || return undef;
	my $hash = {};
	$hash->{$_}++ foreach @$head;
	return $hash;
}

sub header {
	my $self = shift;
	return $self->{header} if $self->{header};
	if (my $line = $self->_good_line ){
		if ($self->{excelhead}){
			if ($#$line > 256){
				$self->err("More than 256 columns not handled yet");
				return undef;
			}
			my $c1 = '';	
			for (my $i=0;$i <= $#$line;$i++){
				my $j = $i % 26;
				$c1 = chr(64+int($i/26)) if ($i>25);
				$line->[$i] = $c1 . chr (65+$j);
			}
			undef $self->{fh};
		}
		s/^\s*(.*?)\s*$/$1/ foreach @$line;
		my @orig_head = map $_,@$line;
		if ($self->nocase){
			$_ = uc($_) foreach @$line;
		}
		if ($self->dbhead){
			my $dup = {};
			foreach (@$line){
				 # print "dbhead|$_|\n";
				# These few are from the iprocess output, and kill firebird.
				$_ = 'NOTITLE' if $_ eq '';
				$_ = 'YEARNO' if $_ eq 'YEAR';
				$_ = 'MONTHNO' if $_ eq 'MONTH';
				$_ = 'DAYNO' if $_ eq 'DAY';
				$_ = 'WEEKDAY_NAME' if $_ eq 'WEEKDAY';
				$_ = 'HOURNO' if $_ eq 'HOUR';
				$_ = 'MINNO' if $_ eq 'MIN';
	
				# General fixes.
				s/\s+/_/g;
				s/\$/DOLLARS/g;
				s/\%/PERCENT/g;
				s/\W//g;
				s/_+$//g;	# Trim trailing _'s
				s/^_+//g;	# Trim leading _'s
				# print Dumper ($dup) if $_ eq 'CODE';
				if (my $end = $dup->{$_}){
					$dup->{$_}++;
					$_ .=  $end;
					# print "Dup $_";
				}else{
					$dup->{$_}++;
				}
			}
		}
		my %orig_head_hash = ();
		@orig_head_hash{@$line}=@orig_head;
		$self->{original_header_names} = \%orig_head_hash;
		$self->{header} = $line;
		return $self->{header};
	}else{
		$self->err("no header in $self->{file}") unless $self->err;
		return undef;
	}
}

sub original_header_names{
	my $self  = shift;
	my $head = $self->header || return undef;
	return $self->{original_header_names};
}

sub _good_line {
	# internal sub for getting non comment non blank lines
	# now it splits the line too.
	# returns undef on failure
	
	my $self = shift;
	return undef unless my $fh = $self->fh;
	if (my $csv = $self->csv){
		$self->{line}++;
		if (my $ref = $csv->getline($fh)){
			return undef unless @$ref;				# Detects EOF
			if ($ref->[0] =~ /^\s*$/ && @$ref ==1)
				{
				return $self->_good_line() if $self->{include_blankrows};
				}
			return $ref
		}else{
			$self->err("CSV parser error with '$_'") if $_=$csv->error_input();
			return undef
		}
	}elsif (my $p = $self->html()){
		my @cells = ();
		my $text = '';
		while (my $t = $p->get_token){
			# print Dumper $t;
			if (ref $t){
				my $start=1 if $t->[0] eq 'start';
				my $tag = $t->[1];
				$tag = 'td' if $tag eq 'th';
				if (!$start && $tag eq 'tr'){
					if (@cells){
						s/[\t]+/ /g foreach @cells;
						s/[\r\n\xA0]+//g foreach @cells;
						# print Dumper \@cells;
						return \@cells;
					}
				}
				if (!$start && $tag eq 'td'){
					push @cells,$text;
					$text = '';
				}
				if ($start){
					# print "start $tag\n";
					$p->{inside}->{$tag}++;
				}else{
					# print "end $tag\n";
					$p->{inside}->{$tag}--;
				}
			}else{
				$text .= $t if $p->{inside}->{td};
				# print "text='$text'\n";
			}
		}
		# print "Here".Dumper $p;
		return undef;
	}else{
		while (my $line = <$fh>){
				$self->{line}++;
				chomp $line;
				$line =~ s/\r$//;
				next if $line =~ /^\s*#/;
				next if ($line =~ /^\s*$/) && !$self->{include_blankrows};
				return [split /\t/,$line];
		}
	}
	return  undef;
}

sub fh {
	my $self = shift;
	return $self->{fh} if $self->{fh};
	my $file = $self->file;
	my $mod = '';
	if ($self->{append_file}){
		 die "append not implemented yet";
	}
	if ($self->{replace_file}){
		$mod = ">";
	}
	if (my $fh = new FileHandle ("$mod $file")){
		$self->{fh} = $fh;
		return $fh;
	}else{
		$self->err("Could not open file $mod '$file':$!");
		return undef;
	}

}
sub err {
	my $self = shift;
	return $self->{err} = $_[0] if @_;
	return $self->{err};
}
sub reset {
	my $self = shift;
	$self->{err}=undef;
	$self->{fh} = undef;
	$self->{header} = undef;
	$self->{count} = undef;
}

sub edit_to_temp {
	my $self = shift;
	my %args = @_;

	my $callbacks = $args{callbacks};
	my $tmp_args = {UNLINK=>0};
	if (my $f = $args{file}){
		my  ($name,$path,$suffix) = fileparse($f);
		$tmp_args->{DIR} = $path;
		$tmp_args->{TEMPLATE} = $name;
	}
	$tmp_args->{DIR} = $args{dir} if $args{dir};

	$callbacks = [$callbacks] if ref $callbacks eq 'HASH';
	my $tmp = new File::Temp(%$tmp_args);

	my $head = $self->header || return undef;
	my $orig = $self->original_header_names;

	my $csv = $self->csv;
	unless ($csv){
		die Dumper ($self);
		$self->err("Can't get csv.  This should not happen".Dumper($self));
		return undef;
	}


	$csv->print( $tmp,[map $orig->{$_},@$head]);
	print $tmp "\n";
	
	while (my $row = $self->row){
		foreach my $cb (@$callbacks){
			my $action = undef;
			if (ref($cb) eq 'HASH'){
				$action = $cb->{action} 
			}elsif (ref($cb) eq 'CODE'){
				$action = $cb;
				$row = &$action ($row);
			}else{
				die "Should not have happened"
			}
			$row = &$action($row);
			## Leave room for a delete..
		}
		# If the callbacks return undef, we leave this row out of the new file.
		next unless defined ($row);
		my @cols = map $row->{$_},@$head;
		$csv->print($tmp,\@cols);
		print $tmp "\n";
	}
	return undef if  $self->err;
	$tmp->close;
	return $tmp->filename;
}
1;
