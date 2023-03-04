#!/usr/bin/perl
# $Id: 360_delete_core.pl,v 1.10 2007-07-19 23:34:05 triton Exp $
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# Perl library for QT project
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# 360_delete_core.pl - Core function to delete a participant
#
#
#--------------------------------------------------------------------------------------------
# Subroutines
#
sub delete_by_id
	{
	my $survey_id = shift;
	my $id = shift;

	my $result = '';
	
	&db_conn;
	&db_conn2;
	if ($config{email_send_method} ==2 ){
		use TPerl::EScheme;
		use Data::Dumper;
		my $es = new TPerl::EScheme(dbh=>$dbh);
		my $es_sql = "select DISTINCT PWD from $config{index} where UID=?";
		if (my $es_pwds = $dbh->selectcol_arrayref($es_sql,{},$id)){
			$result .= join "\n",map $es->delete_by_pwd(pwd=>$_),@$es_pwds;
			$result .= "\n";
		}else{
			die Dumper {sql=>$es_sql,errstr=>$dbh->errstr};
		}
		die Dumper($_) if $_ = $es->err;
	}
	$sql = "SELECT UID,PWD,SID FROM $config{index} WHERE UID='$id'";
	&db_do($sql);
	my $cnt = 0;
	while (@row = $th->fetchrow_array())
		{
		($theid,$thepwd,$sid) = @row;
		$sql2 = "SELECT SEQ FROM $sid WHERE PWD=? AND UID=? and SEQ>0";
		&db_do2($sql2,$thepwd,$theid);
		while (@row = $th2->fetchrow_array())
			{
			$files{"$qt_root/$sid/web/D$row[0].pl"}++ if (-f "$qt_root/$sid/web/D$row[0].pl");
			$files{"$qt_root/$sid/doc/$row[0].rtf"}++ if (-f "$qt_root/$sid/doc/$row[0].rtf");
			}
		$sql2 = "DELETE FROM $sid WHERE PWD='$thepwd' AND UID='$theid'";
		if ($thepwd ne '')
			{
			$files{"$qt_root/$sid/web/u$thepwd.pl"}++ if (-f "$qt_root/$sid/web/u$thepwd.pl");
			$files{"$qt_root/$config{participant}/web/u$thepwd.pl"}++ if (-f "$qt_root/$config{participant}/web/u$thepwd.pl");
			}
		&db_do2($sql2)unless ($opt_n);
		$cnt++;
		}
	$sql = "SELECT DISTINCT UID,PWD,SID FROM $config{index} WHERE UID='$id'";
	&db_do($sql);
	while (@row = $th->fetchrow_array())
		{
		($theid,$thepwd,$sid) = @row;
		$sql2 = "DELETE FROM $config{index} WHERE PWD='$thepwd' AND UID='$theid'";
		$files{"$qt_root/$sid/web/u$thepwd.pl"}++ if (-f "$qt_root/$sid/web/u$thepwd.pl");
		&db_do2($sql2) unless ($opt_n);
		$cnt++;
		}
	$files{"$qt_root/$config{master}/web/u$thepwd.pl"}++ if (($thepwd ne '') && (-f "$qt_root/$config{master}/web/u$thepwd.pl"));
	$sql2 = "DELETE FROM $survey_id WHERE UID='$id'";
	&db_do2($sql2) unless ($opt_n);
	$cnt++;
	if ($config{status})
		{
		$sql2 = "DELETE FROM $config{status} WHERE UID='$id'";
		&db_do2($sql2) unless ($opt_n);
		$cnt++;
		}
	if (keys(%files))
		{
		$result .= "deleting files: \n".join("\n",sort keys(%files))."\n";
		unlink keys %files unless ($opt_n);
		}
	&db_disc;
	&db_disc2;
	$result;
	}
1;
