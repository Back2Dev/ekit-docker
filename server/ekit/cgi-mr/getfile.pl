#!/usr/bin/perl
#
use strict;
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use POSIX qw(strftime);

# MySQL settings:
our $mysql_db_file = 'vhost_ekit';
our $mysql_db_user = 'triton';
our $mysql_db_password = 'Rsptcmg5!';
#
# Little hack to get extra cubes in
#
my $ball = <<BALL;
Ballantine_lbsSUM=Ballantine Lbs
Ballantine_salesSUM=Ballantine Sales
Ballantine_slbsSUM=Ballantine Sales/Lbs
Ballantine_lsrpSUM=Ballantine Sales/Lbs/Price
BALL
my $giu = <<GIU;
Giumarra_lbsSUM=Giumarra Lbs
Giumarra_salesSUM=Giumarra Sales
Giumarra_slbsSUM=Giumarra Sales/Lbs
Giumarra_lsrpSUM=Giumarra Sales/Lbs/Price
GIU

my $rip = <<RIP;
RipeNReady_lbsSUM=Ripe & Ready Lbs
RipeNReady_salesSUM=Ripe & Ready Sales
RipeNReady_slbsSUM=Ripe & Ready Sales/Lbs
RipeNReady_lsrpSUM=Ripe & Ready Sales/Lbs/Price
RIP

my %extra_cubes = (
# Ballatine:
		MichaelCelani => $ball,
		GinoDiBuduo => $ball,
		GregMancini => $ball,
		SabrinaMak => $ball,
		JPHarmon => $ball,
# Giumarra:
# For some reason they changed their mind on this one.		
#		PattyBoman => $giu,
# Ripe 'n Ready:
# Currently have no clue
#		SteveKenfield => $rip,
	);
#
# Start of main code
#
my $q = new CGI;
my $file = ($ENV{PATH_INFO} eq '') ? "index.html" : qq{$ENV{DOCUMENT_ROOT}$ENV{PATH_INFO}};
if ($file =~ /\.htm/i)
	{
	print "Content-type: text/html\n\n";
	}
else
	{
	print "Content-type: text/plain\n\n";
	}
my $whoru = $ENV{REMOTE_USER} || $q->param('user');
my $dbh = DBI->connect("dbi:mysql:database=$mysql_db_file","$mysql_db_user","$mysql_db_password",{ PrintError => 0, RaiseError => 0}) || print ";[W] Cannot connect to MySQL database ($mysql_db_file) : $DBI::err $DBI::errstr\n";
my $href;
if ($dbh)
	{
	my $sql = "SELECT * FROM USERS WHERE USERID=?";
	my $th = $dbh->prepare($sql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
	$th->execute($whoru) || print ";[W] Cannot execute SQL statement: $DBI::errstr\n";
	if ($th)
		{
		$href = $th->fetchrow_hashref();
		$th->finish();
		$dbh->disconnect || warn "Error disconnecting from database: $DBI::errstr\n";
		undef $dbh;
		
		$$href{EXTRAS} = $extra_cubes{$whoru};
		
		#print "FILE FOLLOWS: $file\n";
		foreach my $key (keys %$href)
			{
			$file =~ s/$key/$$href{$key}/;
			}
		}
	}
open (F,"<$file") || die "Error $! encountered while opening file $file\n";
while (<F>)
    {
    while (/\[%(\w+)%\]/)
        {
        my $token = $1;
        my $newthing = $ENV{$token};
        $newthing = $$href{uc($token)} if ($$href{uc($token)} ne '');
        s/\[%$token%\]/$newthing/ig;
        }
    print $_;
    }
1;
