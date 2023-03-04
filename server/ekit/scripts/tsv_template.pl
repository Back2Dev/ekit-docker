#!/usr/bin/perl
#$Id: tsv_template.pl,v 2.3 2005-05-10 01:02:27 triton Exp $
use strict;
use TPerl::Error;
use TPerl::TSV;
use Template;
use TPerl::Template;
use Data::Dumper;

my $template = shift;
my $file = shift;

usage ("Nothing on command line") unless $template && $file;

sub usage {
	my $msg = shift;
	print qq{$msg
 Usage $0 template file
};
	exit;
}

my $e = new TPerl::Error;

$e->F("file '$file' does not exist") unless -e $file;
# my $tt = new Template;
my $tt = new TPerl::Template(template=>$template);

my $tsv = new TPerl::TSV(file=>$file);
my $hh = $tsv->header_hash();
$e->F("No variables in template '$template'") unless keys %{$tt->vars};
$e->F("Data does not match template '$template':".$tt->err) unless $tt->check_subs($hh);

while (my $row = $tsv->row){
	# my $out = undef;
	# $tt->process (\$template,$row,\$out) or $e->E("Could not proccess ".$tt->error);
	# print "$out\n";
	
	# Lets use the new Temlpate..
	my $out = $tt->process($row);
	$e->E("Could not process:$_") if $_=$tt->err;
	print "$out\n";
}

