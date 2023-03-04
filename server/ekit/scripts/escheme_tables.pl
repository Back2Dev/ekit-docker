use strict;
#$Id: escheme_tables.pl,v 1.4 2007-07-12 00:49:10 triton Exp $
use TPerl::EScheme;
use TPerl::MyDB;
use FileHandle;
use Getopt::Long;
use Data::Dumper;
use TPerl::Error;
use Pod::Usage;

=head1 SYNOPSIS

Does table stuff for the Eschemes.  See EScheme.pm for detail of tables.  To
create tables.

 perl scripts/escheme_tables.pl --create
 perl scripts/escheme_tables.pl --dump --drop --create --read

to Duplicate a scheme 4

 perl scripts/escheme_tables.pl -cps 4

to Remove (delete) scheme 3

 perl scripts/escheme_tables.pl -rms 3

to Tear off a scheme 2 with pwd 1234

 perl scripts/escheme_tables.pl -ts i=2:p=1234:l=sp:s='Next Week'

=cut

my $e = new TPerl::Error;

my $dump = 0;
my $read = 0;
my $dump_file = 'db_dump_escheme';
my $drop = 0;
my $create = 0;
my $db  ;
my $help = 0;
my $debug = 0;

## These are custom persistant email things.
my $del_scheme = [];
my $cp_scheme = [];
my $tear_off = [];
my $rm_tear = [];

GetOptions (
        'dump+'=>\$dump,
        'read+'=>\$read,
        'file:s'=>\$dump_file,
        'create+'=>\$create,
        'drop+'=>\$drop,
        'db:s'=>\$db,
        'help+'=>\$help,
        'debug!'=>\$debug,

		'rms:i'=>$del_scheme,
		'cps:i'=>$cp_scheme,
		'ts:s'=>$tear_off,
		'rmt:i'=>$rm_tear,
) or $e->F("Bad Options");

pod2usage(1) if $help;


my $dbh = dbh TPerl::MyDB(db=>$db,debug=>$debug) or
    die "canna connect to db '$db'". TPerl::MyDB->err();

my $thing = new TPerl::EScheme (dbh=>$dbh);

my $tables = $thing->table_create_list;
if ($dump){
    my $fh = new FileHandle ("> $dump_file") or die "canna open dump file for writing:$!";
    die "table2file error:$_" if $_ = $thing->tables2file(fh=>$fh,dbh=>$dbh);
}
my %args = ();
$args{create} = $tables if $create;
$args{drop} = $tables if $drop;

my $err = $thing->do_tables(%args);
print "do_tables error ".Dumper $err if $err;

if ($read){
    my $fh = new FileHandle $dump_file or $e->F("Could not open '$dump_file':$!");
    my $errs = $thing->file2tables(fh=>$fh, print_sql=>1);
    print Dumper $errs if $errs;
}

if (@$del_scheme){
	# $thing->dbh->begin_work;
	foreach my $ds (@$del_scheme){
		die $thing->err unless $thing->delete_scheme(scheme_id=>$ds);
		print "Deleted scheme id $ds\n";
	}
	# $thing->dbh->commit;
}
if (@$cp_scheme){
	# $thing->dbh->begin_work;
	foreach my $cp (@$cp_scheme){
		my $new_id = $thing->duplicate_scheme(scheme_id=>$cp);
		die "Error copying '$cp':".Dumper ($thing->err) unless $new_id;
		print "Copied scheme $cp to $new_id\n";
	}
	# $thing->dbh->commit;

}
if (@$tear_off){
	my $arg_list = [];
	my $allowed = {i=>'scheme_id',p=>'password',l=>'language',s=>'scheme_start'};
	foreach my $ts (@$tear_off){
		my @bits = split /:/,$ts;
		my $args = {tear_off=>1};
		foreach my $b (@bits){
			my ($k,$v) = split /=/,$b,2;
			die "Malformed tearoff $b of '$ts'. example is -ts p=1234:l=sp" unless $allowed->{$k};
			$args->{$allowed->{$k}} = $v;
		}
		die "$ts needs at least i=1:p=1234\n".Dumper $args unless $args->{password} and $args->{scheme_id};
		push @$arg_list,$args;
	}
	# $thing->dbh->begin_work;
	foreach my $args (@$arg_list){
		my $new_id = $thing->duplicate_scheme(%$args);
		die "Could not tear off ".Dumper ($args). Dumper($thing->err) unless $new_id;
		print "copied EMAIL_SCHEME $args->{scheme_id} to EMAIL_SCHEME_STATUS $new_id\n";
	}
	# $thing->dbh->commit;
}
if (@$rm_tear){
	$thing->dbh->begin_work;
	foreach my $dt (@$rm_tear){
		die "could not delete tear '$dt':".Dumper ($thing->err) unless
			$thing->delete_scheme(scheme_id=>$dt,tear_off=>1);
		print "Deleted EMAIL_SCHEME_STATUS:$dt\n";
	}
	$thing->dbh->commit;
}

