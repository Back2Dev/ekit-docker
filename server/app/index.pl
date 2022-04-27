#!/usr/bin/perl

use CGI;
use strict;
use warnings;
use DBI;

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


my $query = CGI->new;
# ���O����

my $name = $query->param('name');


# ���O�ǉ�

my $name_post_add = $query->param('nameadd');
if($name_post_add ne ""){
  my $sth = $dbh->prepare("INSERT INTO user(name) VALUES (?)");
  $sth->bind_param(1, $name_post_add); 
  $sth->execute();
  print "Location: ./\n\n";
}

#
# ---- PRINT -------
#

print "Content-Type: text/html; charset=Shift_JIS\n\n";
print "<html lang='ja'>";
print "<head><title>�f����</title><link rel='stylesheet' href='style/main.css'></head>";
print "<body>";

print "<div class='blocktext'>";

print "<h3>�f����</h3>";

print "<h4>�����o�[�ꗗ</h4>";
print "���� : ".$name;

if($name ne ""){
    $name = "%".$name."%";
    my $sth = $dbh->prepare("SELECT * FROM user WHERE name LIKE ?");
    $sth->bind_param(1, $name); 
    $sth->execute();

    while (my $ary_ref = $sth->fetchrow_arrayref) {
        my ($id, $name) = @$ary_ref;
        print "<h3>", $id, " , ", $name, "</h3>\n";
    }
}else{
    my $sth = $dbh->prepare("SELECT * FROM user WHERE name LIKE ?");
    $sth->bind_param(1, $name); 
    $sth->execute();

    while (my $ary_ref = $sth->fetchrow_arrayref) {
        my ($id, $name) = @$ary_ref;
        print "<h3>", $id, " , ", $name, "</h3>\n";
    }
}

print "<hr>";

print "<h5>���O������</h5>";
print '<FORM method="POST" action="./">';
print '<LABEL>���O</LABEL><INPUT type="text" name="name">';
print "<button>����</button>";
print "</FORM>";

print "<hr>";

print "<h5>���O��o�^</h5>";
print '<FORM method="POST" action="./">';
print '<LABEL>���O</LABEL><INPUT type="text" name="nameadd">';
print "<button>�o�^</button>";
print "</FORM>";

print "</div>";

print "</body>";
print "</html>";

