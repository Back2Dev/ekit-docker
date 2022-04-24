#!/usr/bin/perl

use CGI;
use strict;
use warnings;
use DBI;

print "Content-type: text/html\n\n";
print "<H1>Hello World Perl !!</H1>\n";

# �f�[�^�x�[�X�ڑ�����
my $dsn = "dbi:mysql:database=testdb;host=db;port=3306";
my $user = "root";
my $pass ="root";

# �f�[�^�x�[�X�n���h��
my $dbh = DBI->connect( $dsn, $user, $pass, {
    AutoCommit => 1,
    PrintError => 0,
    RaiseError => 1,
    ShowErrorStatement => 1,
    AutoInactiveDestroy => 1
})|| die $DBI::errstr;

my $sth = $dbh->prepare("SELECT * FROM user");
$sth->execute();
while (my $ary_ref = $sth->fetchrow_arrayref) {
  my ($id, $name) = @$ary_ref;
  print "<h3>", $id, " , ", $name, "</h3>\n";
}

print "<hr>";

my $query = CGI->new;
my $name_post = $query->param('name');

print "�������[�h : ".$name_post;

my $name = "%".$name_post."%";

$sth = $dbh->prepare("SELECT * FROM user WHERE name LIKE ?");
$sth->bind_param(1, $name); 
$sth->execute();

while (my $ary_ref = $sth->fetchrow_arrayref) {
  my ($id, $name) = @$ary_ref;
  print "<h3>", $id, " , ", $name, "</h3>\n";
}

$sth->finish;
$dbh->disconnect;

print '<FORM method="POST" action="./index.pl">';
print '<LABEL>���O</LABEL><INPUT type="text" name="name">';
print "<button>����</button>";
print "</FORM>";