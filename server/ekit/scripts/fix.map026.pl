#!/usr/bin/perl
# $Id: fix.map026.pl,v 1.3 2013-03-14 00:30:04 triton Exp $
# Kwik script to scan MAP026 d-files, and read workshop_leader stuff from MAP001 
# if it's not already there
#
use strict;
use File::Slurp;
use TPerl::TritonConfig;
use TPerl::Engine;
use Data::Dumper;

my $e = new TPerl::Engine;

my $data_dir = "../triton/MAP026/web";
opendir DDIR,$data_dir || die "Error $! encountered while opening directory $data_dir\n";
my @files = grep (/^D/,readdir(DDIR));
closedir(DDIR);
opendir DDIR,$data_dir || die "Error $! encountered while opening directory $data_dir\n";
push @files,grep (/^u/,readdir(DDIR));
closedir(DDIR);
my $buf = read_file("ID-WSLEADERS-BACK-6-YEARS.csv");
my @lines = split(/\n/,$buf);
my %idlkup;
foreach my $l (@lines) {
	my @bits = split(/	/,$l);
	next if ($bits[0] =~ /ID/i);
	$bits[1] = qq{$2 $1} if ($bits[1] =~ /^(\w+):(.*)/ig);	# Reverse the name
	$idlkup{$bits[0]}{initials} = $bits[2];
	$idlkup{$bits[0]}{name} = $bits[1];
}
#print Dumper \%idlkup;

my ($n,$warn);
foreach my $f (@files) {
	print "Reading file $f\n";
	my $d;
	if ($f =~ /^u/) {
		$d = $e->u_read(qq{$data_dir/$f});
	} else {
		$d = $e->qt_read(qq{$data_dir/$f});
	}
#	print Dumper $d;
	next if (($$d{workshop_leader_name} ne '') && ($$d{workshop_leader_initials} ne ''));
	if (!$$d{password}) {
		$$d{password} = $1 if ($f =~ /^u([A-Z]+)\.pl$/);
	}
	if (!$$d{password}) {
		warn "Missing password in $f\n";
		$warn++;
	} else {
#		print "Reading u-file u$$d{password}.pl\n";
		my $u = $e->u_read(qq{../triton/MAP001/web/u$$d{password}.pl});
#		print Dumper $u;
		$$d{workshop_leader_name} = $$u{workshop_leader_name};
		$$d{workshop_leader_initials} = $$u{workshop_leader_initials};
		$$d{workshop_leader_name} = $idlkup{$$u{id}}{name} if (!$$d{workshop_leader_name});
		$$d{workshop_leader_initials} = $idlkup{$$u{id}}{initials} if (!$$d{workshop_leader_initials});
		if ($f =~ /^u/) {
			foreach my $key (keys %{$u}){		# Recover u-file data
				$$d{$key} = $$u{$key};
			}
			$e->u_save(qq{$data_dir/$f},$d);
		} else {
			$e->qt_save(qq{$data_dir/$f},$d);
		}
		print "  updated $f\n";
		$n++;
	}
}
print "Done.\n Updated $n files, $warn warnings\n";

