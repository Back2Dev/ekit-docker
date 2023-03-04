use strict;
use TPerl::MyDB;
use TPerl::Error;
use FileHandle;
use File::Path;
use Data::Dumper;

=head1 SYNOPSIS

This goes through the database and looks for all the JOBS and VHOSTS
trying to organise for mail to be able to be sent to any.one@JOB.VHOST
or andrew.creer@REA201.realtor.asp4me.com etc.  To this end it creates two files. 
/etc/aliases.asp has lines like 

 rea202_aspalias: "|/home/vhosts/realtor/scripts/asp_mail_responder.pl -h realtor.asp4me.com"

and /etc/mail/virtusertable.asp which has lines like 

 @rea202.realtor.asp4me.com rea202_aspalias


=cut


my $root = '/etc';
my $db  = 'ib';
my $err = new TPerl::Error;

my $sql = 'select * from job,vhost where job.vid = vhost.vid order by job.sid';
my $dbh = dbh TPerl::MyDB (db=>$db) || $err->F("Could not connect to '$db'");

mkpath ($root.'/mail',1) unless -e $root.'/mail';
my $afile = $root.'/aliases.asp';
my $afh = new FileHandle ("> $afile") or $err->F("Could not open $afile for writing:$!");
my $vfile = $root."/mail/virtusertable.asp";
my $vfh = new FileHandle ("> $vfile") or $err->F("Could open $vfile for writing:$!");

my $sth = $dbh->prepare ($sql) or $err->F("Could not prepare $sql");
$sth->execute() or $err->F("Could not execute $sql");
while (my $row = $sth->fetchrow_hashref){
	# print Dumper $row;
	$row->{VDOMAIN} =~ s/(.*?):\d+$/$1/;
	$row->{SID} = lc $row->{SID};
	my $alias = "$row->{SID}_aspalias";
	print $afh qq{$alias: "|$row->{SCRIPTS}/asp_mail_responder.pl -h $row->{VDOMAIN}"\n};
	print $vfh qq{\@$row->{SID}.$row->{VDOMAIN} $alias\n};
}
$err->I("$0 wrote $afile");
$err->I("$0 wrote $vfile");
