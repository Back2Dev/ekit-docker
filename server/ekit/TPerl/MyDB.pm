#!/usr/bin/perl
#
# $Id: MyDB.pm,v 1.35 2011-07-26 20:52:31 triton Exp $
#Copyright Triton Technology 2001
#
# Package to provide a database layer for TPerl
#
package TPerl::MyDB;

use strict;
use DBI;
use CGI;
use Data::Dumper;
use TPerl::TritonConfig;
use Carp qw(confess);
use File::Temp;

=head1 SYNOPSIS

Yet another DBI wrapper

 my $dbh = dbh TPerl::MyDB (db=>$db) or
    print "Could not connect to $db:".TPerl::MyDB->err."\n";


=head1 DESCRIPTION

Its good to be able to refer to database's with just one string name

 my $dbh = dbh TPerl::MyDB (db=>$db,debug=>1,attrs=>{PrintError=>0,RaiseError=>0}) or
    print "Could not connect to $db:".TPerl::MyDB->err."\n";

The options for the DBI->connect call are 
got from TPerl::TritonConfig->getdbConfig calls
for a database ib we need
 
 ib_db_file=/opt/interbase/triton.gdb
 ib_db_user=username
 ib_db_password

also possible are

 ib_db_options=ib_dialect=3;host=palaeo;
 ib_db_driver=InterBase

but this module tries to guess these

It is now also possible to omit the db=> parameter completely, in which case this module will 
look for a EngineDB= entry in the config, hoping that it is present. It dies if it can't find a 
database name there.

=cut

###Package global
use vars qw($err);

my $mydbh;		# Place to cache a dbh for lazy callers

sub dbh {
	my $self = shift;
	$mydbh = $self->_connect (@_);
	return $mydbh;
}

sub driver {
    my $self   = shift;
    my $db     = shift || confess "First param must be a 'db'";
    my $driver = getdbConfig( $db . '_db_driver' );
    $driver ||= 'InterBase' if $db =~ /^ib/;
    $driver ||= 'mysql'     if $db =~ /^mysql/;
    unless ($driver) {
        $err = "No  ${db}_db_driver from TritonConfig";
        return undef;
    }
    return $driver;

}

sub tmp_db {
    # lets make a db in a temp file.
	# Gets same defaults etc at the others specified in server.ini
    my $self    = shift;
    my %args    = @_;
    my $debug   = $args{debug};
    my $db      = $self->db( $args{db} ) || return;
    my $driver  = $self->driver($db) || return;
    my $options = $self->options( $db, $driver );

    my $user = getdbConfig( $db . '_db_user' );
    my $pass = getdbConfig( $db . '_db_password' );

    confess("Only works for driver 'InterBase', not '$driver'")
      unless $driver eq 'InterBase';

	my $isql = '/opt/interbase/bin/isql' if -e '/opt/interbase/bin/isql';
	$isql = '/usr/bin/isql-fb' if -e '/usr/bin/isql-fb';

	confess "could not find isql '/opt/interbase/bin/isql' or '/usr/bin/isql-fb'" unless $isql;

    my $fh = new File::Temp();
    my $fn = $fh->filename;
    $fh->close;
	unlink $fn;

	my $sql_fh = new File::Temp();
	my $sql_fn = $sql_fh->filename;
	print $sql_fh "create database '$fn';exit;\n\n";
	$sql_fh->close;

	my $cmd = qq{$isql -user $user -password $pass  -i $sql_fn -echo};
	system ($cmd) == 0 or confess "$cmd failed:$?";
	# chmod (0777,$fn) || confess "Could not chmod $fn";
	
    return $fn;
}


sub options {
    my $self    = shift;
    my $db      = shift || confess "First param must be a 'db'";
    my $driver  = shift || $self->driver($db);
    my $options = getdbConfig( $db . '_db_options' );
    $options ||= 'ib_dialect=3' if $driver eq 'InterBase';
    $options = ";$options" if $options and $options !~ /^;/;
	return $options;
}

sub db {
	my $self = shift;
	my $db = shift;

	#$db = getdbConfig ('EngineDB') if ($db eq '');
	if (!$db) { $db = getdbConfig ('EngineDB'); }

	if ($db eq '')
		{
		$db = getdbConfig ('default');
		print "[W] Warning - [database] default= directive is deprecated, use EngineDB=\n" if ($db ne '');
		}
	confess("No database name specified either with subroutine call, or as EngineDB= in server.ini\n") if ($db eq '');
	return $db;
}

sub dsn {
	my $self = shift;
	my %args = @_;
	my $db = $self->db($args{db});
	my $db_file = $args{db_file};

	# Leave this test even though the previous one confessesss
	if ($db){
		my $database;
		$database = $db_file || getdbConfig ($db.'_db_file');
		unless ($database){
			$err = "No ${db}_db_file from TritonConfig";
			return undef;
		}
		my $driver;
		$driver = $self->driver($db) || return;
		my $options;
		$options = $self->options($db,$driver);
		my $dsn;
		if ($options) {
			$dsn = "DBI:$driver:database=$database$options;";
		} else {
			$dsn = "DBI:$driver:database=$database;";
		}
		return $dsn;
	}else{
		$err = "no db parameter sent";
		return undef;
	}
}

sub _connect {
	# A wrapper round DBI::connect
	# build the first $data_source ($dsn) param from the server.ini file.
	# EngineDB in the [database] section is the default.
	# This accepts args of
	# 	db 	    => specify which db in server.ini to connect to
	# 	debug   => prints out much info.
	# 	db_file => override the ${db}_db_file param from server.ini.  
	# 	           Useful if you have used tmp_db to create a temp one.
	#
	my $self = shift;
	my %args = @_;

	my $debug = $args{debug};
	my $db = $self->db($args{db});
	my $attr = $args{attr};
	$attr->{FetchHashKeyName} = 'NAME_uc' unless defined $attr->{FetchHashKeyName};

	if (my $dsn = $self->dsn (%args)){
		my $user = getdbConfig ($db.'_db_user');
		my $pass = getdbConfig ($db.'_db_password');
		print Dumper {dsn=>$dsn,user=>$user,attr=>$attr} if $debug;
		if (my $dbh = DBI->connect($dsn,$user,$pass,$attr)){
			print "Connected ".Dumper $dbh if $debug;
			if ( $dsn =~/InterBase/){
				print "Setting ib_ date formats\n" if $debug;
				$dbh->{ib_time_all}='ISO';
				# $dbh->{ib_timestampformat} = '%Y %m %d %H:%M:%S';
				# $dbh->{ib_dateformat} = '%Y %m %d';
				# $dbh->{ib_timeformat} = '%H:%M:%S';
			}
			if ($debug){
				print "Interbase $_=$dbh->{$_}\n" foreach 
					qw (ib_timestampformat ib_dateformat ib_timeformat);
			}
			return $dbh;
		}else{
			# $dbs->{$db}->{err} =  DBI->errstr;
			$err = DBI->errstr;
			print "err=$err\n" if $debug;
			return undef
		}
	}else{
		# error message set by dsn function...
		return undef;
	}
}

=head2 sth

This is DEPRECATED.

a method that can return all sorts of stuff,
by default returns a prepared executed sth

 no_execute  prepare the sth only
 results return an array_ref of fetchrow_hashref's

=cut

sub sth {
	my $self = shift;
	my %args = @_;

	die "There are heaps better ways to do this goose";

	#print "sth args ".Dumper \%args;

	my $sql = $args{sql};
	my $debug =$args{debug};
	if ($sql){
		my $exec= 1 unless $args{no_execute};
		my $no_results = 1 unless $args{results};
		my @params =  ();
		@params = @${$args{params}};

		my $db = $args{db};
		print "TPerl::MyDB->sth db=$db sql=$sql\n" if $debug;
		print "TPerl::MyDB->sth params  ".Dumper (\@params) if $debug;

		return undef unless my $dbh=$self->_connect(db=>$db);
		if ( my $sth=$dbh->prepare($sql) ){
			return $sth unless $exec;
			if ($sth->execute(@params)){
				return $sth if $no_results;
				my @rows=();
				while (my $hash_ref = $sth->fetchrow_hashref){
					push @rows, $hash_ref;
				}
				return \@rows;
			}else{
				$err =  "Could not execute $sql\n params ".Dumper (\@params) .
					DBI->errstr;  return undef
			}
		}else { $err = "Could not prepare $sql " . DBI->errstr;  return undef}
	}else{
		$err = "must set sql";
		return undef;
	}
}

sub err {
	return $err;
}

=head2 table_list

THIS IS DEPRECATED

returns an sth that wil provide a list of tables in a database
http://community.borland.com/article/0,1410,25172,00.html
or google interbase system tables

=cut

sub table_list{
	my $self = shift;
	my %args = @_;
	die "use the tables method of the DBI you GOOSE\n";
}


sub db_do
	{
	my $self = shift;
	my %args = @_;
	
    my $sql = $args{sql};
    my $dbh = ($args{dbh} ) ? $args{dbh} : $mydbh;		# Use local dbh copy (assumes call to connect has been done already)
    my @params;
    print Dumper \%args if ($args{debug});
    @params = (@{$args{params}}) if ($args{params});
    print "Preparing SQL statement: [$sql]".join(",",@params)."\n" if ($args{debug});
    my $th = $dbh->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
    print "Executing SQL statement\n" if ($args{debug});
    if (!$th->execute(@params))
    	{
    	print "SQL execute errror with sql=[$sql]: $DBI::errstr\n";
	    $th = undef;
		}
    $th;
	}

sub db_map
	{
	my $self = shift;
	my %args = @_;

	my @columns;
	my @vals;
# This looks like some sort of new function in the making, but not finished yet, so I patch to make it compile.
my ($row,%hash,@cols,$i);
	my @data = split(/\t/,$row);
	foreach my $col (@{$args{cols}})
		{
		next if ($args{data}{$col} eq '');
#		next if (!$column_map{$cols[$i]});			# NB presence of column is used to determine if we want it at this stage 
		$hash{$col} = $args{data}{$col};
		push @columns,$cols[$i];
		push @vals,$args{data}{$col};
		}
# Do we need to jam in another one ?
#				if ($hash{EARLY_ARRIVAL} =~ /Y/i)						# Special procesing for early arrival - need to set the date
#					{
#					my $day_prior = &DateCalc(&ParseDate($hash{WSDATE_D}),"-1d");
#					push @columns,'EARLY_ARRIVAL_DATE';
#					push @vals,UnixDate($day_prior,"20%y-%m-%d");;
#					}
#				$e->I("$hash{FULLNAME} $hash{LOCID} $hash{WSDATE_D}");
	my $clist = join(",",@columns);
	my $plist = $clist;
	$plist =~ s/\w+/?/g;
# Insert the new data
	if ($args{sql} =~ /INSERT/i)
		{
			my $sql = qq{$args{sql} ($clist) VALUES ($plist)};
		$self->dbo_do($sql,@vals);
		}
	}

1;



