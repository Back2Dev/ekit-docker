#!/usr/bin/perl
#$Id: aspsendbatches.pl,v 1.16 2005-05-04 07:01:28 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::MyDB;
use TPerl::LookFeel;
use File::Basename;
use TPerl::TritonConfig;
use TPerl::DBEasy;
use TPerl::ConfigIniFiles;


=head 1 SYNOPSIS

Batches of files that are on the server, but not in the
email_work database table are in 'limbo'.  Well see 
finds those, and presents a form.  

=cut

my $lf = new TPerl::LookFeel;
my $q = new TPerl::CGI;

my %args = $q->args;
my $SID= $args{SID};
$q->mydie("No SID sent") unless $SID;
my $uid = $ENV{REMOTE_USER};
my $troot = getConfig('TritonRoot');
my @checkboxes = ();

# database connections and ASP objects
my $db = getdbConfig ('EngineDB') or die "Could not get 'EngineDB' from 'getdbConfig'";
my $dbh = dbh TPerl::MyDB (db=>$db) or die $TPerl::MyDB::err;
my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);
my $ez = new TPerl::DBEasy(dbh=>$dbh);

## use the edit_security to see if they have W access to this job.
unless (getConfig('no_security')){
	my $esec = $sec->edit_security ($uid,$SID);
	if ($esec->{err}){
		$q->mydie($esec->{err});
	}
}

my $e = new TPerl::Error (noSTDOUT=>1);
my $ini_fn = join '/',$troot,$SID,'config','upload_csv.ini';
my $ini = new TPerl::ConfigIniFiles();
my $ini_sec = fileparse ($ENV{SCRIPT_NAME}||$0,qr{\..*$});
$ini->sanity_logging (err=>$e,ini_sec=>$ini_sec,ini_fn=>$ini_fn);


my $us_date = 1;
my $fmt = '%m/%d/%Y' if $us_date;


### handle the sending and deleting
my $bids = [];
foreach my $arg (keys %args){
	if (my ($num) = $arg =~ /^batch(\d+)$/){
		push @$bids,$num;
	}
}
if (@$bids && $args{delete}){
	## Now we use aspbatchreverse, cause it does so much more..
	my $url = "aspbatchreverse.pl?SID=$SID&";
	$url .= join ('&',map("BID=$_",@$bids));
	print $q->redirect($url);
}
if (@$bids && $args{send}){
	# just set these to FILTERED for now.  later we'll possibly set it to CONFIRMED....
 	my $status = 2;
 	my $params = [time(),$status,$status,$SID];
 	push @$params,$_ foreach @$bids;
 	my $where = join ' OR ',map ' BID=? ',@$bids;
 	my $sql = "update BATCH set MODIFIED_EPOCH=? , STATUS=? where STATUS < ? and SID=? and ($where)";
 	$q->mydie({sql=>$sql,dbh=>$dbh,params=>$params}) unless $dbh->do($sql,{},@$params);
}

## rescan after all the deleting and sending

my $limbo = $asp->limbo_batches(SID=>$SID,who=>$ENV{REMOTE_USER});
# $q->mydie($limbo);
my $stuff = join "\n",
	$ini->val($ini_sec,'nolimbo_before'),
	$q->msg('There are now no unconfirmed batches for '.$ENV{REMOTE_USER}),
	$ini->val($ini_sec,'nolimbo_after');
if (@$limbo){
	my $b_fields = $asp->batch_fields();
	$b_fields->{BID}->{cgi}->{func} = 'textfield';
	$b_fields->{NAMES_FILE}->{cgi}->{func} = 'hidden';
	delete $b_fields->{$_} foreach qw (CLEAN_EPOCH DELETE_EPOCH);
	my $code_ref = sub { 
		my $bid = shift;
		my $q = new CGI('');
		push @checkboxes,"batch$bid";
		return 'Select '.$q->checkbox_group(-name=>"batch$bid",-values=>[1],
			-labels=>{1=>''});
	};

	my $states = [qw (SID)];
	$b_fields->{radio} = {pretty=>'Select',code=>{ref=>$code_ref,names=>['BID']}};
	my $b4 =  $ini->val($ini_sec,'list_before') ||
		'<p class="prompt">Below is a list of your uploaded batch(es)</p>';
	my $b4html = join "\n",
		$q->start_form(-action=>$ENV{SCRIPT_NAME},-method=>'POST',-name=>'q',-onSubmit=>"return checksels();"),
		#### ,-onsubmit=>"return QValid();"`
		$b4,
		map ($q->hidden(-name=>$_,-value=>$args{$_}),(@$states,'page'));
	my $af = $ini->val($ini_sec,'list_after') || 
		'If you wish to delete the batch(es), select the ones to delete and
		click the DELETE button. If you wish to proceed with sending emails,
		select the batch(es) and click the CONFIRM button';
	my $afhtml = join "\n",
		qq{<p class="prompt">$af</p>},
		#$q->textfield(-name=>'invite_date',-value=>$invite_date,),
		# qq{<a href="javascript:show_calendar('q.invite_date',null,null,'MM/DD/YYYY');"><img src="/pix/show-calendar.gif"></a>},
		'<BR>',
		$q->submit(-name=>'delete',-value=>'Delete'),
		$q->submit(-name=>'send',-value=>'Confirm'),
		$q->end_form;

	$stuff = $ez->lister_wrap(rows=>$limbo,look=>$lf,fields=>$b_fields,
		_afhtml=>$afhtml,_b4html=>$b4html,
		_row_count=>'  ',
		limit=>20,form=>1,_state=>$states,%args) or $q->mydie ($ez->err());
		
}

	my $jscript = <<JS;
function checksels()
	{
	var nsel = 0;
JS
	foreach my $box (@checkboxes)
		{
		$jscript .= "\tif (document.q.$box.checked) nsel++;\n";
		}
	$jscript .= <<JS;
	if (nsel == 0)
		alert("Please select at least one batch to be deleted or confirmed");
	return (nsel > 0);
	}
JS

print join "\n",
	$q->header,
	$q->start_html(-style=>{src=>"/$SID/style.css"},-title=>'Unconfirmed Batches',-class=>'body',-script=>$jscript),
	$stuff,
	# $q->dumper(\%args),
	$q->end_html;

