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
    AutoInactiveDestroy => 1,
    mysql_enable_utf8 => 1
})|| die $DBI::errstr;

$dbh->do("set names sjis");

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

if($name_post ne ""){
  $sth = $dbh->prepare("SELECT * FROM user WHERE name LIKE ?");
  $sth->bind_param(1, $name); 
  $sth->execute();

  while (my $ary_ref = $sth->fetchrow_arrayref) {
    my ($id, $name) = @$ary_ref;
    print "<h3>", $id, " , ", $name, "</h3>\n";
  }
}


print '<FORM method="POST" action="./index.pl">';
print '<LABEL>���O</LABEL><INPUT type="text" name="name">';
print "<button>����</button>";
print "</FORM>";

print "<hr>";

# ------ADD DB-------

my $name_post_add = $query->param('nameadd');
if($name_post_add ne ""){
  $sth = $dbh->prepare("INSERT INTO user(name) VALUES (?)");
  $sth->bind_param(1, $name_post_add); 
  $sth->execute();
  print "<script>";
  print "window.alert('".$name_post_add." ��o�^���܂���')";
  print "</script>";
  print "<meta http-equiv='refresh' content='0'; URL='./'>";
  print "\n";
}


$sth->finish;
$dbh->disconnect;

print "<h2>DB�ɓo�^</h2>";
print '<FORM method="POST" action="./index.pl">';
print '<LABEL>���O</LABEL><INPUT type="text" name="nameadd">';
print "<button>�o�^</button>";
print "</FORM>";