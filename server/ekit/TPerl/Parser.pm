#$Id: Parser.pm,v 2.69 2011-08-30 02:17:20 triton Exp $
package TPerl::Parser;
	##########################################################################
	##
	## Parser Modules
	##
	## Copyright Triton Information Technology 2001, All rights reserved
	##
	##########################################################################
use strict;
use Data::Dumper;
use File::Slurp;
use FileHandle;
use Text::Balanced qw (extract_bracketed);
use File::Copy;
use File::Temp qw (tempdir tempfile);
use File::Temp qw (:mktemp);
use File::Basename;
use File::Path;
use Carp qw (confess);
use Data::Dump qw (dump);
use IO::Scalar;

use TPerl::Text::Quote;
use TPerl::Parser::Chunk;
use TPerl::Lookup qw (question_type_number qt_match);
use TPerl::Error;
use TPerl::TritonConfig qw (getConfig);
# use Config::IniFiles;
use TPerl::ConfigIniFiles;
use TPerl::Survey::Question;
use TPerl::Survey;
use TPerl::Dump;

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my %args = @_;
	$self->{_error} = $args{err} || new TPerl::Error (fh=>$args{err_fh}) ;
	return $self;
}

=head2 parser_filename

	this returns the parser filename. 

=cut

sub parser_filename {
	my $self = shift;
	my %args = @_;
	my $survey = $args{survey};
	my ($root,$config);
	if ($survey){
		$root = $survey->TR;
		# $config = $survey->config_subdir;
	}
	$root ||= $args{TritonRoot} || getConfig('TritonRoot');
	$config ||= $args{config_subdir} || 'config';
	my $name = $args{SID};
	confess "SID is a required param" unless $name;
	my $file = undef;
	foreach ('.txt','.TXT'){
		my $tfile = join '/',$root,$name,$config,"$name$_";
		if (-e $tfile){
			$file = $tfile;
			last;
		}
	}
	return $file;
}

sub chunks {
	my $self = shift;
	return $self->{_chunks};
}

sub err {
	my $self = shift;
	return $self->{_error};
}


sub parse {	
	my $self = shift;
	my %args = @_;
	my $debug = $args{debug};
	# $debug=1;

	my $file = $args{file} ;
	confess "file is a required arg" unless $file;
	if (my $fh = new FileHandle ("< $file") ){

		my @chunks = ();
		my $rules = $self->chunk_rules(parse=>1);
		my $current_chunk = [];
		my @Qstems;
		my $count = 0;
		while (my $line = <$fh> ){
			chomp $line;
			$line =~ s/\r$//;
			$line =~ s/(.*?)\s*$/$1/;
			$count++;
			# --------------------------------------------------------------
			# description: looks for duplicate question stems and returns a warning
			# author: jello
			# date: 4/28/2011
			# revision: 1
			# --------------------------------------------------------------
			if ($line =~ /^\s*Q\s*/) {
				my $q_stem = $line;
				$q_stem =~ s/^\s*Q\s*.\.//;
				#print "question stem: $q_stem \n";
				if (is_in($q_stem,@Qstems)) {
					#print "This question stem is being used in a previous question: $line";
					$self->err->W("PRIORITY WARNING!!! This question stem is being used in a previous question: $line");
				} else {
					push(@Qstems,$q_stem);
				}
			}
			# -END----------------------------------------------------------			
			foreach my $rule (@$rules){
				if ($line =~ /$rule->{identify}/ ){
					if ($rule->{new_chunk}){
						my @last_chunk = @$current_chunk;
						push @chunks,\@last_chunk;
						$current_chunk = [];
					}
					$line =~ s/($rule->{identify})// if $rule->{clean};
					my $type = $rule->{name};
					my $ob = {line=>$line,number=>$count,type=>$type};
					$ob->{clean} = $1 if $rule->{clean};
					push @$current_chunk,$ob;
					last;
				}
			}
		}
		### who could forget the lucky last.
		push @chunks,$current_chunk;
		
		# turn the chunks into chunk objects to give em numbers and stuff
		$count=0;
		foreach my $lines (@chunks){
			my $chunk = new TPerl::Parser::Chunk (
					lines=>$lines,
					number=>$count++,
					file=>$file,
					type=>$lines->[0]->{type},
				);
			push @{$self->{_chunks}},$chunk;
			$chunk->orphan_warnings(err=>$self->err);
		}
		print 'Parser before expand '.Dumper $self if $debug;
		my $repeats = $self->expand_repeats;
		print 'Parser after expand '.Dumper $self if $debug;
		### put the label in each lines object.
		my $current_label = undef;
		$count = 0;
		foreach my $chunk (@{$self->chunks}){
			$current_label = $chunk->qlabel(label=>1) if $chunk->type eq 'question';
			$chunk->number($count++);
			foreach my $line (@{$chunk->lines}){
				$line->{label} = $current_label;
			}
		}
		###check for duplicate qlabels.
		if ($repeats){
			my ($name,$path,$suffix) = fileparse($file,'\.txt');
			my $efile = $name.'_Expanded'.$suffix;
			$efile = $path.$efile if $path;
			my $efh = new FileHandle ("> $efile") or $self->err->F("Could not open '$efile' for writing:$!");
			$self->err->I("Writing file '$efile'");
			$_->as_src (fh=>$efh) foreach @{$self->chunks};
		}
		return {repeats => $repeats};
	}else{
		$self->err->E ("Could not open file $file for parsing");
	}
}

# sub question_chunks {
# 	my $self = shift;
# 	return $self->{_qchunks};
# }
sub expand_repeats {
	#my $self = shift;
	#my %args = shift;
	my $self = $_[0];
	my %args = ();
	if ($_[1]) {
		%args = $_[1];
	}

	my $found_repeat = 0; #track the number of repeaters we find

	### this process changes the number of chunks in the survey, so 
	## we can't use 'normal' array traversing
	for (my $cnum=0;$cnum<=$#{$self->chunks};$cnum++){
		my $q = $self->chunks->[$cnum];
		# print "found chunk $cnum\n";
		next unless ($q->type eq 'question');
		# print "er found chunk $cnum label ".$q->qlabel(label=>1) ."\n";
		next unless (qt_match($q->options(opt=>'qtype')) == qt_match('repeater'));

		$found_repeat++;
		my $nrepeat = $q->options(opt=>'nrepeat');
		my $thing_rep = $q->options(opt=>'mask_include');
		my $rep_until = $q->options(opt=>'repeat_until');
		my $rlabel = $q->qlabel(label=>1); # label of the repeater question.
		my $random_repeats = $q->options(opt=>'random_repeats');
		

		$self->_line_error (msg=>"No +nrepeat or +repeat_until", line=>$q->lines->[0]) unless $nrepeat || $rep_until;
		my $loop_var = uc $q->options(opt=>'loopvar');
		
		my @newlist = ();  # this is the list of new chunks..

		# how many times can we go through this?
		my $attribs = $self->chunk_filter (start_num=>$q->number,look_type=>'attribute',end_type=>'question');
		my $repeats = scalar @$attribs;


		### now things get messy.  we are going to clobber a section of the array forward of where $cnum points
		### first we find out how much to clobber, and collect some of it to copy and replicate

		my $replace_start = undef;  #where to splice the mangled chunks into the original list
		my $replace = [];  # The list of chunks to mangle
		my $rqlabels = {}; # which labels are in the mangle group and need modifying in skips.

		my $rep_qnum = -1; # keep track of how many questions we have seen
		my $chunksb4rep = 0; # the number of chunks in the actual repeat group itsself
		my $made_automask_question = 0;  

		if ($rep_until){
			my $qnumb = -1;
			my $rep_found;
			for (my $i=$cnum;$i<=$#{$self->chunks};$i++){
				my $ch = $self->chunks->[$i];
				if ($ch->type eq 'question'){
					$qnumb++;
					if ( uc($ch->qlabel(label=>1)) eq uc($rep_until)){
						$self->_line_warn (msg=>"Ignoring +nrepeat=$nrepeat in favour of $qnumb", line=>$q->lines->[0]) if $nrepeat and ($nrepeat != $qnumb);
						$nrepeat = $qnumb;
						# print "Setting nrepeat to $nrepeat\n";
						$rep_found++;
						last;
					}
				}
			}
			$self->_line_error (msg=>"Could not find question +repeat_until=$rep_until", line=>$q->lines->[0]) unless $rep_found;
		}
		
		unless ($thing_rep){
			### if they do not specify a mask lets make one and fill it with the attributes of this question.
			# $self->_line_error (msg=>"no +mask_include", line=>$q->lines->[0]) unless $thing_rep;
			$thing_rep = "automask_$rlabel";
			my @masktext = (
				qq{Q $rlabel. auto generate and fill a mask},
				'+qtype=multi',
				"+autoselect=$repeats",
				"+mask_reset=$thing_rep",
				"+mask_update=$thing_rep",
				map ("A ".$_->lines->[0]->{line},@$attribs),
			);
			# print Dumper \@masktext;
			my $maskparser = $self->text2parser( join "\n\t",@masktext);
			push @newlist,@{$maskparser->chunks};
			$made_automask_question++;
		}
		if ($random_repeats){
			$self->err->F("Does not work unless made_automask_question") unless $made_automask_question;
			my $jlist = [];
			@$jlist = map qq{'${rlabel}_R$_'} , 1..$repeats;
			my @rep_text = (
				qq{},
				qq{ Q ${rlabel}_zz1 build a skip mask		},
				q{+qtype=perl_code},
				q{C  my $jumps = [ }.join (',',@$jlist) . '];',
				qq{C  my \$af = '${rlabel}_zzz_FIN';		},
				qq{C  my \$msk_name = 'zz_${rlabel}_zz1';		},
				q#C  unless ($resp{"mask_$msk_name"}){		#,
				q{C        my @msk = ();		},
				q{C        my $already = {};		},
				q{C        my $length=@$jumps;		},
				q#C         while (@msk < $length){		#,
				q{C             my $not_chosen = $length - @msk;		},
				q{C             my $rand = int(rand($not_chosen));		},
				q#C             while ($already->{$rand}) {		#,
				q{C                 $rand++;		},
				q{C                 $rand=0 if $rand >= $length;		},
				q#C             }		#,
				q{C             push @msk,$rand;		},
				q#C             $already->{$rand}++;		#,
				q#C         }		#,
				q{C        # use Data::Dumper; print "length= $length mask=". Dumper \@msk;		},
				q#C        $resp{"mask_$msk_name"} = join $array_sep,@msk;		#,
				q{C        push @$jumps,$af;		},
				q#C        my $next = {};		#,
				q#C        $next->{$msk[$_]} = $jumps->[$msk[$_+1]] foreach (0..$length-1);		#,
				q#C        $next->{$msk[-1]} = $jumps->[$length];		#,
				q#C        $resp{"maskt_$msk_name"} = join $array_sep,@$jumps;		#,
				qq#C        setvar ('${rlabel}_zz_jumps_hash', join \$array_sep, \%\$next);		#,
				q#C  }		#,
				q{C  ## Now the code to jump to the first one.		},
				q{C  # use Data::Dumper; print 'jumps '.Dumper $jumps;		},
				q#C my @msk = split /$array_sep/,$resp{"mask_$msk_name"};		#,
				q{C # use Data::Dumper; print 'msk '.Dumper \@msk;		},
				q#C $q_no = goto_qlab($jumps->[$msk[0]])-1		#,
			);
			# print Dumper \@rep_text;
			my $maskparser = $self->text2parser( join "\n",@rep_text);
			push @newlist,@{$maskparser->chunks};
		}
	
		my $lastrepq = undef;  # to get a qlabel you need to remember the last chunk that is a question, not look in the last chunk.
		for (my $i=$cnum;$i<=$#{$self->chunks};$i++){
			my $ch = $self->chunks->[$i];
			if ($ch->type eq 'question'){
				$rep_qnum++;
				$replace_start = $i if $rep_qnum ==0;
				$rqlabels->{uc $ch->qlabel(label=>1)}++ if $rep_qnum >0 and $rep_qnum <= $nrepeat;
				$lastrepq=$ch if $rep_qnum <= $nrepeat;
			}
			$chunksb4rep++ if $rep_qnum <1;
			last if $rep_qnum > $nrepeat;
			push @$replace,$ch if $rep_qnum>0;
		}
		# print "chunksb4rep=$chunksb4rep\n";
		# print 'these labels are in the repeat group '.Dumper $rqlabels;
		# print 'These are the replace chunks '.Dumper $replace;
		my $last_qlab = $lastrepq->qlabel(label=>1); # replace->[-1]->qlabel(label=>1) ;
		$self->err->I("Found $rlabel a repeater with $repeats Repeats and $nrepeat questions finishing after $last_qlab");
		$self->err->I("Using $loop_var as the zero based loop variable") if $loop_var;
		$self->err->I("Randomising repeats") if $random_repeats;

		#### build a new parser object with just the rereat group chunks and then run the variable usage function on it
		# thinks variable usage should be in its own module???....
		my $upout = undef;
		my $upoutfh = new IO::Scalar \$upout;
		my $useparser = $self->new(err_fh=>$upoutfh);
		$useparser->{_chunks} = $replace;
		my $rusage = $useparser->variable_usage();
		# $self->err->D ('Repeater var usage '.Dumper $rusage);

		#now copy the chunks, mangle them and stick them on the new list
		my $thingrex = qr{\$\$repeat_thing}i;
		my $next_ext; #need this outside loop
		# print "Usage Vars in this loop ". Dumper $rusage->{assign};
		delete $rusage->{assign}->{$loop_var} if $loop_var;
		for (my $rep=1;$rep<=$repeats;$rep++){
			my $label_ext = "_R$rep";
			$next_ext = '_R'.($rep+1);
			## initial eval
			my $e_label = $rlabel . $label_ext;
			$e_label = $rlabel if $rep == 1 && !$made_automask_question; # the label of the first eval is the repeat grounp label
			my $mask_index = $rep-1;
			# $self->err->I("starting repeat group $rep with question $e_label");
			my $evalp = $self->text2parser ( 	join "\n", (
				qq{Q $e_label. Ask block of $nrepeat for \#$rep of $repeats},
				qq{\t+qtype=code},
				qq{C	if (!ismask('$thing_rep',$mask_index)) goto $rlabel$next_ext},'# '
			));
			# print 'Eval chunks '.Dumper $evalp->chunks;
			push @newlist,@{$evalp->chunks};
			if ($loop_var){
				my $loop_var_val = $rep -1;
				my $evalloop = $self->text2parser ( 	join "\n", 
					qq{Q ${rlabel}_LoopSet$label_ext. set the loop variable },
					qq{+qtype=perl_code},
					qq{C	setvar('$loop_var',$loop_var_val);},'','',
				);
				push @newlist,@{$evalloop->chunks};
			}
			## originals
			my $select_vars = {};
			foreach my $orig (@$replace){
				my $new = eval dump $orig;
				### mangle prompt and label.
				my $in = $rep-1;
				my $expthing = qq{\$\$$thing_rep\[$in\]};
				if ($new->type eq 'question'){
					my $la = $new->qlabel(label=>1).$label_ext;
					my $pr = $new->qlabel(prompt=>1);
					$pr =~ s/$thingrex/$expthing/g;
					$new->qlabel (new_prompt=>$pr,new_label=>$la);
					$select_vars->{$_}++ if $_ = uc $new->options(opt=>'selectvar');
					# mangle +varname
					if (my $vn = $new->options(opt=>'varname')){
						$new->replace_options(new=>{varname=>$vn.$label_ext});
					}
				}
				
				# mangle skips;
				if (my $skip = uc $new->options(opt=>'skip')){
					# print "skip=$skip|\n";
					## only replace the skips if the skip is internal
					$new->replace_options (new=>{skip=>$skip.$label_ext}) if 
						$rqlabels->{$skip};
				}
				### now replace any other stray $$repeat_thing or vars defined in the repeat group
				# print Dumper $new;

				#HACK for WUS102J don;t expand A lines with a +section
				my $section = $new->options(opt=>'section');
				# print "Found $section in ".Dumper $new if $section;

				foreach my $line (@{$new->lines}){
					next if grep $line->{type} eq $_,qw(leftovers grid_pulldown comment );
					# print "LINE=$line->{line}\n" if $line->{line} =~ /make a lot of careless mistakes in school work/;
					my $mat = 0;
					#### \b won't match cause there is no \w on either side.  see perldoc perlre.
					$mat += $line->{line} =~ s/(\W)$thingrex(\b)/$1$expthing$2/g;
					# print "thingrex = $thingrex\n";
					# print "$thingrex|LINE=$line->{line}\n" if $line->{line} =~ /make a lot of careless mistakes in school work/;
					###now mangle any vars that are assigned to in the repeat group.
					foreach my $var (keys %{$rusage->{assign}}){
						next if grep $var eq $_,qw(Q_LABEL QLAB SURVEY_ID);
						next if $section && (uc($var) eq uc($section));
						my $rex = quotemeta $var;
						my $varrep = $var.$label_ext;
						if ($line->{type} eq 'question'){
							#force use of $$var in prompts.
							$rex = '\$\$'.$rex if $line->{type} eq 'question'; 
							$varrep = '$$'.$varrep;
						}
						foreach my $selvar (keys %$select_vars){
							if ($var =~ /^$selvar(_\d+)$/i){
								$varrep = $selvar.$label_ext.$1;
								# print "<BR>REX=$rex|VARREP=$varrep\n";
							}
						}
						#print "B4$rex|$line->{line}\n" if $var eq 'CHILDAGE';
						# \b matches empthy space at the start of a string.  this is good.
						my $mat += $line->{line} =~ s/(\b)$rex(\b)/$1$varrep$2/ig;
						# but \b does not match at $$goose because there is nary a \w on either side.  \b in a character class is a backspace
						$mat += $line->{line} =~ s/(\W)$rex(\b)/$1$varrep$2/ig;
						# my $orex = qr{<%\s*$var\s*%>};
						# $mat += $line->{line} =~ s/$orex/$varrep/ig;
						# print "AF$orex|$line->{line}\n" if $var eq 'P_EVENT';
					}
					foreach my $lab (keys %$rqlabels){
						next if $section && (uc($lab) eq uc($section));
						my $rex = quotemeta $lab;
						my $labrep = $lab.$label_ext;
						$mat += $line->{line} =~ s/(\b)$rex(\b)/$labrep/ig;
					}
					# print "<BR>AFTER $line->{line}\n" if $mat;
				}
				push @newlist,$new;
			}
			if ($random_repeats){
				my $lv = $rep-1;
				my @skip_text = (
					qq{Q ${rlabel}_post_$rep jump to the next random one....},
					q{+qtype=perl_code},
					qq{C my \$pos = $lv;},
					qq{C my \%next = split /\$array_sep/,getvar('${rlabel}_zz_jumps_hash');},
					q#C $lab = $next{$pos};#,
					q{C $q_no = goto_qlab($lab)-1;},

				);
				# print Dumper \@rep_text;
				my $maskparser = $self->text2parser( join "\n",@skip_text);
				push @newlist,@{$maskparser->chunks};
				
			}
		}
		## add the last eval target to the list
		my $targparser = $self->text2parser( qq{Q $rlabel$next_ext. End of repeat loop expansion\n\t+qtype=eval\n\n});
		push @newlist,@{$targparser->chunks};
		# print Dumper \@newlist;
		if ($random_repeats){
			my @end_rand_text = (
				qq{Q ${rlabel}_zzz_FIN. this is where the last random jump jumps too.},
				'+qtype=eval',
				'',
			);
			my $targparser = $self->text2parser(join "\n",@end_rand_text);
			push @newlist,@{$targparser->chunks};
	
		}

		#slice the new list into the big list.
		splice @{$self->chunks},$replace_start,$chunksb4rep+@$replace,@newlist;
		# and renumber the chunks, so that chunks
		my $ncount = 0;
		$_->number ($ncount++) foreach @{$self->chunks()};
		# print Dumper \@newlist
	}
	return $found_repeat;
}
sub text2parser {
	## sort of a contructor..
	my $self = shift;
	my $text = shift;

	my $td = tempdir(CLEANUP=>1);

	my $tfile = mktemp("$td/parsXXXXXXX");
	# print "tfile=$tfile\n";
	write_file ($tfile,$text) || $self->err->E("Could not write temp file to parse $text");
	# print "________\n$text\n_______\n";
	my $upout = undef;
	my $upoutfh = new IO::Scalar \$upout;
	my $useparser = $self->new(err_fh=>$upoutfh);
	my $ep= $self->new(err_fh=>$upoutfh);
	# print 'New Parser '.Dumper $ep;
	# print 'Empty new Parser chunks '.Dumper $ep->chunks;
	$ep->parse(file=>$tfile,debug=>0);
	return $ep;
}
sub _line_warn{
	my $self = shift;
	my %args = @_;
	my $line = $args{line};
	my $msg = $args{msg};
	my $fh = $args{fh} || \*STDOUT;

	my $tline = $line->{line};
	$tline =~ s/^\s+//;
	$self->err->W("$msg\n\t$line->{number}: $tline");
	# print $fh "[W] $msg\n\t$line->{number}: $tline\n";
}
sub _line_info{
	my $self = shift;
	my %args = @_;
	my $line = $args{line};
	my $msg = $args{msg};
	my $fh = $args{fh} || \*STDOUT;

	$self->{_err}->{I}->{count}++;

	my $tline = $line->{line};
	$tline =~ s/^\s+//;
	$self->err->I("$msg\n\t$line->{number}: $tline");
}
sub _line_error{
	my $self = shift;
	my %args = @_;
	my $line = $args{line};
	my $msg = $args{msg};
	my $fh = $args{fh} || \*STDOUT;

	$self->{_err}->{E}->{count}++;

	my $tline = $line->{line};
	$tline =~ s/^\s+//;
	$self->err->E("$msg\n\t$line->{number}: $tline");
}
=head2 cvs_import

my $err = $parser->cvs_import(files=>['file','other_file'],cvsroot=>'/some/cvs/root');

=cut

sub cvs_import {
    my $self = shift;
    my %args = @_;
    my $cvsroot = $args{cvsroot};
    my $files_arg = $args{files} || [];
    my $module = $args{module} || 'Surveys';
    my $comment = $args{comment} || scalar (localtime);
	my $dir = $args{dir};

    $comment =~ s/'//g;

	my $files = $files_arg if ref $files_arg eq 'ARRAY';
	$files = [keys %$files_arg] if ref $files_arg eq 'HASH';

    # confess "need a cvsroot" unless $cvsroot;
    my $tempdir = tempdir (CLEANUP=>1);
	if ($dir && ! scalar(@$files)){
		return "Could not read from $dir" unless -d $dir;
		my @files =  read_dir($dir);
		$_ = "$dir/$_" foreach @files;
		@files = grep -f $_,@files;
		$files = \@files;
	}
    foreach my $file (@$files){
		my $new_name;
		if (ref $files_arg eq 'HASH'){
			$new_name = $files_arg->{$file};
			my ($name,$path,$suffix) = fileparse($new_name);
			# print "path=$path $name\n";
			mkpath ("$tempdir/$path") if $path;
		}
        return "Could not copy $file to $tempdir:$!" unless copy $file,"$tempdir/$new_name";
    }
	return "No cvsroot supplied" unless $cvsroot;
    my $cmd = "cvs -d $cvsroot import -m '$comment' $module triton ASPimport";
    my $exec = execute TPerl::CmdLine (cmd=>$cmd,dir=>$tempdir);
    return $exec->output unless $exec->success;
    return undef;
}

# sub usage make this easier to search for...
sub variable_usage {
	my $self = shift;
	my %args = @_;

	my $vars = $args{variables};
	my $allvars = $args{allvars};
	my $ignore = $args{ignore};
	my $ext_info = $args{external_info};
	
	# print "External_info =".Dumper $ext_info;
	my $assign_warnings = 1 unless $args{no_assign_warnings};

	my $uses = {};	###keep track of the uses of a variable
	my $assign= {};	###keep ytrack of assignments
	my $defined_qlabels={};		###defined variable are implicit assigns, but should not be warned about
	my $warned_vars = {};	## only give one warning about a var


	$warned_vars->{uc($_)} = 1 foreach @$ignore;
	# print "Ignoreing ".Dumper ($ignore).Dumper $warned_vars;

	# print Dumper $warned_vars;

	## the parsing results of chunks of different kinds
	my $groups = $self->question_groups;
	# print scalar (@$groups) . " Groups\n";
	#
	
	###Now some 'global' implicit vars.
	push @{$assign->{Q_LABEL}},{val=>'QuestLabel',label=>'Engine',implicit=>1};
	push @{$assign->{QLAB}},{val=>'QLab',label=>'Engine',implicit=>1};
 	push @{$assign->{SURVEY_ID}},{val=>'SurveyID',label=>'Engine',implicit=>1};
 	push @{$assign->{SEQNO}},{val=>'SurveyID',label=>'Engine',implicit=>1};
	foreach my $group (@{$self->question_groups}){
		my $chunk = $group->[0];
		#we are interested in question chunks.  we make sure that each variable is assigned to before it is used
		# all variables are case insensitive

		##$clab is the name of the current question 
		my $clab = $chunk->qlabel(label=>1);

		#labels are implicit vars with a Q in front
		push @{$assign->{uc("Q$clab")}},{line=>$chunk->lines->[0],implicit=>1,label=>$clab};

		#keep track of defined questions cause these names can be used as variables
		$defined_qlabels->{uc($clab)} = 1;

		my $efbl = $chunk->options(opt=>'external',whole_line=>1);
		if ($ext_info && $efbl){
			my $efb=$efbl->{val};
			my $evars = $ext_info->{pages}->{$efb}->{names};
			foreach my $evar (@$evars){
				$evar = uc ("ext_$evar");
				# print "FOUND Var usage of $evar in  $efb\n";
				push @{$assign->{$evar}},{line=>$efbl,implicit=>1,label=>$clab};
			}
		}

	
		# print "Chunk type ",$chunk->options(opt=>'qtype'),"\n" ;
		if ($chunk->options(opt=>'qtype') eq 'perl_code'){
			# worry about setvar in perlcode...
			foreach my $line (@{$chunk->lines}){
				next if $line->{line} =~ /^\s*#/;
				while ($line->{line} =~ /getvar\s*\(\s*'(\w+)'/g){
					my $getvar = $1;
					# print Dumper $line;
					# print "found a getvar $getvar\n";
					$getvar = uc $getvar;
					push @{$uses->{$getvar}},{line=>$line,label=>$clab};
					unless ( $assign->{$getvar} || $warned_vars->{$getvar} ){
						$self->_line_warn (line=>$line,msg=>"variable '$getvar' has no value in question $clab") ;
						$warned_vars->{uc($getvar)}++ ;
					}
				}
				if (my ($setvar,$val) = $line->{line} =~ /setvar\s*\(\s*'(\w+)'\s*,(.*?)\)/){
					# print Dumper $line;
					# print "found a setvar $setvar\n";
					$setvar = uc $setvar;
					push @{$assign->{$setvar}},{val=>$val,line=>$line,label=>$clab};
				}
			}
			# don't worry bout any other perl_code stuff...
			next;
		}
		if ($chunk->options(opt=>'qtype') eq 'ageonset'){
			if (my $ln=$chunk->options(opt=>'age_var',whole_line=>1)){
				# print "Found a age_var ".Dumper $ln;
				my $var = uc($ln->{val});
				push @{$uses->{$var}}, {%$ln,label=>$clab};
				unless ( $assign->{$var} || $warned_vars->{$var} ){
					$self->_line_warn (line=>$ln->{line},msg=>"variable '$var' has no value in question $clab") ;
					$warned_vars->{uc($var)}++ ;
				}
			}
		}
		### +limhi or lo is a usage
		foreach my $o (qw (limhi limlo)){
			if (my $ln=$chunk->options(opt=>$o,whole_line=>1)){
				# print "Found a $o ".Dumper $ln;
				my $var = uc($ln->{val});
				next if $var =~ /^\d+$/;
				push @{$uses->{$var}}, {%$ln,label=>$clab};
				unless ( $assign->{$var} || $warned_vars->{$var} ){
					$self->_line_warn (line=>$ln->{line},msg=>"variable '$var' has no value in question $clab") ;
					$warned_vars->{uc($var)}++ ;
				}
			}
		}
		### a cnt_var is an assignment
		if (my $ln = $chunk->options(opt=>'cnt_var',whole_line=>1)){
			# print "Found a cnt_var ".Dumper $ln;
			push @{$assign->{uc($ln->{val})}},{val=>$clab,line=>$ln->{line},label=>$clab,implicit=>0};

		}
		### IMPLICIT selectvars assignment
		if (my $var = $chunk->options(opt=>'selectvar',whole_line=>1) ){
			# print "Found A selectvar option ". Dumper $var;
			push @{$assign->{uc($var->{val})}},{val=>$clab,line=>$var->{line},label=>$clab,implicit=>1};
			## now do the implicit vars, for each G type
			my $g_count = 1;
			foreach my $ch (@$group){
				next unless $ch->type eq 'grid_heading';
				#print "Found an implicit selectvalue ".Dumper $ch;
				my $implicit = uc($var->{val}).'_'.$g_count++;
				push @{$assign->{$implicit}},{val=>$clab,line=>$var->{line},label=>$clab,implicit=>1};
				#print "Implicit assignment of $implicit ".Dumper $assign->{$implicit};
			}
		}
		### in a repeat group  C if (!ismask('children',0)) goto EH7_R2
		# means that var $$children[0] is allright as a variable (its the $$repeat_thing)
		# so we don't warn about vars followed by a [ in the usage below.

		foreach my $line (@{$chunk->lines}){
			###look for usage
			next if $line->{type} eq 'comment';
			my %vars_this_line=(); ###only warn once per line # may be redundant since we only warn once perl var, but it does not harm

			#USAGE in question lines  either $$VAR or <% VAR %>
			# what about a var at an end of line?
			# print "HERE $line->{line}\n" if $line->{label} eq 'I9C_1';
			my $tline = $line->{line} . ' ';  # this helps find $$var at ends of lines.
			while ($tline =~ m/<%\s*(\w+)\s*%>|\$\$(\w+)(\W)/g){
				my $var = $1 || $2;
				my $nowrn = $3; #things happen to $3 after s/// or m//
				# print "warned found 1=$1 2=$2 3=$3 in $clab $ a  line->{line}\n";
				push @{$uses->{uc($var)}}, {line=>$line,label=>$clab};
				# print "FOUND var=$var\n" ;
				#trucate vars that look like VARx23 to VAR
				my $tvar = $var;
				$tvar =~ s/x\d+$//;
				$tvar =~ s/^Q//i;
				
				$warned_vars->{uc($var)}++ if $var =~ /^TQ/i;
				$self->_line_warn (line=>$line,msg=>"Variable '$var' has no value in question $clab") 
					unless ($assign->{uc($var)}  # || $defined_qlabels->{uc($tvar)}
						|| $vars_this_line{uc($var)} || $warned_vars->{uc($var)} || $nowrn eq '[');
				
				$vars_this_line{uc($var)}++ ;
				$warned_vars->{uc($var)}++ ;
			}

			#USAGE in code lines
			#assign in code lines too
			if (grep $line->{type} eq $_ ,qw(code if)){
				#on the rhs of = signs enclosed in ( ) ie ADT= (VAR or VAR1 and VAR2)
				#on the rhs of  j4btotal=( j4b_3 *30 )+( j4b_2 * 7 )+ j4b_1
				#ie dont worry about rhs enclosed in ( )  and split on \W not \s
				if (my ($lhs,$rhs) = $line->{line} =~ /^\s*(\w*)\s*=\s*(.*)\s*$/ ){
					# print "CODE ASSIGN lh=$lhs|rh=$rhs\n";
					push @{$assign->{uc($lhs)}},{val=>$rhs,line=>$line,label=>$clab};
					next if $rhs =~ /mask\s*\(\s*\w+/;
					next if $rhs =~ /^"/;
					foreach my $var (split /\W+/,$rhs){
						next unless $var;
						next if grep lc($var) eq $_ ,qw(min max mask or and ismask mask get_data get_gpdata);
						next if $var=~/^\s+$/;
						next if $var=~/^\d+$/;
						next if $rhs =~ /ismask\s*\(\s*'$var'/;  # The name of the mask is not a var.
						# print "HERE $var\n";
						push @{$uses->{uc($var)}}, {line=>$line,label=>$clab};
						$self->_line_warn (line=>$line,msg=>"Variable '$var' has no value in question $clab")
						          unless ($assign->{uc($var)} # || $defined_qlabels->{uc($var)}
								         || $vars_this_line{uc($var)} || $warned_vars->{uc($var)} );
						$vars_this_line{uc($var)}++ ;
						$warned_vars->{uc($var)}++ ;
					}
				}
				# in if statements ie look for  if ( (VAR>0 ) AND (VAR2< 23)) goto 23
				if ($line->{line} =~ /^\s*if/){
					my $l = $line->{line};
					$l =~ s/^\s*if\s*//i;
					# print "LINE=$l\n";
					if (my ($cond,$expression) = extract_bracketed ($l,'()')){
						# print "text_bracketed=$cond\n|rem=$expression\n";
						# print "FOUND usage in $cond\n";
						$self->_line_error(line=>$line,msg=>'Syntax error: No bracket around CONDITION in if statement') unless $cond;
						foreach my $var (split /\W+/,$cond){
							next if $var =~ /^AND$/i;
							next if $var =~ /^OR$/i;
							next if $var =~ /^\d+$/;
							next if $var eq 'ismask';
							next if $var eq 'get_data';
							next unless $var;
							next if $l =~ /ismask\('$var'/;
							# print "FOUND USAGE IN A CONDITION $var\n";
							push @{$uses->{uc($var)}}, {line=>$line,label=>$clab};
							$self->_line_warn (line=>$line,msg=>"Variable '$var' has no value in question $clab")
									  unless ($assign->{uc($var)} # || $defined_qlabels->{uc($var)}
											 || $vars_this_line{uc($var)} || $warned_vars->{uc($var)} );
							$vars_this_line{uc($var)}++ ;
							$warned_vars->{uc($var)}++ ;
						}
						#### look for assignments in if statements
						# print "exp=$expression\n";
						while ($expression =~ m/(\w+)\s*=\s*("?.*?"?)\s*$/g ){
							my ($var,$val) = ($1,$2);
							# print "Found var=$var|val=$val\n";
							push @{$assign->{uc($var)}},{val=>$val,line=>$line,label=>$clab};
							$self->_line_warn (line=>$line,msg=>"Variable '$var' has no value in question $clab")
									  unless ($assign->{uc($var)} # || $defined_qlabels->{uc($var)}
											 || $vars_this_line{uc($var)} || $warned_vars->{uc($var)} );
							$vars_this_line{uc($var)}++ ;
							$warned_vars->{uc($var)}++ ;
						}
					}
				}
			}
			
			###look for assignment
		}
		#in setvalues or in +var lines
		my $attr_count=0;
		foreach my $a_chunk (@{$group}){
			### usage can happen in attibute lines
			if ($a_chunk->type eq 'attribute'){
				$attr_count++;
				# only others get impicit vars from attrs
				# push @{$assign->{uc("Q${clab}$attr_count")}},{line=>$a_chunk->lines->[0],implicit=>1,label=>$clab};
				while ($a_chunk->lines->[0]->{line} =~ m/\$\$(\w+)|<%\s*(\w+)\s*%>/g){
					my $var = $1 || $2;
					# print "Found var=$var in ATTR line\n";
					my $tvar = $var;
					$tvar =~ s/x\d+$//;
					$tvar =~ s/^Q//i;
					$warned_vars->{uc($var)}++ if $var =~ /^TQ/i;
					$self->_line_warn (line=>$a_chunk->lines->[0],msg=>"Variable '$var' has no value in question $clab") 
						unless ($assign->{uc($var)} # || $defined_qlabels->{uc($tvar)}
							|| $warned_vars->{uc($var)} );
					$warned_vars->{uc($var)}++ ;
				}
			}
			if (my $var_line = $a_chunk->options(opt=>'setvalues',whole_line=>1) ){
				my $line = $var_line->{val};
				#print "Found a setvalues :$line\n";
				###This regexp is based on one in sub splitvalues in qt-libdb.pl
				## Except that i include the quotes in the val, to make translation easier...
				while ($line =~ /\s*([a-zA-Z][\w\.]*)\s*=\s*(".*?")/g ){ 
					my ($var,$val) = ($1,$2);
					# print "split a setvalue to find var=$var|val=$val\n";
					push @{$assign->{uc($var)}},{val=>$val,line=>$var_line->{line},label=>$clab};
				}
			}
			if (my $var = $a_chunk->options(opt=>'var',whole_line=>1) ){
				# print "Found A VAR option $var\n";
				my $vname  = uc($var->{val});
				my $ageon = 1 if lc ($chunk->options(opt=>'qtype')) eq 'ageonset';
				push @{$assign->{$vname}},{val=>$clab,line=>$var->{line},label=>$clab,implicit=>$ageon};
				# print "ageonset CHUNK " .$chunk->options(opt=>'qtype')."\n";
				if ($ageon){
					my $imp = $vname.'O';
					# print "FOUND implicit var $imp in ageonset\n";
					push @{$assign->{$imp}},{val=>$clab,line=>$var->{line},label=>$clab,implicit=>1};
				}
			}
		}
		my $others = $chunk->options(opt=>'others',whole_line=>1);
		foreach (1..$others->{val}){
			my $num = $attr_count+$_;
			push @{$assign->{uc("Q${clab}x$num")}},{line=>$others->{line},implicit=>1,label=>$clab};
		}
	}
	###give errors if an assignment is made but not used
	if ($assign_warnings){
		foreach my $var (keys %$assign){
			unless ( $uses->{uc $var} || $warned_vars->{uc($var)} ){
				foreach my $ass ( @{$assign->{$var}} ){
					$self->_line_warn (msg=> "Variable $var is assigned to but never used",
						line=>$ass->{line} ) unless $warned_vars->{uc($var)} || $ass->{implicit};
					$warned_vars->{uc($var)}++;
				}
			}	
		}
	}
	#### show info about specific variables if required...
	my @list = @$vars if $vars;
	if ($allvars){
		my %bighash =(%$uses,%$assign);
		@list = keys %bighash;
	}
	# @list = keys (%{%$uses,%$assign}) if $allvars;
	foreach my $var (@list){
		next unless $var;
		$self->err->I( "VARIABLE $var");
		if ($uses->{$var}){
			foreach ( @{$uses->{$var}} ){
				$self->_line_info(msg=>"used in question $_->{label}",line=>$_->{line});
			}
		}else{
			$self->err->I( "'$var' is not used");
		}
		if ($assign->{$var}){
			foreach ( @{$assign->{$var}} ){
				$self->_line_info(msg=>"assgined to in question $_->{label}",line=>$_->{line});
			}
		}else{
			$self->err->W( "'$var' is not assigned to");
		}
	}
	return {usage=>$uses,assign=>$assign};
}


sub tokenise {
	my $self = shift;
	my %args = @_;
	my $tokens = $args{tokens} || {};
	my $tok_use = $args{token_use} ||{};
	my $tokbase = $args{tokbase} || 'XxTRITON_TOKEN_';

# 	my $ret = $self->variable_usage;
# 	# print Dumper $ret;
	my $assign = $args{assign} ;# $ret->{assign};

	##look in the usage hash for "strings" and tokenise.
	## tokenise the chunks.
	$_->tokenise (tokens=>$tokens,tokbase=>$tokbase,token_use=>$tok_use) 
		foreach @{$self->{_chunks}};
	##tokenise the vars
    my $next_tok = 0;
    foreach (values %$tokens){
        m/(\d+)$/;
        $next_tok = $1 if $1>$next_tok
    }
	foreach my $var (keys %{$assign}){
		foreach my $use (@{$assign->{$var}}){
			next unless my ($tr) = $use->{val} =~ /^"(.+?)"$/;
			$tr =~ s/^\s*(.*?)\s*$/$1/;
			my $tok = $tokens->{$tr} ||  $tokbase.++$next_tok;
			# print "tr=$tr|tok=$tok\n";
			$tokens->{$tr} = $tok;
			push @{$tok_use->{$tok}},$use->{line};
			$tr = quotemeta $tr;  
			if ($use->{line}->{line} =~ s/$tr/$tok/){
			}else{
				print "trying to substitue $tok for $tr failed in line ".Dumper $use->{line};
			}
		}
	}
	return {tokens=>$tokens,token_use=>$tok_use};
}

sub number2line {
	my $self = shift;
	my %hsh = ();
	foreach	my $c (@{$self->chunks}){
		foreach my $l (@{$c->lines}){
			$hsh{$l->{number}} = $l;
		}
	}
	return \%hsh;
}

sub chunk_rules {
	my $self = shift;
	my %args = @_;

	my $parse = $args{parse};

	my $hsh = {
		question => {
						identify=>'^\s*Q\s*',
						new_chunk=>1,
						clean=>1,
			},
        'grid_heading'=> {
                        identify=>'^\s*G\s*',
						new_chunk=>1,
                        clean=>1,
                },
        'grid_pulldown'=> {
                        identify=>'^\s*P\s*',
						new_chunk=>1,
                        clean=>1,
                },
        'attribute'=> {
                        identify=>'^\s*A\s*',
						new_chunk=>1,
                        clean=>1,
                },
####sections are option of the attribute
#### labels are not needed
#         'section'=> {
#                         identify=>'^\s*S\s*',
# 						new_chunk=>1,
#                         clean=>1,
#                 },
#         'label'=> {
#                         identify=>'^\s*L\s*',
# 						new_chunk=>1,
#                         clean=>1,
#                 },
        'code'=> {
                        identify=>'^\s*C\s*',
                        clean=>1,
                },
        'comment'=> {
                        identify=>'^\s*#|^\s*$',
                },
        'option'=> {
                        identify=>'^\s*\+\s*\w+',
                },
        'if'=> {
                        identify=>'^\s*if',
                },
        'leftovers'=> {
                        identify=>'.',
                }
        };
	if ($parse){
		my @ret = ();
		foreach (qw (question grid_heading grid_pulldown
				attribute  code comment option if leftovers)){
			my $rule = $hsh->{$_};
			$rule->{name} = $_;
			push @ret,$rule;
		}
		return \@ret;
	}
}
# sub chunks2survey {
# 	my $self = shift;
# 
# 	foreach my $chunk (@{$self->questions}){
# 		my $q = new TPerl::Survey::Question;
# 		push @$quests,$q;
# 		$q->label ( $chunk->qlabel(label=>1));
# 		$q->prompt ($chunk->qlabel(prompt=>1));
# 		$q->options ($chunk->options);
# 		$q->type (
# 	}
# 	print Dumper $quests;
# 	my $survey = new TPerl::Survey (%$survey_args,questions=>$quests,options=>);
# 	return $survey;
# }

sub engine_files{
	my $self = shift;
	my %args = @_;
	my $dest = $args{dir};
	my $SID = $args{SID};
	my $troot = $args{troot};
	my $simple_tabs = $args{simple_tabs};
	my $max_var_length = $args{max_var_length};
	my $recode =1;
	$recode = $args{recode} if exists $args{recode};
	my $simple_tabs_setting = "OFF";
	if ($simple_tabs eq 1 || $simple_tabs eq "on") {
		$simple_tabs_setting = "ON";
	}
	print "Simple Tabs setting: $simple_tabs_setting  <br>";
	my @survey_questions = ();  # these are the TPerl::Survey::Question things.

	my $groups = $self->question_groups; # an array of arrays of chunks for each question
	$self->err->I("Found ". scalar (@$groups) . " Questions");
 	$self->_config_file (dir=>$dest,SID=>$SID,troot=>$troot);
	my $count = 1;
	# print Dumper $self;
	my $skip_hash = $self->label2qfilenumber(uc=>1);
	

	foreach my $group ( @$groups ){
		my $fh = new FileHandle ("> $dest/q$count.pl") or 
			$self->err->E( "Could not open file $dest/q$count.pl:$!");
		my $q = $self->_qfile (fh=>$fh,group=>$group,number=>$count,skip_hash=>$skip_hash,simple_tabs=>$simple_tabs);
		push @survey_questions,$q;
		$count++;
	}
	my $su = new TPerl::Survey (SID=>$SID,questions=>\@survey_questions,options=>$self->chunks->[0]->options);
	my $ext_info = $su->external_info();
	my $data_cols = {};
	my $data_cols_ext= {};
	foreach my $q (@{$su->questions}){
		$q->external_info ($ext_info->{pages}->{$_}) if $_ = $q->external();
		my $cis = $q->getDataInfo(ext_info=>$ext_info);
		#my $qid = $q->label .': '. $q->prompt;
		my $qid = $q->label ;
		foreach my $ci (@$cis){
			my $varn = uc $ci->{var};
			if ($data_cols->{$varn}){
				my $err_type = 'F';
				$err_type = 'E' if $data_cols_ext->{$varn};
				$self->err->$err_type(sprintf "Data Column '$varn' in '$qid' is previously used by question(s) '%s'",
					join ' AND ',@{$data_cols->{$varn}});
			}
			# $self->err->W("Data Column $ci->{var} is longer than 8 chars") if length($ci->{var})>8;
			push @{$data_cols->{$varn}}, $qid;
			push @{$data_cols_ext->{$varn}}, $qid if $q->qtype == 7;
		}
	}
	$self->_qlabel_file(dir=>$dest,survey_id=>$SID,label2qnumber=>$skip_hash);
	$self->_recode_file(dir=>$dest,max_var_length=>$max_var_length,troot=>$troot,SID=>$SID,survey=>$su) if $recode;
	# print dump $self->chunks->[0]->options;
	# print dump $su;
	my $qbylab = $su->questions_by_label;
	$_->chk_direct_data_use (err=>$self->err,qbylab=>$qbylab) foreach @{$su->questions};
	my $sfile = "$dest/${SID}_survey.pl";
	if (justput TPerl::Dump $sfile, $su){
		return undef;
	}else{
		return "Error writing survey object to $sfile:$!";
	}
# 	my $du = new TPerl::Dump (file=>$sfile,touch=>1);
# 	return $_ if $_ = $du->err;
# 	$du->getnlock();
# 	return $_ if $_ = $du->err;
# 	$du->putnunlock($su);
# 	return $_ if $_ = $du->err;
# 	return undef;
}

sub question_groups {
	my $self = shift;
	my %args= @_;
	my $wchb4fq = 0; #want chunks b4 first question.
	my $ret = [];
	my $group_count = -1;
	$group_count = 0 if $wchb4fq;
	foreach my $chunk (@{$self->chunks}){
		if ($chunk->type eq 'question'){
			$group_count++;
		}
		push @{$ret->[$group_count]},$chunk if $group_count>-1;
	}
	return $ret;
}

sub questions {
	my $self = shift;
	my %args = @_;
	my @chunk_list = ();
	foreach my $chunk ( @{$self->{_chunks}} ){
		push @chunk_list,$chunk if $chunk->type() eq 'question';
	}
	return \@chunk_list;
}
sub _chunks_options {
	my $self = shift;
	my %args = @_;
	my $chunks = $args{chunks} || [];
	my $option = $args{option};
	my $res = [];
	# print "In _chunks_options with ".Dumper \%args;
	if ($option){
		my $found = 0;
		foreach my $ch (@$chunks){
			my $opt = $ch->options(opt=>$option);
			# print "opt=$opt\n";
			push @$res,$opt;
			$found++ if $opt ne '';
		}
		$res = [] unless $found;
	}
	return $res;
}
sub _qfile {
	my $self = shift;
	my %args=@_;
	my $fh = $args{fh};
	my $simple_tabs = $args{simple_tabs};
    my $skip_hash = $args{skip_hash} || $self->label2qfilenumber;
	my $group = $args{group}; ##Chunk number 
	my $number = $args{number};## qfile number

	my $q = new TPerl::Survey::Question ();

	my $chunk = $group->[0];
	my $qnum = $chunk->qlabel(label=>1);
	my $prompt = $chunk->qlabel(prompt=>1);
	$q->label ( $chunk->qlabel(label=>1));
	$q->prompt ($chunk->qlabel(prompt=>1));
	$q->qnum($number);

	#print "chunk number $number $qnum\n";
	
	my $q_attr = $chunk->options();
    print $fh    q{#!/usr/bin/perl} . "\n";
    print $fh    q{#} . "\n";
    print $fh    q{# Copyright 2001 Triton Survey Systems, all rights reserved} . "\n";
    print $fh    q{#} . "\n";
    print $fh    q{# } . scalar (localtime) . "\n";
    print $fh    q{#} . "\n";

    ### allow numeric question types
    my $qtype = undef;
    if (my ($num) = $q_attr->{qtype} =~ /(\d+)/ ){
		$self->_line_info (msg=>"using qtype number $num in question "
				.$chunk->qlabel(label=>1)." near",
			line=>$chunk->lines->[1]);
        print $fh qq{ \$qtype = $num;\n };
        $qtype = $num;
    }elsif (my $qtyp_num = question_type_number($q_attr->{qtype} ) ){
        print $fh  qq{\$qtype = $qtyp_num ;\n};
        $qtype = $qtyp_num;
    }else{
        print $fh  qq{\$qtype = 3;\n};
		$self->_line_error (msg=>"No qtype for $q_attr->{qtype} near",line=>$chunk->lines->[0]);
        $qtype = 3;
    }
	$q->qtype ($qtype);
    my $grid_stuff = grep $qtype == $_, (14, 19 ,24,25,26,29,30,31);
 	
	my $question = "$qnum. $prompt";
	$question = $prompt if $prompt =~ /^\s*</ ;
    print $fh  qq{\$prompt = '}.TPerl::Text::Quote->quote_quote  ($question).qq{';\n};
	my $qlab = uc($qnum);
	$qlab = uc("Q$qlab");
    print $fh  qq{\$qlab = '$qlab';\n};
    print $fh  qq{\$q_label = '$qnum';\n};

    print $fh  qq{undef \$others;\n};

	my $supported= $q->supported_options;
	my @supported_options = @{$supported->{normal}};

	push @supported_options,@{$supported->{set_if_exist}};

	# push @supported_options, 'agevar' if $qtype == 19;
    my @leave_these_till_later = @{$supported->{special}};

    foreach (@{$supported->{set_if_exist}}){
		if (exists $q_attr->{$_} &&  $q_attr->{$_} eq ''){
        	$q_attr->{$_} = 1 ;
			$q->$_ ($q_attr->{$_});
		}
    }

    $q_attr->{instr} ||='';
    foreach my $key (keys %$q_attr){
            next if grep $key eq $_, @leave_these_till_later ;
			print $fh qq{\$$key = '}. TPerl::Text::Quote->quote_quote  ($q_attr->{$key}) .qq{';\n};
			if (grep $_ eq $key, @supported_options){
				$q->$key ($q_attr->{$key});
			}else{
            	$self->err->W("Non supported option '+$key' at question ".$chunk->qlabel(label=>1));
			}
    }
	if ($qtype==5){
		foreach (qw (dk)){
			print $fh  qq{\$$_ = '}. TPerl::Text::Quote->quote_quote  ($q_attr->{$_} ) .qq{';\n};
			$q->$_ ($q_attr->{$_});
		}
	}
    if ($grid_stuff){
        unless ($qtype == 19){
            print $fh  qq{undef \@scale_words;\n};
            foreach (qw (dk middle )){
                print $fh  qq{\$$_ = '}. TPerl::Text::Quote->quote_quote  ($q_attr->{$_} ) .qq{';\n};
				$q->$_ ($q_attr->{$_});
            }
        }
        foreach (qw (left_word right_word )){
            print $fh  qq{\$$_ = '}. TPerl::Text::Quote->quote_quote  ($q_attr->{$_} ) .qq{';\n};
			$q->$_ ($q_attr->{$_});
        }
    }


	my $grid = $self->collected (start_num=>$chunk->number,look_type=>'grid_heading',end_type=>'question');
	if (@$grid){
		my @recodes = ();
		my $found_recode=undef;
		my $chunks = $self->chunk_filter (look_type=>'grid_heading',end_type=>'question',start_num=>$chunk->number);
        foreach my $g ( @$chunks){
			my $cod = $g->options->{code};
			push @recodes,$cod;
			# print "here $cod\n" if $q->label eq'B2';
			if ($cod){
				if (grep $_==$qtype,14,25){
					$found_recode=1;
				}else{
					$self->err->W("Ignoring +code=$cod on G in a non 'grid' question ".$chunk->qlabel(label=>1));
				}
			}
		}
		if ($found_recode){
			push @recodes,undef foreach 1..$q_attr->{others};
		}
		$q->recodes(\@recodes) if $found_recode;
		my $varnames = $self->_chunks_options (chunks=>$chunks,option=>'varname');
				for (my $idx=0;$idx < @$grid ;$idx++){
					unless (defined $varnames->[$idx]){
						if (!$simple_tabs || $simple_tabs eq "" || $simple_tabs eq 0) {
							$varnames->[$idx] = $1 if $grid->[$idx] =~ /^(\w+)\./;
						}
						$varnames->[$idx] = $1 if $grid->[$idx] =~ /^(\w+)\./;
						$varnames->[$idx] = $grid->[$idx] if length ($grid->[$idx]) <3;
						$varnames->[$idx] =~ s/\W//g if $varnames->[$idx];
					}
				}
			$q->g_varnames ($varnames) if @$varnames;
		my $varlabels = $self->_chunks_options (chunks=>$chunks,option=>'varlabel');
			$q->g_varlabels ($varlabels) if @$varlabels;
		$self->err->W("$qnum is a grid question with specify_n and no true_flags") if ($qtype==14) and $q->specify_n and !$q->true_flags;
	}

    print $fh  q{@scale_words = (}. TPerl::Text::Quote->quote_quote_array (@$grid). qq{);\n} if $grid_stuff && @$grid;
	$q->scale_words ($grid) if $grid_stuff && @$grid;

    my $scale = $q_attr->{scale};
    $scale ||= @$grid;
    print $fh  qq{\$scale = '$scale';\n} if $scale;
	$q->scale($scale);

    {
        my $required = $q_attr->{required};

        if ($qtype == 1 ){
            $required = 'all' unless defined $required;
        }
		if (grep $qtype == $_,1,9,21,19,29){
            foreach (qw(limlo limhi)){
				my $lim = $q_attr->{$_};
				$lim = 0 if ($_ eq 'limlo') and ($qtype ==19) and ($lim eq '');
				$q->$_($lim) if $lim ne '';
                $lim = "''" if $lim eq '';
                print $fh qq{\$$_ = "$lim";\n};
            }
		}
        $required = 'all' if grep ($qtype == $_,15,19) && !defined $required;
        $required = '0' if $qtype == 2 && !defined $required;
        print $fh qq{\$required = '$required';\n}if defined $required;
		$q->required ($required) if defined $required;
    }
    my @vars = ();
    my @skips = ();
    my @scores = ();
    my @options = ();
    my @setvalues = ();
	my @tally_sections = (); # sections are for tally questions. and for cluster questions
	my @can_proceed = ();

	# code lines are in the current chunk they don;t make new chunks basically cause they don;t have options
    if (my @code = @{$chunk->line_filter (type=>'code',line_only=>1)} ){
        # print "code\n";
		# print Dumper \@code;
		if ($qtype == 27){
			print $fh qq(\$code_block = q{\n);
			print $fh "\t$_\n" foreach @code;
			print $fh qq(};\n);
		}else{
			print $fh qq{\$code_block = <<END_OF_CODE;\n};
			foreach ( @code ){
				s/\$/\\\$/g;
				s/@/\\\@/g;
				print $fh "\t$_\n";
			}
			print $fh qq{END_OF_CODE\n};
		}
		$q->code(\@code);
		# This does not work cause we are not in cgi-mr land.
# 		if ($qtype==27){
# 			no strict;
# 			eval join "\n",@code;
# 			if ($@){
# 				$self->err->E("Perl code eval error in $qlab:'$@'");
# 			}
# 			use strict;
# 		}
    }

    if (my $if = $chunk->line_filter(type=>'if',line_only=>1)->[0]){
        # skips can com from evauator questions
        my ($lhs,$rhs,$sk) = $if =~ /\((\w*),(\w*)\) goto (\S+)/;
        print $fh   q{$lhs = '}. TPerl::Text::Quote->quote_quote ($lhs) . qq{';\n};
        print $fh   q{$rhs = '}. TPerl::Text::Quote->quote_quote ($rhs) . qq{';\n};
        @skips = split /,/,$sk;
        # print "match $lhs|$rhs|$sk\n";
    }else{
        ### vars skips and scores come from attributes.
        ## we also get setvalues from attributes
		my @recodes = ();
		my $found_recode=undef;
		my $attrbs = $self->chunk_filter (look_type=>'attribute',end_type=>'question',start_num=>$chunk->number);
        foreach ( @$attrbs ){
			my $opt1 = $_->options;
            push @vars,$opt1->{var};
			my ($l,$r) = split /=/,$opt1->{setvalues},2;
			my $sv = lc($l).'='.$r if $l;
            push @setvalues,$sv;
            push @scores,0;
			push @can_proceed,$opt1->{can_proceed};
            my $skip = '0';
            push @skips,$opt1->{skip};
            push @options, $_->lines->[0]->{line};
			push @tally_sections,$opt1->{section};
			my $cod = $opt1->{code};
			push @recodes,$cod;
			if ($cod){
				if (grep $qtype == $_,2,3){
					$found_recode=1;
				}else{
					$self->_line_warn (msg=>"Ignoring +code=$cod on an A. Not 'multi' or 'single' in question ".
						$chunk->qlabel(label=>1),
						line=>$_->lines->[0])
				}
			}
        }
		# --------------------------------------------------------------
		# description: NAGS modification is here. If an attribute has a dot (.) in the first part then its first word is appended to the tab name i.e. (Q1xsomething) if A something.com. Therefore Q 1A. something becomes Q1x1A column in data file. This is by design as a fix for NAGS client requirement. 
		# comment: should probably be a compiler switch!!
		# author: mking / andrew
		# date: n/a
		# revision: 1
		# --------------------------------------------------------------
		my $varnames = $self->_chunks_options(chunks=>$attrbs,option=>'varname');
			# if (@$varnames){
				for (my $idx=0;$idx < @options ;$idx++){
					unless (defined $varnames->[$idx]){
						if (!$simple_tabs || $simple_tabs eq "" || $simple_tabs eq 0) {
							$varnames->[$idx] = $1 if $options[$idx] =~ /^(\w+)\./;
						}
					}
				}
				$q->a_varnames($varnames);
			# }
		# -END----------------------------------------------------------
		my $varlabels = $self->_chunks_options(chunks=>$attrbs,option=>'varlabel');
			$q->a_varlabels($varlabels) if @$varlabels;
		$q->recodes(\@recodes) if $found_recode;
	#	print Dumper \@options;
    }

    #translate skip from qlabel 2 qnumber if it exists
	my @skip_labels = @skips;
    foreach (@skips){
        next unless $_;
        if (my $skip = $skip_hash->{uc($_)}){
            $_ = $skip;
        }else{
			$self->_line_error(msg=>"No question has label $_ in question ".
				$chunk->qlabel(label=>1)." begining at" ,line=>$chunk->lines->[0]);
        }
    }
	if ($qtype==22){
		###check for tally option in cluster questions with skip hash
		if (my $tally_num = $skip_hash->{$chunk->options->{tally}}){
			print $fh qq{\$tally = $tally_num;\n};
			$q->tally ($tally_num);
		}else{
			$self->_line_error(msg=>"Tally option $chunk->options->{tally} does not refer to a question".
				$chunk->qlabel(label=>1)." begining at",line=>$chunk->lines->[0]);
		}
	}

    print $fh  q{@skips = (}. TPerl::Text::Quote->quote_quote_array (@skips). qq{);\n}
        unless $qtype==19;
	$q->skips(\@skip_labels);
        
	my ($grid_type) = $q_attr->{qtype} =~ /_(\w+)/;

	print $fh  qq{\$grid_type = '$grid_type';\n} if $grid_type;

    my $grid_pull = $self->collected(look_type=>'grid_pulldown',end_type=>'question',start_num=>$chunk->number);
	# my $grid_pull = [grep $_->type eq 'grid_pulldown',@$group];
    if (@$grid_pull){
		my $non_quoted = eval dump $grid_pull;
		$q->pulldown($non_quoted);
        foreach (@$grid_pull){$_ = TPerl::Text::Quote->quote_quote  ($_) }
        print $fh  q{@pulldown = ( '} . join (qq{', \n\t'},@$grid_pull) . qq{',\n\t);\n};
		# now iterate over pulldows getting recodes
		my @recodes=();
		
		my $found_recode;
		# print "BF ".Dumper \@recodes;
        foreach my $p ( @{$self->chunk_filter (look_type=>'grid_pulldown',end_type=>'question',start_num=>$chunk->number)} ){
			my $cod = $p->options->{code};
		 	# print $chunk->qlabel()." c=$cod HERE$p\n";
			push @recodes,$cod;
			$found_recode=1 if $cod;
		}
		# print "AF ".Dumper \@recodes;
		$q->recodes(\@recodes) if $found_recode;
    }
	$q->scores(\@scores);
	$q->attributes(\@options);
	$q->vars(\@vars);
	$q->setvalues(\@setvalues);

    print $fh  q{@can_proceed = (}. TPerl::Text::Quote->quote_quote_array (@can_proceed). qq{);\n} if grep $_,@can_proceed;
    print $fh  q{@scores = (}. TPerl::Text::Quote->quote_quote_array (@scores). qq{);\n};
    print $fh  q{@options = (}. TPerl::Text::Quote->quote_quote_array (@options) . qq{);\n} if @options;
    print $fh  q{@vars = (}. TPerl::Text::Quote->quote_quote_array (@vars). qq{);\n} ;
    print $fh  q{@setvalues = (}. TPerl::Text::Quote->quote_quote_array (@setvalues). qq{);\n}
        unless $qtype ==19 ;
 
#  	#### do labels and sections. 
#	section is now an option of and Attribute
# 	labels are not needed

	if ($qtype==21 || $qtype == 22 || $qtype == 23){  ## tally
		$q->sections (\@tally_sections);
		print $fh q{@sections = (}.TPerl::Text::Quote->quote_quote_array (@tally_sections). qq{);\n};

	}
    print $fh  qq{# I Like the number wun\n};
	# my $frz = freeze (%cnstr);
	# print $fh  "#FrozenConstructorYadaYibble=$frz\n";
    print $fh      qq{1;\n};
	return $q;
}
sub _recode_file {
	my $self = shift;
	my %args = @_;
	my $dir = $args{dir};
	my $recode_str = $args{recode_str} || 'recode';
	my $filebase = $args{basename} || 'extract';
	my $extract_str = $args{extract_str} || 'extract';
	my $limit_str = $args{limit_str} || 'limit';
	my $vallab_str = $args{vallab_str} || 'value_labels';
	my $max = $args{max_var_length} || 8;
	my $s = $args{survey};

	my $file = "$dir/$filebase.ini";
	my $hfile = "$dir/${filebase}_history.ini";
	my $troot = $args{troot};
	my $SID = $args{SID};

	# my @no_qtype_extract = qw (8 20 22 28); # instr eval, code,  repeater

	# if the file does not already exist we need to put the Status, Token etc
	# vars at the beginning.

	my $file_existed = -e $file;
	unless ($file_existed){
		write_file ($file,"[$extract_str]\n") or $self->err->E("Could not make $file:$!");
	}
	unless (-e $hfile){
		write_file ($hfile,"[$extract_str]\n") or $self->err->E("Could not make $hfile:$!");
	}

	# my $cfg = new Config::IniFiles (-file=>$file);
	my $cfg = new TPerl::ConfigIniFiles (-file=>$file);
	unless ($cfg){
		$self->err->E("Could not parse '$file' ");
		$self->err->E("$_") foreach @Config::IniFiles::errors;
		$self->err->F("Please fix ini file '$file'");
		return;
	}
	# my $hcfg = new Config::IniFiles (-file=>$hfile);
	my $hcfg = new TPerl::ConfigIniFiles (-file=>$hfile);
	unless ($hcfg){
		$self->err->E("Could not parse '$hfile' Errors and line numbers follow");
		$self->err->E("$_") foreach @Config::IniFiles::errors;
		return;
	}

	# should always start the recode section from scratch.
	# $cfg->delete([$recode_str]) if $cfg->exists([$recode_str]);
	$cfg->DeleteSection($recode_str) if $cfg->SectionExists($recode_str);
	#### Now we are only adding new variables that we have not seen, 
	my $in_extract = {};
	foreach my $e ($cfg->Parameters($extract_str)){
		$e =~ s/^\s*!*\s*(.*)/$1/;
		$in_extract->{uc($e)}++;
        if (my ($ext_var) = $e =~ /^ext_(\w+)/){
            # if there is and ext_rsex in the extract.ini then we dont want to put an rsex from and external in there also
            $in_extract->{uc($ext_var)}++;
        }
	}
	# print "in_extract ".Dumper $in_extract;
	my @common = qw (Status Seqno  SurveyID Email  Ipaddr Duration Year Month Day Weekday hour min Token Id lastq );
	unless ($file_existed){
		$cfg->newval($extract_str,$_,'') foreach @common;
	}
	# print Dumper $cfg;
	my $externals = {};
	my $extrs = {};  # the vars that are supposed to be here.
	
	my $lastvar = undef;
	foreach my $q ( @{ $s->questions } ){
		my $qtype = $q->qtype;
		my $lab = $q->label;
		foreach my $efnb (qw(execute require_file)){
			if (my $efb = $q->$efnb){
				# print "Found $efnb $efb in $lab\n";
				my $rf = join '/',$troot,$SID,'config',$efb;
				$self->err->W("Move $efnb functionality in $efb to a perl_code question at $lab") unless -e $rf;
			}
		}
		# The extract section should have everything in the data file by default
		my $cidx = 0;
		my $re = $q->recodes;
		foreach my $ci (@{$q->getDataInfo}){
			my $var = $ci->{var};
			$extrs->{$var}++;
			unless ($in_extract->{uc($var)}){
				$cfg->newval_after ($extract_str,$var,$lastvar,'');
				$self->err->I("Added $var to [extract] section after $lastvar");
			}
			# Now do some footwork for the recode things.
			my $recs = {};
			if ($qtype==3){
				my $as = $q->attributes;
				my $started;
				foreach my $a (1..@$as){
					my $adx = $a-1;
					my $new_code = $re->[$adx];
					$started++ if defined $new_code;
					if (exists $ci->{autocode_after} && $a>$ci->{autocode_after}){
						$self->err->W("Ignoring recode of specify '$as->[$adx]' in question $lab") if defined $new_code;
					}else{
						
						# $self->err->W("No Code on $as->[$adx] in question $lab") if $started && !defined $new_code;
						# $new_code = $a if $started and !defined $new_code;
						push @{$recs->{$var}},"$a,$new_code" if defined $new_code;
					}
				}
			}elsif (grep $qtype==$_,2,25){
				# print $q->label." $qtype\n";
				if ($re){
					my $new_code = $re->[$cidx] if $qtype==2;
					my $recdx = $ci->{pos} % @$re;
					$new_code=$re->[$recdx] if (($qtype==25) && $ci->{val_if_true});
					# print "var=$var idx=$recdx new=$new_code|".Dumper($ci) if $lab eq 'B2';
					# print Dumper($re) if $lab eq 'B2';
					if (defined $new_code){
						if ($ci->{specify}){
							$self->err->W("Ignoring +code=$new_code on a specifier in question $lab");
						}else{
							push @{$recs->{$var}},"$ci->{val_if_true},$new_code";
						}
					}
				}else{
					#repeaters become multi with autselect, but they don;t have a recode hash
				}
			}elsif (grep $qtype==$_,14){
				my $gs = $q->scale_words;
				if ($re){
					foreach my $oval (1..@$gs){
						my $new_code = $re->[$oval-1];
						if (defined $new_code){
							push @{$recs->{$var}},"$oval,$new_code";
						}
					}
				}
			}elsif (grep $qtype==$_,19,21){
				unless ($q->no_recency){
					my $ps=$q->pulldown;
					my $st = 0;
					$st = 1 if $qtype==19;
					# now if there is +last_recency_only there are only 3 cols, not 4.
					# Use the presence of val_label to see if we are recoding.
					if ($re and exists $ci->{val_label}){
						foreach my $o ($st..@$ps-1){
							my $n = $re->[$o];
							if (defined $n){
								 #print "recode $var $o $n\n";
								 push @{$recs->{$var}},"$o,$n";
							}
						}
					}
				}
			}elsif (grep $qtype==$_,26){
				my $ps = $q->pulldown;
				foreach my $p (1..@$ps-1){
					push @{$recs->{$var}},"$p,$re->[$p]" if defined $re->[$p];
				}
			}
			$lastvar=$var;
 			$cfg->newval($recode_str,$_,@{$recs->{$_}}) foreach keys %$recs;
			$cidx++;
		}
 	}
	$cfg->SetSectionComment($recode_str,"$recode_str section is machine edited",'Do not edit') if $cfg->SectionExists($recode_str);
	### Sanity Checking
	#Check for dups.  check if relabels clash with existing
	# print "About to sanity check in recode_file()\n";
	{	
		my $out_labels = {};
		foreach my $var ($cfg->Parameters($extract_str)){
			my @vals = $cfg->val($extract_str,$var);
			if (@vals >1){
				my $vals = @vals;
				$self->err->E("$vals lines with $var= in [$extract_str] section of $file") ;
			}
			foreach my $val (@vals){
				if ($val){
					$self->err->I("$var=$val conflicts with previous label $val in [$extract_str] section of $file") 
						if $out_labels->{uc $val};
					$out_labels->{uc $val}++;
				}else{
					$self->err->I("$var=$val conflicts with previous label $var in [$extract_str] section of $file") 
						if $out_labels->{uc $var};
					$out_labels->{uc $var}++;
				}
			}
		}
	}
	
	# move to history if things should not be here
	# print "About to look in in history file $hfile\n".Dumper($hcfg);
	my $new_hist = 0;
	my @hvals = $hcfg->Parameters($extract_str);
	foreach my $var ($cfg->Parameters($extract_str)){
		next if $extrs->{$var};
		next if $var =~ /^ext/;
		next if $var =~ /^\s*!/;
		next if grep $_ eq $var,@common;
		my $val = $cfg->val($extract_str,$var);
		if ((grep $_ eq $var,@hvals) and ($hcfg->val($extract_str,$var) eq $val)){
			#dont add another
		}else{
			$new_hist++;
			$cfg->delval($extract_str,$var);
			$hcfg->newval($extract_str,$var,$val);
			$hcfg->SetParameterComment ($extract_str, $var,"Moved to history on ".scalar(localtime)) if $new_hist ==1;
		}
	}
	# print "About to write newhist if $new_hist\n";
	if ($new_hist){
		$self->err->I("$new_hist items moved from [$extract_str] in $file to $hfile");
		$hcfg->WriteConfig($hfile) or $self->err->F("Could not write $hfile:$!");
	}
	# print Dumper $hcfg;
	# $cfg->save or $self->err->E("Cannot write recode file '$file'");
	# exit;
	# $cfg->WriteConfig($file) or $self->err->E("Could not write $file:$!");
	# lets write to a temp file and then move that to the right spot
	my ($tfh,$tfn) = tempfile();
	$tfh->close;
	$cfg->WriteConfig($tfn) or $self->err->E("Could not write $tfn:$!");
	move ($tfn,$file) or $self->err->E("Could not move '$tfn' to '$file':$!");
	# print "About to finish\n";
}
sub _qlabel_file {
	my $self = shift;
	my %args = @_;

    my $survey_id = $args{survey_id};
    my $dir = $args{dir};
	my $lab2qnum = $args{label2qnumber};
    my $opt = $self->{_chunks}->[0]->options;

	my $fh = $args{fh} || new FileHandle ("> $dir/qlabels.pl");

    print $fh qq{#!/usr/bin/perl\n};
    print $fh    q{# } . scalar (localtime) . "\n";
    print $fh    qq{\$survey_id = '$survey_id';\n};
    foreach (qw (window_title survey_name)){
        print $fh qq{\$$_ = '} . TPerl::Text::Quote->quote_quote ( $opt->{$_} ) . qq{';\n};
    }
    print $fh    q{%qlabels = (}."\n";
    my $count = 1;
	###MASKS. for each mask keep track of the largest number of att and others
	#	found so far.  use these values for the qlabels file.
	my $masks = {};
	foreach my $chunk (@{$self->questions}){
        my $q_opt = $chunk->options;
        my $att = scalar ( @{$self->chunk_filter 
				(look_type=>'attribute',start_num=>$chunk->number)});
        my $others;
        if ($q_opt->{others}) {
        	$others = $q_opt->{others};
        } else {
        	$others = "";
        }
        my $q_type = question_type_number($q_opt->{qtype});
        if ($q_type == 3 ){
            # $others = 1;
            $att = 1;
        }

		#tally questions.
		if ($q_type == question_type_number ('tally')){
			if ($q_opt->{multi}){
			}elsif ($q_opt->{multi}){
				$att *= 2;
			}else{
				$att *= 4;
			}
		}
		if ($q_type == question_type_number ('cluster')){
			$att=0;
		}
		#  Get rid of this when there are no more when grid_type is removed
		if (($q_type == question_type_number ('grid') && $q_opt->{grid_type} eq 'pulldown')  ){
			my $gr = scalar ( @{$self->chunk_filter 
					(look_type=>'grid_heading',start_num=>$chunk->number)});
			$att *= $gr;
		}
		if (grep $q_type == question_type_number ($_),qw(grid_multi grid_pulldown grid_number grid_text)){
			my $gr = scalar ( @{$self->chunk_filter 
					(look_type=>'grid_heading',start_num=>$chunk->number)});
			$att *= $gr;
		}
		$att ||=1 if $q_type == question_type_number ('written');
		if ($q_type == question_type_number ('ageonset')){
			$att *=2;
		}

        my $q_lab = $chunk->qlabel(label=>1);
        $q_lab = "q$q_lab" if $q_lab =~ /^\d/;

		if (my $mask = $chunk->used_mask ){
			#use saved mask info unless they mean a reduction in size.
			## like happens whn masks are set in code questions.
			# singles are always 1.
			if ($q_type != 3){
				$att = $masks->{$mask}->{att}+$masks->{$mask}->{oth} if 
					$att < $masks->{$mask}->{att} + $masks->{$mask}->{oth};
			}
		}
		if (my $mask = $q_opt->{mask_reset} ){
			# save mask info
			# in a mask question we are getting codes from another question 
			$masks->{$mask}->{att}=$att if $att>$masks->{$mask}->{att};
			$masks->{$mask}->{oth}=$others if $others >$masks->{$mask}->{oth};
			# print Dumper $masks;
		}

        print $fh    qq{     '$count',   '$q_type $q_lab $att  $others',\n};
        $count++;
    }
    $count--;
    print $fh    qq{);\n};
    print $fh    qq{\$numq = $count;\n};
	my $labs = {};
	foreach my $k (keys %$lab2qnum){
		my $newk = $k;
		# next if grep $k == $_,-1,-2;
		$newk = "Q$k" if $k =~ /^\d/;
		$labs->{$newk} = $lab2qnum->{$k};
	}
	my $hsh = dump ($labs);
	$hsh =~ s/^\s*{//;
	$hsh =~ s/}\s*$//;
	print $fh    q{%qlab2ix = (}."\n";
	print $fh    qq{$hsh\n};
	print $fh	 q{);}."\n";
    print $fh    qq{1;\n};
}

sub label2qfilenumber {
	my $self = shift;
	my %args = @_;
	my $uc=$args{uc};

	my %hsh = ();
	my $count = 1;
	foreach (@{$self->questions}){
		my $lab = $_->qlabel(label=>1);
		# print "lab=$lab ". Dumper \%hsh;
		##Mike want this to be fatal
		$self->err->F("Duplicate question label $lab") if $hsh{$lab};
# 		$self->_line_error (msg=>"Duplicate question label $lab",
# 			line=>$_->lines->[0]) if $hsh{$lab};
		$lab = uc($lab) if $uc;
		$hsh{$lab} = $count++
	}
	# skips of -1 and -2 have special meaning in the engine
	$hsh{$_} = $_ foreach (-1,-2);
	return \%hsh;
}
sub collected {
	my $self = shift;
	my %args = @_;

    my $start_num =$args{start_num} || 0;
	my $end_type = $args{end_type};
	my $look_type = $args{look_type};

	my $filtered = $self->chunk_filter (start_num=>$start_num,look_type=>$look_type,end_type=>$end_type);
	my $lines = [];
	$_->line_filter (lines=>$lines,type=>$look_type,line_only=>1) foreach @$filtered;
	return $lines;
}
sub chunk_filter{
	my $self = shift;
	my %args = @_;

	my $start_num =$args{start_num} || -1;
	my $end_type = $args{end_type} || 'question' ;
	my $look_type = $args{look_type};
	
	# print "chunk st=$start_num|et=$end_type|look_type=$look_type\n";
	my @list = ();

	#### according to profiling this function gets called alot
	## so we use direct access for type and number instead of the methods.

	my $cnum = $start_num+1;
	while (1){
		my $chunk = $self->{_chunks}->[$cnum];
		last unless defined $chunk;
		$cnum++;
		last if $chunk->{_type} eq $end_type;
		next if $look_type and $chunk->{_type} ne $look_type;
		push @list,$chunk;
	}
# 	foreach my $chunk ( @{$self->{_chunks}} ){
# 		if ($chunk->{_number}>$start_num){
# 			last if $chunk->{_type} eq $end_type;
# 			next if $look_type and $chunk->{_type} ne $look_type;
# 			push @list,$chunk;
# 		}
# 	}
	# print ":chunk_filter ".Dumper \@list;
	return \@list;
}
sub _config_file {
	my $self = shift;
	my %args = @_;
	my $job=$args{SID};
	my $dir=$args{dir};
	my $survey_id=$args{SID};
	my $troot;
	if ($args{troot}) {
		$troot = $args{troot};
	} else {
		$troot = "";
	}

    # i will create an empty config2.pl if it does not exist
    # config2.pl is hand edited for future quick hacks and overwrites etc.
    # all options go into the config.pl
    # here are the default values that are always included, but may be overwritten....
    # also survey_name and window_title are compulsory and we should error
    # if they are not included in the text file

    my %config = ( banner_top=>0,
                    bg_color=>'#FFFFFF',
                    textcolor=>'#000000',
                    background=>'',
                    plain=>1,
                    do_footer=>0,
                    no_methods=>1,
                    style=>'plain',
                    do_body=>1,
                    block_size=>999,
                    mailto=>'info@market-research.com',
                    thankyou_url=>"/$survey_id/thanks.htm"
                );
    my @error_if_not_present = qw (survey_name window_title);

	my @lines=();
    unless ( -e File::Spec->catfile ($dir,'config2.pl')){
        push @lines,q{#!/usr/bin/perl};
        push @lines,q{# generated by TPerl::Parser because it does not exist };
        push @lines,'# '. scalar (localtime);
        push @lines,'# config2.pl should be hand edited for future quick hacks and overwrites etc.';
        push @lines, q{1;};
        foreach (@lines) { s/$/\n/ }
		# print File::Spec->catfile ($dir,'config2.pl')."\n";
        overwrite_file (File::Spec->catfile ($dir,'config2.pl'),@lines);
    }

	my $count = scalar (@ {$self->questions()} );
    @lines = ();
	my %jumps = ();
	foreach my $q (@{$self->questions}){
		$jumps{$q->qlabel(label=>1)} = 1 if exists $q->options->{jump};
	}
	my $attr=$self->{_chunks}->[0]->options;

    push @lines,q{#!/usr/bin/perl};
    push @lines,q{# generated by TPerl::Parser::_config_file };
    push @lines,'# '. scalar (localtime);
    push @lines,    qq{\$numq = $count;};
    my %opts = (%config, %$attr);
    foreach my $key (@error_if_not_present){
        $self->err->E("'+$key' not specified ") unless grep $_ eq $key, keys %opts;
    }
	my $srcfile = $self->parser_filename(SID=>$survey_id);
	$srcfile =~ s/$dir//;
	if ($opts{survey_id} && $opts{survey_id} ne $survey_id){
		# $self->err->W("Using survey_id '$survey_id' rather than '$opts{survey_id}'".
			# " from '$srcfile' in config.pl");
		$opts{survey_id} = $survey_id;
	}
    foreach (keys %opts ){
        push @lines, qq{\$$_ = '} . TPerl::Text::Quote->quote_quote ( $opts{$_} ) . q{';};
    }
	if (%jumps){
		push @lines, q{%jumps = ( };
		push @lines, qq{	'$_'=>'$jumps{$_}',} foreach keys %jumps;
		push @lines, q{); };
		
	}
	### now do @major_sections array if a coag.txt file exists
	my $coag_file = join '/',$troot,$job,'config','coag.txt';

	if (-e $coag_file){
		$self->err->I("Making \@major_sections from $coag_file");
		my $cg = getro TPerl::Dump ($coag_file);
		my $jobs = $cg->{jobs};
		my @lets = @$jobs;
		s/$job// foreach @lets;
		push @lines,'@major_sections=qw(' .join (' ',@lets) . ');';
	}
    push @lines, q{1;};
    foreach (@lines) { s/$/\n/ }
    overwrite_file (File::Spec->catfile ($dir,'config.pl'),@lines);
}

# --------------------------------------------------------------
# description: generic subroutine to check items within an array against a value
# comment: this f(x) is slated for default inclusion in newer perl and is part of most modern languages
# author: jello
# date: 4/28/2011
# revision: 1
# --------------------------------------------------------------
sub is_in {
	my $sought = shift;
	my @list = @_;
	foreach my $item(@list) {
		if ($sought eq $item) { 
			return 1;
		}
	}
	return 0;
}

1;
