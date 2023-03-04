#!/usr/bin/perl
#$Id: aspbatchlist.pl,v 1.8 2004-09-08 23:18:09 triton Exp $
#
# This is similar to aspbatches, but it purely database driven.
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::LookFeel;
use TPerl::DBEasy;
use TPerl::ASP;

my $q = new TPerl::CGI;
my %args = $q->args;
my $lf = new TPerl::LookFeel;

my $SID = $args{SID} || $args{survey_id};
$q->mydie("no SID sent") unless $SID;

my $dbh = dbh TPerl::MyDB() or $q->mydie("Cannot connect to database:".TPerl::MyDB->err);

my $asp = new TPerl::ASP(dbh=>$dbh);

my $fields = $asp->batch_fields;
my $tablekeys = {BATCH=>['BID']};
my $ez = new TPerl::DBEasy(dbh=>$dbh);

###No we need to fix up the args hash to make sure we allow limeted things to happen.
$args{table} = 'BATCH';  ## We only edit one table...
delete $args{$_} foreach qw(new delete edit);

delete $fields->{$_} foreach qw(NAMES_FILE CLEAN_EPOCH); ## Office use only...

my $update_messages = undef;
if ($args{_NEW_BID}){
	my $row = {};
	my $update_fields = {};
	foreach my $a (keys %args){
		if (my ($f) = $a =~/^_NEW_(.*)$/){
			$row->{$f} = $args{$a};
			$update_fields->{$f} = $fields->{$f};
		}
	}
	# print $q->dumper($row);
	my $db_err = $ez->row_manip(fields=>$update_fields,table=>'BATCH',
		action=>'update',vals=>$row,keys=>['BID']);
	if ($db_err){
		$update_messages.= $q->err($db_err);
	}else{
		$update_messages.= "Changes made sucessfully for BATCH '$args{_NEW_BID}'<BR>";
	}
}

my $code_ref = sub {
	my $title = shift;
	my $bid = shift;
	my $del = shift;
	my $q = new CGI('');
	return undef unless $bid;
	return undef unless $del eq '';
	return join "\n",
		# $q->image_button(-name=>'edit',-src=>'http://www.triton-tech.com/pix/edit.gif',-alt=>'Edit Batch Name',-onclick=>"getNewTitle($bid)"),
		$q->start_form(-action=>$ENV{SCRIPT_NAME},-method=>'POST',-name=>"form$bid",-onSubmit=>"return getNewTitle($bid)"),
		$q->hidden(-name=>'_NEW_BID',-value=>$bid),
		$q->hidden(-name=>'SID',-value=>$SID),
		$q->hidden(-name=>'_NEW_TITLE',-value=>$title),
		# $q->textfield(-class=>'input',-name=>'_NEW_TITLE',-value=>$title,-size=>50,-maxlength=>100),
		$q->submit(-class=>'input',-name=>'submit',-value=>'Edit'),
		$q->end_form;
};
$fields->{edit}->{code}={ref=>$code_ref,names=>[qw(TITLE BID DELETE_EPOCH)]};

my $bl = $asp->batch_list(SID=>$SID);
$q->mydie($asp->err) unless $bl;

if (!$args{edit} and !$args{new} and !$args{delete}){
	$fields->{BID}->{cgi}->{func} = 'textfield' ;
	$fields->{BID}->{order} = -1;
}
my $res =  $ez->edit(_obj=>$asp,_new_buttons=>[],
	_tablekeys=>$tablekeys,_fields=>$fields,
	_list_rows=>[sort {$b->{UPLOAD_EPOCH} <=> $a->{UPLOAD_EPOCH}} values %$bl],
	_state=>['SID'],
	_list_del=>0,_list_edit=>0,
	%args);


if ($res->{err}){
	$q->mydie($res->{err});
}else{
	my $jscript = qq{
			function getNewTitle (bid) {
				var formName = "form"+bid;
				var myform = document.all.item(formName);
				var oldText = myform._NEW_TITLE.value
				//alert (oldText);
				var r = prompt ("Please enter a new batch title",oldText);
				if (r == undefined) return false;
				if (r == oldText) return false;
				// alert (r);
				myform._NEW_TITLE.value=r;
				return true;
			}
		};
	print join "\n",
		$q->header,
		$q->start_html(-title=>"Batch List",-style=>{src=>"/$SID/style.css"},-script=>$jscript, -class=>"body"),
		$update_messages,
		$res->{html},
		# $q->dumper($bl),
		# $q->dumper(\%args),
		# $q->dumper($fields),
		$q->end_html;
}

