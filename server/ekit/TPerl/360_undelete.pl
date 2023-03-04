#!/usr/bin/perl
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
# $Id: 360_undelete.pl,v 2.1 2007/01/28 07:51:47 triton Exp $
#
$copyright = "Copyright 1996 Triton Technology, all rights reserved";
#
# Author:	Mike King
#
#---TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS------TSS---
#
# This is a slave - should be called by a higher level wrapper
#
# NB Does not require things - assume that is already done !
#
use CGI::Carp qw(fatalsToBrowser);
#
# Settings
#
#$dbt = 1;
$do_body = 1;
$plain = 1;
$form = 1;
$rolename = 'admin';
#--------------------------------------------------------------------------------------------
# Subroutines
#
#--------------------------------------------------------------------------------------------
# Start of main code 
#
#&ReadParse(*input);
our $q = new TPerl::CGI;
our %input = $q->args;
#
print "Content-Type: text/html\n\n";
print "<HTML>\n";
&db_conn;
#
$survey_id = $config{master};			# This is a hack to use PWIKIT as the central authentication spot
$resp{'survey_id'} = $survey_id;
#
&add2hdr(<<HDR);
	<TITLE>$config{title} listing page </TITLE>
	   <META NAME="Horizon Research Corporation">
	   <META NAME="Author" CONTENT="Mike King (213) 627 7100">
	   <META NAME="Copyright" CONTENT="Triton Technology 1995-2003">
	<link rel="stylesheet" href="/$config{case}/style.css">
HDR
my $selections .= qq{<OPTION VALUE="">All\n};
foreach my $role (keys %{$config{roles}})
	{
	my $checked = ($input{fsid} eq $config{roles}{$role}{code}) ? "SELECTED" : '';
	$selections .= qq{<OPTION VALUE="$config{roles}{$role}{code}" $checked>$config{roles}{$role}{name}\n};
	}
my $search = <<SEARCH;
	<FORM ACTION="$ENV{SCRIPT_NAME}" method="POST" ENCTYPE="x-www-form-encoded">
	<TABLE BORDER="0" cellpadding="6" CELLSPACING="0" class="mytable">
	<TR class="heading"><TD colspan="2"> Please enter details for restore, or leave blank to list all
	<TR class="options">
		<TD>ID:<TD><INPUT type="TEXT" name="fid" value="$input{fid}">
	<TR class="options">
		<TD>Name:<TD><INPUT type="TEXT" name="fname" value="$input{fname}">
	<TR class="options">
		<TD NOWRAP>Age no more than (days):<TD><INPUT type="TEXT" name="age" value="$input{age}">
	<TR class="options">
		<TD>ROLE ID:<TD><SELECT name="fsid">$selections</SELECT>
	<TR class="options">
		<TD colspan=2>
	<INPUT TYPE="SUBMIT" Value="Search" name="search">
	</table><BR>
SEARCH

&add2body($search);
foreach my $in (grep /restore_/,keys %input)
	{
	&add2body(qq{$in=$input{$in}<BR>\n});
	my ($sid,$uf,$seqno,$batchno,$fullname) = split(/\//,$input{$in});
	if ($sid eq '')
		{
		&add2body("No SID found in $input{$in}<BR>\n");
		}
	else
		{
		my $webdir = qq{${qt_root}/${sid}/web};
		my $ufile = qq{$webdir/u${uf}.pl};
		my_require($ufile,1);
		my $status = (-f "$qt_root/$sid/doc/$seqno.rtf") ? 4 : 3;
		&db_set_status($sid,$ufields{id},$uf,$status,$seqno);
		my $n = 0;
		$n = $1-1 if ($sid =~ /\D+(\d+)$/);
		my @roles = ('Self','Peer','Boss','Reviewer','Reviewer');
		my $thisrole = $roles[$n];
		%maproles = (
MAP001  => 'Self',
MAP002  => 'Self',
MAP003  => 'Self',
MAP004  => 'Self',
MAP005  => 'Self',
MAP006  => 'Self',
MAP007  => 'Self',
MAP010A	=> 'Self',	
MAP010  => 'Peer',
MAP011  => 'Boss',
MAP012  => 'Boss',
);
		$thisrole = $maproles{$sid} if ($maproles{$sid} ne '');
		&db_add_invite($config{index},$config{case},$sid,$ufields{id},$uf,$fullname,$thisrole,$batchno,0);
		}
	}
if ($input{search} ne '')
	{
&add2body(<<HEADER);
<FORM ACTION="$ENV{SCRIPT_NAME}" method="POST" ENCTYPE="x-www-form-encoded">
<TABLE BORDER="0" cellpadding="6" CELLSPACING="0" class="mytable">
	<TR>
		<TH class="heading">Form</TH>
		<TH class="heading">ID</TH>
		<TH class="heading">Reviewer</TH>
		<TH class="heading">Password</TH>
		<TH class="heading">Data</TH>
		<TH class="heading">DB</TH>
		<TH class="heading">Doc</TH>
		<TH class="heading">Action</TH>
		
	</TR>
HEADER
my $rowcnt = 0;
my $role = 'x';
my %df_cache = ();
my %found = ();
my $stack = '';
foreach my $SID (sort keys %{$config{snames}})
	{
	my $webdir = qq{${qt_root}/${SID}/web};
	my $newrole = $SID;
	$newrole =~ s/\d+$//;
	if ($input{fsid})
		{
		next if (!($SID =~ /$input{fsid}/i));
		}
	if ($newrole ne $role)
		{
		$stack = qq{<TR class="heading"><TD colspan=8>$newrole};
		$role = $newrole;
		}
#
# Let's cache a list of D-files first, to see where we have data
#
	opendir (WEB,$webdir) || die "Error $! encountered while reading directory: $webdir\n";
	my @dfiles = grep(/^D\d+\.pl$/,readdir(WEB));
	closedir(WEB);
	foreach my $dfile (@dfiles)
		{
		undef %resp;
    	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)
	           = stat("$webdir/$dfile");
	    next if (($mtime < (time - ($input{age} * 60*60*24))) && ($input{age} ne ''));
		my_require("$webdir/$dfile",1);
		$df_cache{"$SID$resp{token}"} = $dfile;
		}
#
# Now look at the ufiles, because they are the master set
#
	opendir (WEB,$webdir) || die "Error $! encountered while reading directory: $webdir\n";
	my @ufiles = grep(/^u\D+\.pl$/,readdir(WEB));
	closedir(WEB);
	foreach my $ufile (@ufiles)
		{
		undef %ufields;
		undef %resp;
    	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)
	           = stat("$webdir/$ufile");
	    next if (($mtime < (time - ($input{age} * 60*60*24))) && ($input{age} ne ''));
		my_require("$webdir/$ufile",1);
		if ($input{fid})
			{
			next if (!($ufields{id} =~ /$input{fid}/i));
			}
		if ($input{fname})
			{
			next if (!($ufields{aboutname} =~ /$input{fname}/i)) && (!($ufields{who} =~ /$input{fname}/i));
			}
		my $options = ($rowcnt % 2) ? "options" : "options2";
		my $data = "-";
		if ($df_cache{"$SID$ufields{password}"} ne '') 
			{
			$found{"$SID$ufields{password}"}++;
			my $dfile = $df_cache{"$SID$ufields{password}"};
			my_require("$webdir/$dfile",1);
			$data = &perc_done($SID);
			}
		my $db = "N";
		db_new_survey($SID);
		my $sql = "SELECT UID,PWD,FULLNAME,STAT,SEQ from $SID WHERE pwd=?";
		&db_do($sql,$ufields{password});
		while (my $hr = $th->fetchrow_hashref())
			{
			$db = $$hr{STAT};
			}
		my $action = '&nbsp;';
		my $who = ($resp{who} eq '') ? $ufields{who} : $resp{who};
		if ($db eq "N")
			{
			$action = qq{<INPUT type="CHECKBOX" name="restore_$rowcnt" value="$SID/$ufields{password}/$resp{seqno}/$ufields{batchno}/$who"> Restore};
			}
		if ($stack ne '')
			{
			&add2body($stack);
			$stack = '';
			}
		my $doc = (-f "$qt_root/$SID/doc/$resp{seqno}.rtf") ? "Y" : '';
		&add2body(qq{<TR class="$options"><TD>$SID<TD>$ufields{id} $ufields{aboutname}<TD>$who<TD>$ufields{password}<TD>$data<TD>$db<TD>$doc<TD>$action});
		$rowcnt++;
		}
	}

&add2body(<<EOFORM);
  </TABLE>
<HR class="options">
<INPUT TYPE="SUBMIT" Value="Restore selections" name="restore">
</FORM>
EOFORM
foreach my $df (keys %df_cache)
	{
	next if ($found{$df});
	&add2body("Not found: $df<BR>\n");
	}
}

&db_disc;
#
# OK, we're done now, so output the standard footer :-
#
&qt_Footer;

sub perc_done
	{
	my $SID = shift;
	my $qlfile = "$qt_root/$SID/config/qlabels.pl";
	&my_require ("$qlfile",1);
	my $done = 1;
	my $n = 0;
	my $perc = 2;
	for(my $i=1;$i<=$numq;$i++)
		{
		my @bits = split(/\s+/,$qlabels{$i});
	#	print "$i: $bits[1]? \n";
		if ($config{case} eq 'ppr')
			{
			if ($bits[1] =~ /^([AB]\d+)$/)
				{
				$done++ if ($resp{"_Q$1"} ne '');
		#		print "  ".$resp{"_Q$1"}."\n";
				$n++;
				}
			elsif ($survey_id =~ /5$/)		# Is it the action list ?
				{
				if ($bits[1] =~ /^(\d+)$/)
					{
					$done++ if ($resp{"_Q$1"} ne '');
					$n++;
					}
				}
			}
		else
			{
			my $key = $bits[1];
			$key =~ s/^q//;
			$done++ if ($resp{"_Q$key"} ne '');
			$n++;
			$n = 7;
			}
		}
	$perc = int(100*$done/$n) if ($n > 0);
	$perc = 100 if $perc > 100;
	"$perc%";	
	}
1;
