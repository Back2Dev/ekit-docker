#$Id: Survey.pm,v 2.22 2011-07-26 09:11:55 triton Exp $

# Been though perltidy

package TPerl::Parser::HTMLParser;
use base 'HTML::Parser';
use Data::Dumper;

sub start {
    my $self  = shift;
    my $tag   = shift;
    my $attr  = shift;
    my $debug = $self->{ac_debug};
    $attr->{type} ||= $tag;
    push @{ $self->{inputs} }, $attr if grep lc $tag eq $_, qw(input textarea);
    if ( lc($tag) eq 'select' ) {
        # print "found a select ".Dumper $attr;
        $self->{current_select} = $attr;
    } elsif ( lc($tag) eq 'option' ) {
        $self->{in_option} = 1;
        if ( my $sel = $self->{current_select} ) {
            my %h = ( %$sel, %$attr );
            print "Combined hash " . Dumper \%h if $debug;
            push @{ $self->{inputs} }, \%h;
        } else {
            # print "orphan option\n";
        }
    }
}

sub text {
    my $self  = shift;
    my $text  = shift;
    my $debug = $self->{ac_debug};
    print "in text=$text\n" if $debug and $self->{in_option};
    # only allow the first bit of text....
    $self->{inputs}->[-1]->{label} = $text
      if $self->{in_option} and !( exists $self->{inputs}->[-1]->{label} );
}

sub end {
    my $self = shift;
    my $tag  = shift;
    $self->{current_select} = undef if lc($tag) eq 'select';
    $self->{in_option}      = undef if lc($tag) eq 'option';
}

sub inputs {
    my $self = shift;
    return $self->{inputs} || [];
}

package TPerl::Survey;
use strict;
use Data::Dumper;
use TPerl::TritonConfig;
use TPerl::Error;
use TPerl::MyDB;
use File::Path;
use File::Slurp;
use File::Copy;
use TPerl::CmdLine;
use TPerl::DBEasy;
use TPerl::Survey::Question;
use Cwd;
use Carp;

=head1 SYNOPSIS 

 ## Going to create or delete a job? 
 # you'll need directories, links, and database tables and 
 # survey2DHTML....
 use TPerl::Survey
 use Data::Dumper;
 my $s = new TPerl::Survey ('Goose123');
 print Dumper $s->dirs;
 print Dumper $s->links;
 print Dumper $s->tables;
 $s->survey2DHTML (world=>getConfig('scriptsDir');

 ###OR using a XXX123_survey.pl file
 #
 use File::Slurp;
 my $sfile = survey_file TPerl::Survey ($SID);
 $e->F("Survey file '$sfile' does not exist") unless -e $sfile;
 my $s = eval read_file $sfile;
 if ($@){
     $e->F("Eval error in '$sfile':@$");
 }

=head1 DESCRIPTION

Perl Module to create a new Triton Survey.  Should be run as the web server user.  The Default 
behavior is general but it is quite customisable.

A Survey also has questions.  

these are the methods

=head1 new 

make a new TPerl::Survey object.  does not actally do anything.
if there is only 1 argument this is the Survey ID.
other parameters include the following.  There access methods
for each of these.

=item SID

the Survey ID. 

=item TritonRoot

where the job files live on the File system


=item doc_root

the document root for this survey

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self  = {};
    bless $self, $class;

    my %args = ();
    my $job  = undef;
    if ( scalar @_ == 1 ) {
        $job = shift;
    } else {
        %args = @_;
        $job  = $args{SID};
    }

    ###programmer help
    confess('No Job Supplied') unless defined $job;

    $self->{_SID}           = $job;
    $self->{_TritonRoot}    = $args{TritonRoot} || getConfig('TritonRoot');
    $self->{_doc_root}      = $args{doc_root} || getConfig('doc_root');
    $self->{_config_subdir} = $args{config_subdir} || 'config';
    $self->{_html_subdir}   = $args{html_subdir} || 'html';
    $self->{_final_subdir}  = $args{html_subdir} || 'final';
    $self->{_data_subdir}   = $args{data_subdir} || 'web';
    $self->{_doc_subdir}    = $args{doc_subdir} || 'doc';

    ## allows a parsed text file to become a TPerl::Survey object, and
    # be saved to a file
    $self->{_questions} = $args{questions} || [];
    $self->{_masks}     = $args{masks}     || {};
    $self->{_options}   = $args{options}   || {};
    return $self;
}

=head1 err

this returns a TPerl::Error object for storing errors

=cut

sub err {
    my $self = shift;
    return $self->{_err};
}

### using AUTOLOAD makes this sort of thing easier.  these are all
#Read only methods
sub TR            { my $self = shift; return $self->{_TritonRoot}; }
sub SID           { my $self = shift; return $self->{_SID}; }
sub doc_root      { my $self = shift; return $self->{_doc_root}; }
sub options       { my $self = shift; return $self->{_options}; }
sub config_subdir { my $self = shift; return $self->{_config_subdir}; }
sub html_subdir   { my $self = shift; return $self->{_html_subdir}; }
sub final_subdir  { my $self = shift; return $self->{_final_subdir}; }
sub data_subdir   { my $self = shift; return $self->{_data_subdir}; }
sub doc_subdir    { my $self = shift; return $self->{_doc_subdir}; }

=head1 dirs

returns a list of hash refs with inofrmation about necessary directories
for a Survey.  each hashref follows this format

	{
		name=>'html',
		pretty=>'Triton Survey html Directory',
		e=><result of the perl -e test>
		w=><result of the perl -w test>
		dir=><the path in question>
	}

This list may be manipulated and passed back to this function with
either the rm or mk parameters.

for example to change the path the html dir

	my $dirs = $s->dirs;
	foreach my $dir (@$dirs){
		$dir->{dir} = 'some/other/path' if $dir->{name} eq 'html';
	}
	$new_dirs = $s->dirs(dirs=>$dirs,mk=>1)

Of course the dirs parameter is optional if you do not want to make any chnages

=cut

sub dirs {
    my $self = shift;
    my %args = @_;

    my $mk = $args{mk};
    my $rm = $args{rm};

    my $dirs = $args{dirs} || [
        {
            name   => 'SurveyRoot',
            pretty => 'Triton Root html Directory',
            dir    => join( '/', $self->TR, $self->SID ),
        },
        {
            name   => 'config',
            pretty => 'Triton Root config Directory',
            dir    => join( '/', $self->TR, $self->SID, $self->config_subdir ),
        },
        {
            name   => 'html',
            pretty => 'Triton Root html Directory',
            dir    => join( '/', $self->TR, $self->SID, $self->html_subdir ),
        },
        {
            name   => 'web',
            pretty => 'Triton Root html Directory',
            dir    => join( '/', $self->TR, $self->SID, $self->data_subdir ),
        },
        {
            name   => 'doc',
            pretty => 'Triton Root doc Directory',
            dir    => join( '/', $self->TR, $self->SID, $self->doc_subdir ),
        },
        {
            name   => 'incoming',
            pretty => 'Triton Root incoming Directory',
            dir    => join( '/', $self->TR, $self->SID, 'incoming' ),
        },
        {
            name   => 'outgoing',
            pretty => 'Triton Root outgoing Directory',
            dir    => join( '/', $self->TR, $self->SID, 'outgoing' ),
        },
        {
            name   => 'cgi-mr',
            pretty => 'Triton Root doc Directory',
            dir    => join( '/', $self->TR, $self->SID, 'cgi-mr' ),
        },
        {
            name   => 'bin',
            pretty => 'Triton Root doc Directory',
            dir    => join( '/', $self->TR, $self->SID, 'bin' ),
        },
        {
            name   => 'deleted',
            pretty => 'Triton Root doc Directory',
            dir    => join( '/', $self->TR, $self->SID, 'deleted' ),
        },
        {
            name   => 'logs',
            pretty => 'Triton Root Logs Directory',
            dir    => join( '/', $self->TR, $self->SID, 'logs' ),
        },

    ];
    foreach my $dir (@$dirs) {
        $dir->{mk} = mkpath( $dir->{dir} ) if ($mk);
        $dir->{rm} = rmtree( $dir->{dir}, 0, 1 ) if ($rm);
        $dir->{e}  = -e $dir->{dir};
        $dir->{w}  = -w $dir->{dir};
    }
    return $dirs;
}

sub links {
    my $self = shift;
    my %args = @_;

    my $mk = $args{mk};
    my $rm = $args{rm};

    my $links = $args{links}
      || [
        {
            name => 'html',
            new => join( '/', $self->doc_root, $self->SID ),
            existing => join( '/', $self->TR, $self->SID, 'html' ),
            pretty   => 'Activation Link',
        },
      ];
    foreach my $l (@$links) {
        if ($mk) {
            my $symlink_exists = eval { symlink( "", "" ); 1 };
            $l->{mk} = symlink( $l->{existing}, $l->{new} )
              if ($symlink_exists);
            $l->{err} = $! unless $l->{retval};
        }
        if ($rm) {
            $l->{rm} = unlink $l->{new};
            $l->{err} = $! unless $l->{rm};
        }
        $l->{e} = -e $l->{new};
    }
    return $links;
}

sub tables {
    my $self = shift;
    my %args = @_;

    my $mk = $args{mk};
    my $rm = $args{rm};

    my $job = $self->SID;
    my $dbh = $args{dbh};
    unless ($dbh) {
        my $db = $args{db} || '';
        $dbh = dbh TPerl::MyDB( db => $db );
    }

    my $tables = $args{tables} || [
        {
            create => qq{ CREATE TABLE ${job}_E (
                SID                             VARCHAR(10) Not Null ,
                TS                              INTEGER Not Null ,
                EVENT_CODE                      INTEGER Not Null ,
                SEVERITY                        CHAR(1) Not Null ,
                WHO                             VARCHAR(10) Not Null ,
                CAPTION                         VARCHAR(200) ,
                BROWSER                         VARCHAR(12) ,
                BROWSER_VER                     VARCHAR(8) ,
                OS                              VARCHAR(12) ,
                OS_VER                          VARCHAR(8) ,
                IPADDR                          VARCHAR(15) ,
                PWD                             VARCHAR(12) ,
                EMAIL                           VARCHAR(80) ,
                YR                              INTEGER ,
                MON                             INTEGER ,
                MDAY                            INTEGER ,
                HR                              INTEGER ,
                MINS                            INTEGER
            	)		
					},
            name   => "${job}_E",
            pretty => "$job Event Table",
        },
        {
            create => qq{ CREATE TABLE $job (
                PWD                             VARCHAR(12) Not Null ,
                UID                             VARCHAR(50) ,
                STAT                            INTEGER ,
                FULLNAME                        VARCHAR(60) ,
                TS                              INTEGER ,
                EXPIRES                         INTEGER ,
                SEQ                             INTEGER ,
                REMINDERS                       INTEGER ,
                EMAIL                           VARCHAR(80) ,
                BATCHNO                         INTEGER,
				PRIMARY KEY (PWD)
				)	},
            name   => $job,
            pretty => "$job Participants Table",
        }
    ];
    my @table_list = $dbh->tables;
    s/^\W*(.*?)\W$/$1/ foreach @table_list;

    foreach my $t (@$tables) {
        $t->{e} = grep uc($_) eq uc( $t->{name} ), @table_list;
        if ($mk) {
            if ( $t->{e} ) {
                $t->{err} = "$t->{name} exists database";
            } else {
                if ( $dbh->do( $t->{create} ) ) {
                    $t->{mk} = 1;
                    $t->{e}  = 1;
                } else {
                    $t->{err} = $dbh->errstr;
                }
            }
        }
        if ($rm) {
            if ( $t->{e} ) {
                if ( $dbh->do("DROP TABLE $t->{name}") ) {
                    $t->{rm} = 1;
                    $t->{e}  = 0;
                } else {
                    $t->{err} = $dbh->errstr;
                }
            } else {
                $t->{err} = "$t->{name} does not exist";
            }
        }
    }
    return $tables;
}

sub make {
    # Another constructor.
    my $self = shift;
    $self = $self->new(@_) unless ref($self);
    $self->dirs( mk => 1 );
    $self->tables( mk => 1 );
    $self->links( mk => 1 );
    return $self;
}

sub survey2DHTML {
    my $self = shift;
    my %args = @_;

    my $world = $args{world};
    my $debug = $args{debug};
    my $SID   = $self->SID;

    $debug = '-d' if $debug;
    $debug = '' unless $debug;

    my $cmd  = "perl -s aspsurvey2DHTML.pl $debug -no_wait generate $SID";
    my $cmdl = new TPerl::CmdLine;
    my $out  = $cmdl->execute( cmd => $cmd, dir => $world );
    return $out;
}

### now you want to get some fields for the invite table

sub job_fields {
    my $self = shift;
    my %args = @_;
    my $dbh  = $args{dbh};
    my $SID  = $self->SID;

    foreach (qw (dbh)) {
        confess("$_ is required") unless $args{$_};
    }

    my $ez          = new TPerl::DBEasy;
    my %custom_info = ();
    $custom_info{PWD} = $ez->field( type => 'hidden' );
    $custom_info{TS}  = $ez->field( type => 'epoch' );
    my $fields = $ez->fields( table => $SID, dbh => $dbh, %custom_info );
    my %status = (
        0 => 'Ready',
        2 => 'Refused',
        3 => 'Incomplete',
        4 => 'Complete',
        5 => 'Mail Returned',
        6 => 'Removed'
    );
    $fields->{STAT}->{cgi}->{func} = 'popup_menu';
    $fields->{STAT}->{cgi}->{args} =
      { -labels => \%status, -values => keys %status };
    return $fields;
}

sub questions_by_label {
    my $self = shift;
    my $ret  = {};
    my $qs   = $self->questions || [];
    foreach my $q (@$qs) {
        $ret->{ uc( $q->label ) } = $q;
    }
    return $ret;
}

### Now some stuff that intersects with the parser...
sub questions {
    my $self = shift;
    return $self->{_questions};
}

### setDataInfo
sub getDataInfo {
    return [

    ];

}

sub survey_file {
    my $self = shift;
    my $SID  = shift;
    my %args = @_;

    my $troot = $args{troot} || getConfig('TritonRoot');
    return join '/', $troot, $SID, 'config', $SID . '_survey.pl';
}

sub external_info {
    my $self = shift;
    my %args = @_;
    my $err  = $args{err} || new TPerl::Error();

    my $SID       = $self->SID;
    my $troot     = $self->TR;
    my $externals = {};

    foreach my $q ( @{ $self->questions } ) {
        my $lab = $q->label;
        if ( my $extbase = $q->external ) {
            # my $debug = 1 if $extbase =~ /relatives/;
            my $debug = 0;
            print "Found ext $extbase\n" if $debug;
            my $efile = join '/', $troot, $SID, 'html', $extbase;
            push @{ $externals->{order} }, $extbase;
            if ( -e $efile ) {
                my $p = new TPerl::Parser::HTMLParser;
                $p->{ac_debug} = $debug;
                $p->parse_file($efile);
                my $inpts = $p->inputs;
                foreach my $inpt (@$inpts) {
                    next
                      if grep $inpt->{name} eq $_,
                      qw(jump_to seqno survey_id q_no);
                    next if $inpt->{type} eq 'button';
                    push @{ $externals->{pages}->{$extbase}->{names} },
                      $inpt->{name}
                      unless grep $_ eq $inpt->{name},
                      @{ $externals->{pages}->{$extbase}->{names} };
                    next if $inpt->{value} =~ /<%$inpt->{name}%>/;
                    next if $inpt->{value} =~ /<%ext_$inpt->{name}%>/;
# lets put all the options in one hash.  types is only used in the setDataInfo...
# $externals->{pages}->{$extbase}->{types}->{$inpt->{name}} ||=$inpt->{type} if $inpt->{type} ne 'option';
                    $externals->{pages}->{$extbase}->{options}
                      ->{ $inpt->{name} } ||= $inpt
                      ; #  now its safe to put these in....if $inpt->{type} ne 'option';
                        # print Dumper $inpt if  $inpt->{type} eq 'option';
                    if ( $inpt->{value} ne '' ) {
                        # print "Found a value in $extbase".Dumper $inpt;
                        push @{ $externals->{pages}->{$extbase}->{values}
                              ->{ $inpt->{name} } }, $inpt->{value};
                        if ( ( $inpt->{label} ne '' ) ) {
                            $externals->{pages}->{$extbase}->{labels}
                              ->{ $inpt->{name} }->{ $inpt->{value} } =
                              $inpt->{label};
                        }
                    }
                }
                foreach my $var (
                    keys %{ $externals->{pages}->{$extbase}->{values} } )
                {
                    my $vals = $externals->{pages}->{$extbase}->{values}->{$var}
                      || [];
                    foreach my $val (@$vals) {
#The engine now copes with non-integer values.
# $err->W("Ext var $extbase:$var has a non integer value:$val") if $val !~ /^\d+$|<%.*?%>/;
                    }
                }
                print Dumper $externals->{pages}->{$extbase} if $debug;
            } else {
                $err->E("Could not find external '$efile' in question $lab");
            }
        }
        if ( my $js = $q->javascript ) {
            my ( $f, $fn ) = split /,/, $js;
            my $file = join '/', $troot, $SID, 'html', $f;
            $err->E("Could not find javascript file '$file' in question $lab")
              unless -e $file;
        }
    }
    if (%$externals) {
        my $extfile = join '/', $troot, $SID, 'config', 'external_vars.txt';
        $err->I("Writing info about external html vars  to $extfile");
        justput TPerl::Dump( $extfile, $externals );
        my $evars = {};
        foreach my $page ( @{ $externals->{order} } ) {
            my $names = $externals->{pages}->{$page}->{names};
            foreach my $evar (@$names) {
                # push @{$evars->{$evar}},$page;
            }
        }
        foreach my $evar ( keys %$evars ) {
# In NAGS et al the externals look at each others data..
# $self->err->E(sprintf "Ext var $evar is in too many files:%s",join ',',@{$evars->{$evar}}) if scalar @{$evars->{$evar}}>1;
        }
    }
    return $externals;
}

sub from_file {
    # Sort of like a constructor.  Sets $! on failure.
    my $self = shift;
    my $fn   = $self->survey_file(@_);
    unless ($fn) {
        $! = 'Could not get filename';
        return undef;
    }
    unless ( -e $fn ) {
        $! = "file '$fn' does not exist";
        return undef;
    }

    my $s = eval read_file $fn;
    if ($@) {
        $! = "Eval error in '$fn':$@";
        return undef;
    }
    return $s;
}

1;
