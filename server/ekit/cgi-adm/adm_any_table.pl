#!/usr/bin/perl
#$Id: adm_any_table.pl,v 1.2 2007-09-10 10:03:49 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::MyDB;
use TPerl::DBEasy;
use TPerl::CGI;


# A quick script for Mike to edit any table in the database.  
# uses the sulist so that only mikkel and ac can use it.

# standard CGI stuff.
my $q = new TPerl::CGI;
my $sulist = [qw(ac mikkel)];
my %args = $q->args();


# A package inherits from the TPerl::TableManip 
# the DBEasy->edit function below allows editing of 
# any table listed by the table_create_list() function.
# This is where you'd limit it to one or two tables.

{
	package MyPackage;
	use strict;
	use vars qw(@ISA);
	use TPerl::TableManip;
	@ISA=qw(TPerl::TableManip);
	
	sub table_create_list {
		my $self = shift;
		my $dbh = $self->dbh;

		#return['TUSER'];
		return [$dbh->tables];
	}
}

my $obj = new MyPackage;
my $ez = new TPerl::DBEasy (dbh=>$obj->dbh);
my $state=[qw(edit table delete new)];
my $tables = $obj->table_create_list;

## Set the default table to the first in the list (or smarter)
$args{table} ||=$tables->[0];

## You still need to tell the primary key if you want 
# edit or delete columns.

my $tablekeys = {
	TUSER=>['UID'],
};

my $res = $ez->edit(_obj=>$obj,_new_buttons=>$tables,
	_tablekeys=>$tablekeys,
	_state=>$state,%args);

if ($res->{err}){
    $q->mydie ($res->{err});
}else{
    print join "\n",
        $q->header,
        $q->start_html(-title=>$0,-style=>{src=>"/admin/style.css"},-class=>'body'),
        $res->{html},
        join (' | ',map qq{<a href="$ENV{SCRIPT_NAME}?table=$_">$_</a>},@$tables),
        $q->end_html;
}


