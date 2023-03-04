#$Id: db.pl,v 1.15 2007-08-23 01:16:57 triton Exp $
# Quicky to replace isql.
use strict;
use TPerl::MyDB;
use Getopt::Long;
use TPerl::Error;
use Data::Dumper;
use Data::Dump qw (dump);
use TPerl::TritonConfig;
use TPerl::DBEasy;
use FileHandle;
use File::Slurp;

my $db       = getdbConfig('EngineDB') || 'ib';
my $sep      = "\t";
my $e        = new TPerl::Error;
my @params   = ();
my $verbose  = 1;
my $help     = 0;
my $tables   = 0;
my $dsn      = 0;
my $debug    = 0;
my $dump     = [];
my $fields   = [];
my $cols   = [];
my $lister   = 1;
my $sql_from = '';
my $backup	 = 0;

GetOptions(
    'p:s'         => \@params,
    'h!'          => \$help,
    'db:s'        => \$db,
    'tables!'     => \$tables,
	'backup'	  => \$backup,
    'dsn!'        => \$dsn,
    'debug!'      => \$debug,
    'dump:s'      => $dump,
    'fields:s'    => $fields,
    'cols:s'    => $cols,
    'lister!'     => \$lister,
    'sep:s'       => \$sep,
    'read_from:s' => \$sql_from,
    'verbose!'    => \$verbose,

) or $e->F("Bad options");

usage() if $help;

sub usage {
    my $msg = shift;
    print "$msg\n" if $msg;
    print
qq{\tUsage $0 [options] 'select * from table where pwd=? and uid=?' -p=1234 -p=GOOSE\n};
    print qq{ options include
  db	database name
  h		help
  tables	display tables and exit
};
    exit;
}
my $sql = join ' ', @ARGV;
if ($sql_from) {
    $e->F("File '$sql_from' does not exist") unless -e $sql_from;
    $sql = read_file($sql_from);
}

if ($dsn) {
    my $dsn = dsn TPerl::MyDB( db => $db, debug => $debug );
    $e->I("dsn 0f '$db' is '$dsn'");
}

my $dbh = dbh TPerl::MyDB(
    db    => $db,
    attr  => { PrintError => 0, RaiseError => 0 },
    debug => $debug
) or $e->F( "Could not connect to db '$db':" . TPerl::MyDB::err() );

if ($tables) {
    my @tables = $dbh->tables;
    s/^[`'"](.*?)[`'"]$/\1/ foreach @tables;
	my $msg = '%s';
	$msg =  "Tables in '$db' are:\n%s\n" if $verbose;

    printf $msg, join "\n", @tables;
    exit;
}

if ($backup){
    my @tables = $dbh->tables;
    s/^[`'"](.*?)[`'"]$/\1/ foreach @tables;
    my $ez = new TPerl::DBEasy( dbh => $dbh );
	my $fn = 'backup.sql';
	if ( my $fh = new FileHandle("> $fn") ) {
		foreach my $tb (@tables) {
			if ( my $err = $ez->table2file( fh => $fh, table => $tb ) ) {
				$e->E( "Trouble with $tb " . Dumper $err);
			} else {
				$e->I("Dumped '$tb' to '$fn'");
			}
		}
	} else {
		$e->E("Could not create '$fn':$!");
	}
    exit;
}

if (@$dump) {
    my $ez = new TPerl::DBEasy( dbh => $dbh );
    foreach my $tb (@$dump) {
        my $fn = "/tmp/$tb.txt";
        if ( my $fh = new FileHandle("> $fn") ) {
            if ( my $err = $ez->table2file( fh => $fh, table => $tb ) ) {
                $e->E( "Trouble with $tb " . Dumper $err);
            } else {
                $e->I("Dumped '$tb' to '$fn'");
            }
        } else {
            $e->E("Could not create '$fn':$!");
        }
    }
    exit;
}
if (@$fields) {
    my $ez = new TPerl::DBEasy( dbh => $dbh );
    foreach my $table (@$fields) {
        print Dumper $ez->fields( table => $table );
    }
}
if (@$cols) {
    my $ez = new TPerl::DBEasy( dbh => $dbh );
    foreach my $table (@$cols) {
        my $f = $ez->fields( table => $table );
        print
          join( ',', sort { $f->{$a}->{order} <=> $f->{$b}->{order} } keys %$f )
          . "\n";
    }
}

if ($sql) {
    $e->I("Do $sql in $db") if $verbose;
    $e->I( "with params " . dump( \@params ) ) if $verbose && @params;
    if ( $sql =~ /^\s*select/i ) {
        my $sth = $dbh->prepare($sql)
          or $e->F( "Could not prepare $sql:" . $dbh->errstr );
        $e->F( "Could not execute $sql:" . $dbh->errstr )
          unless $sth->execute(@params);
        my $count = 0;
        if ($lister) {
            my $ez     = new TPerl::DBEasy( dbh => $dbh );
            my $fields = $ez->fields( sth       => $sth );
            my @f = $ez->sort_fields($fields);
            print join( $sep, @f ) . "\n" if $verbose;
            while ( my $row = $sth->fetchrow_hashref ) {
                $count++;
                print join(
                    $sep,
                    map $ez->field2val(
                        dbh   => $dbh,
                        field => $fields->{$_},
                        row   => $row
                    ),
                    @f
                ) . "\n";

            }
        } else {
            my $names = $sth->{NAME};
            print join( $sep, @$names ) . "\n" if $verbose;
            while ( my $row = $sth->fetchrow_arrayref ) {
                $count++;
                print join( $sep, @$row ) . "\n";
            }
        }
        print "$count rows\n" if $verbose;
    } else {
        my $ret = $dbh->do( $sql, {}, @params );
        $e->F("SQL:$sql\nParams:@params\n$_") if $_ = $dbh->errstr;
        $e->I("$ret rows affected");
    }
}

