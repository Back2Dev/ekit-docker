#!/usr/bin/perl
## $Id: qtdb.pm,v 1.9 2006/09/28 01:11:51 triton Exp $
#
# Library for Triton database access
# reworked for use strict by AC.

use TPerl::Event;

=head1 SYNOPSIS

This is the use strict version of qtdb.pl without global vars etc...

 use strict;
 use TPerl::MyDB;
 use TPerl::qtdb;
 
 my $db = 'ib';
 my $dbh = dbh TPerl::MyDB(db=>$db) or die "Could not connect to db '$db'".err TPerl::MyDB;
 
 my $qtdb = new TPerl::qtdb(dbh=>$dbh);
 
 if (my $pwd = $qtdb->db_getnextpwd('AND111')){
     print "pwd=$pwd\n";
 }else{
     die "Could not get a password:".$qtdb->err
 }

=cut


package TPerl::qtdb;
use strict;
use Carp qw (confess);
use Data::Dumper;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self,$class;
    my %args = @_;
    confess "dbh is required param" unless $args{dbh};
    $self->{dbh} = $args{dbh};
    return $self;
}

sub err { my $self = shift; $self->{err} = $_[0] if @_; return $self->{err}; }
sub dbh { my $self = shift; return $self->{dbh};}

# MOve these too Tperl::Engine.
# sub pw_generate    {          
# 	my $self=shift;
# 
#     # Since '1' is like 'l' and '0' is like 'O', don't generate passwords with them.
#     # Also I,J,L,O,Q,V                                             
#     # This will just confuse people using ugly fonts.                                                                                                                               #   
#     my @passset = ('A'..'H','K','M','N','P','R'..'U','X'..'Z');
# 	#, 'A'..'N', 'P'..'Z', '2'..'9') ;
#     my $rnd_passwd = "";
#     my $lastwun = '';
# 	my $i=0;
#     while ($i < 8)
#         {
#         my $randum_num = int(rand($#passset + 1));
#         my $this = @passset[$randum_num];
# 		# print "th=$this lw=$lastwun i=$i\n";
#         if ($this ne $lastwun)
#                 {
#                 $rnd_passwd .= $this;
#                 $lastwun = $this;
#                 $i++;
#                 }
#         }
#     return $rnd_passwd;
# }
# sub db_getnextpwd {
# 	my $self=shift;
# 	my $sid = shift;
# 	unless ($sid){
# 		$self->err("SID must be first param to db_getnextpwd");
# 		return undef;
# 	}
# 	my $unique = 0;
# 	my $loopcnt = 0;
# 	my $newpwd = '';
# 	my $dbh = $self->dbh;
# 	# print Dumper [$dbh->tables];
# 	unless (grep /^\W*$sid\W*$/i,$dbh->tables){				# MYSQL on Windows creates the tables with lower case names, hence the case-insensitive search
# 		$self->err("Table $sid not in database");
# 		return undef;
# 	}
# 	while (!$unique) {
# 		$newpwd = $self->pw_generate();                   # What the user must type in
# 		my $sql = "SELECT COUNT(*) FROM $sid WHERE PWD=?";
# 		my $rows = $dbh->selectall_arrayref($sql,{},$newpwd);
# 		# print $loopcnt . Dumper $rows;
# 		$unique = 1 if ($rows->[0]->[0] eq "0");
# 		$loopcnt++;
# 		if ($loopcnt > 100) {
# 			$self->{err} = ('Failed to find new password after 100 attempts');
# 			return undef;
# 		}
# 	}
# 	return $newpwd;
# }

# sub db_save_pwd_full {
# 	my $self = shift;
# 	my $dbh = $self->dbh;
# 	my $SID = shift;
# 	my $uid = shift;
# 	my $pwd = shift;
# 	my $fullname = shift;
# 	my $delta = shift;
# 	my $bat = shift;
# 	my $ev = new TPerl::Event(dbh=>$dbh);
# 	my $ADD_RECIPIENT = $ev->number('ADD_RECIPIENT');
# 	$bat = 0 if ($bat eq '');
# 	my $em = shift;
# 	my $tim = time();
# 	my $expires = $tim + $delta;
# 	my $sql = "INSERT INTO $SID (UID,PWD,STAT,FULLNAME,TS,EXPIRES,REMINDERS,BATCHNO,EMAIL) ";
# 	$sql .= ' VALUES (?,?,?,?,?,?,?,?,?)';
# 	my @params = ($uid,$pwd,0,$fullname,$tim,$expires,0,$bat,$em);
# 	if ($dbh->do($sql,{},@params)){
# 		$ev->I(SID=>$SID,who=>$ENV{REMOTE_USER},pwd=>$pwd,msg=>"Added $uid $fullname $em $pwd from batch $bat",code=>18);
# 		return 1;
# 	}else{
# 		$self->err({sql=>$sql,dbh=>$dbh,params=>\@params});
# 		return undef;
# 	}
# }


1;

