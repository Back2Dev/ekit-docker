#!/usr/bin/perl
# $Id: editini.pl,v 1.8 2004-09-08 05:24:08 triton Exp $
# Copyright Triton Technology 2004
# Edit email messages in web page. File editemail.htm is needed to partner with this file
#

use strict;

use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::TSV;
use TPerl::LookFeel;
use Template;
use TPerl::TritonConfig;
use TPerl::MyDB;
use TPerl::Error;
use Config::IniFiles;


my $troot = getConfig ('TritonRoot');
my $uid = $ENV{REMOTE_USER};
my $q = new TPerl::CGI;
my %args = $q->args;
my $SID = $q->param('SID');
our %data;

my ($crap,$pwd,$rest) = split (/\//,$ENV{PATH_INFO},3);
print $q->header;
my @errors = '';

#
# HTML definitions
#
my $vhost = $ENV{HTTP_HOST};
if ($vhost eq '')
	{
	$vhost = $ENV{SERVER_NAME};
	$vhost .= ":$ENV{SERVER_PORT}" if ($ENV{SERVER_PORT} ne '80');
	}
#
# Now get on with the main business
#

$data{inifile} = $q->param('inifile') || "upload_csv.ini";
if ($q->param('SID') eq '')
	{
	push @errors,'Please enter a SID';
	}
else
	{
	$data{SID} = $q->param('SID');
	my $file = "$troot/$data{SID}/config/$data{inifile}";
	$data{ini_files} = '  Other .ini files: ';
	if (-d "$troot/$data{SID}/config")
		{
		opendir(IDIR,"$troot/$data{SID}/config") || die "Error $! reading directory $troot/$data{SID}/config\n";
		my @flist = grep (/\.ini$/i,readdir(IDIR));
		closedir(IDIR);
		foreach my $f (@flist)
			{
			next if ($f eq $data{inifile});
			$data{ini_files} .= qq{&nbsp;&nbsp;&nbsp;<A HREF="/cgi-adm/editini.pl?SID=$SID&inifile=$f">$f</a> };
			}
		}
	my $read_file = 1;
	if ($q->param('save'))
		{
		my $cleanup = $q->param('cleanup');
		my @sections = grep(/^section_/,$q->param);
#		my $stuff = join("<BR>+",@sections);
		my $inidata = '';
		my $aok = 1;
		foreach my $s (@sections)
			{
			my $sname = $1 if ($s =~ /^section_(.*)/);
			my $values = $q->param($s);
			$inidata .= "[$sname]\n$values\n" unless (($values eq '') && $cleanup);
			my @lines = split(/\n/,$values);
			foreach my $line (@lines)
				{
				$line =~ s/\r//g;
				next if ($line =~ /^[;#\[]/);
				next if ($line eq '');
				next if ($line eq "\n");
				if (!($line =~ /=/))
					{
					push @errors,qq{Syntax error in section [$sname] at line: "$line"};
					$aok = 0;
					}
				}
			}
		if ($aok)
			{
			push @errors,qq{Saving file: $file};
			open (OUT,">$file") || die ("Error $! encountered while saving file: $file\n");
			print OUT "$inidata\n";
			close OUT;
			}
		else
			{
			push @errors,qq{You have errors, the file [$file] has not been saved};
			$read_file = 0;
			}
		}

	if (!$read_file)		# Did we have a problem with the supplied data? If so, give the data back to the user:
		{
		my @sections = grep(/^section_/,$q->param);
		foreach my $s (@sections)
			{
			my $sect = $1 if ($s =~ /^section_(.*)/);
			my $settings = $q->param($s);

			my $shtml = <<SECT_HTML;
<B>[$sect]</B>
<span onclick="toggle(document.all('values_$sect'),document.all('toggle_$sect'));" id="toggle_$sect">(<font color="blue"><U>hide</U></font>)</span>
	<br>
	<span id="values_$sect" style="display:">
	<textarea cols="80" rows="12" name="section_$sect">$settings</TEXTAREA><BR>
</span>
SECT_HTML
					$data{ini_sections} .= $shtml;
			
			}
		}
	else
		{
# Read in .ini file (if it exists)
		if (-f $file)
			{
			push @errors,qq{Read in file: $file};
			my $cfg = Config::IniFiles->new( -file => $file );
			if ($cfg)
				{
				my @sections = $cfg->Sections;
				foreach my $sect (@sections)
					{
					my $settings = '';
					my $rows = 0;
					foreach my $key ($cfg->Parameters($sect))
						{
						my $val = $cfg->val( $sect, $key );
						$settings .= qq{$key=$val\n};
						$rows++;
						}
					$rows += 2;
					$rows = 30 if $rows > 30;
					$rows = 4 if $rows < 4;
					my $shtml = <<SECT_HTML;
<B>[$sect]</B>
<span onclick="toggle(document.all('values_$sect'),document.all('toggle_$sect'));" id="toggle_$sect">(<font color="blue"><U>hide</U></font>)</span>
<br>
<span id="values_$sect" style="display:">
<textarea cols="80" rows="$rows" name="section_$sect">$settings</TEXTAREA><BR>
</span>
SECT_HTML
					$data{ini_sections} .= $shtml;
					}
				}
			else
				{ push @errors,"Error $! encountered while reading .ini file: $file";}
			}
		else
			{
			push @errors,qq{File does not exist: $file};
			}
		}
	}
$data{errormsg} = join("<BR>",@errors);
$data{errormsg} .= "<BR>" if ($data{errormsg} ne '');
my $file = 'editini.htm';
my $tt = new Template;
$tt->process ($file,\%data)
			or $q->mydie($tt->error);
