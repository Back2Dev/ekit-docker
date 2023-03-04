#!/usr/bin/perl
#$Id: aspbatchreverse.pl,v 1.14 2005-05-26 10:31:19 triton Exp $
use strict;
use CGI::Carp qw (fatalsToBrowser);
use TPerl::CGI;
use TPerl::MyDB;
use TPerl::ASP;
use TPerl::TritonConfig;
use TPerl::Error;
use TPerl::ConfigIniFiles;
use File::Basename;

my $troot = getConfig('TritonRoot');
my $q = new TPerl::CGI;
my %args = $q->args;
my $lf = new TPerl::LookFeel;
my $e = new TPerl::Error (noSTDOUT=>1);

my $SID = $args{SID} || $args{survey_id};
$q->mydie("no SID sent") unless $SID;

my $dbh = dbh TPerl::MyDB () or $q->mydie ("could not connect to database :".DBI->errstr);

my $confirm = $args{confirm};
my $stuff = undef;

my $bids = $args{BID} || [];
$bids = [$bids] if $bids and ref $bids ne 'ARRAY';
my $title = "Reverse Batch @$bids";

# $q->mydie ({bids=>$bids});

### We are adding in some stuff from an ini file to explain shit.
# Sould always be able to use it to call $ini->val even if there is something wrong with the file, or its not there.
my $ini_fn = join '/',$troot,$SID,'config','upload_csv.ini';
my $ini = new TPerl::ConfigIniFiles();
my $ini_sec = fileparse ($ENV{SCRIPT_NAME}||$0,qr{\..*$});
$ini->sanity_logging (err=>$e,ini_sec=>$ini_sec,ini_fn=>$ini_fn);


if (@$bids){
	if ($confirm==2){
		my $sqls = [];
		my $msgs = [];
		my $errs = [];
		foreach my $bid (@$bids){
			# Delete the ufiles too.
			my $sql = "select pwd from $SID where batchno=?";
			my $db_list = $dbh->selectall_arrayref($sql,{},$bid) or $q->mydie({sql=>$sql,dbh=>$dbh,params=>[$bid]});
			my $ufile_list = [map (join('/',$troot,$SID,'web',"u$_->[0].pl"),@$db_list)];
			@$ufile_list = grep -e $_,@$ufile_list;
			# $q->mydie ({bid=>$bid,db_list=>$db_list,ufile_list=>$ufile_list,troot=>$troot,SID=>$SID});

			if (@$ufile_list){
				my $deleted = unlink (@$ufile_list);
				push @$msgs,"$deleted ufile(s) deleted" if $deleted;
			}
			push @$sqls,
				{sql=>"delete from $SID where batchno=?",msg=>"Deleted survey records in batch $bid from $SID",ps=>[$bid]},
				{sql=>'Update BATCH set delete_epoch=?,modified_epoch=?,status=? where SID=? AND  BID=?',msg=>"Marked the batch $bid as deleted",ps=>[time(),time(),12,$SID,$bid]},
				{sql=>'Update EMAIL_WORK set end_epoch=? where SID=? AND BID=? and END_EPOCH is null',msg=>"End dated EMAIL_WORK entries for batch $bid",ps=>[time(),$SID,$bid]},
				{sql=>'Update EMAIL_WORK set please_stop=?,error=? where SID=? AND  BID=?',msg=>"EMAIL_WORK queue for batch $bid => PLEASE STOP !!",ps=>[1,"Deleted by $ENV{REMOTE_USER}",$SID,$bid]};
		}
		# $q->mydie ({sqls=>$sqls,bids=>$bids});
		foreach my $h (@$sqls) {
			if ($dbh->do($h->{sql},{},@{$h->{ps}})) {
				push @$msgs,$h->{msg};
			}else{
				push @$errs ,{sql=>$h->{sql},params=>$h->{ps},dbh=>$dbh,msg=>"Failed $h->{msg}"};
			}
		}
		if (@$errs){
			$stuff.= join "\n",
				$ini->val($ini_sec,'error_before'),
				"ERRORS OCCURED".join "\n",map ($q->err($_),@$errs);
				$ini->val($ini_sec,'error_after'),
				;
		}
		$stuff .= join "\n",
			$ini->val($ini_sec,'success_before'),
			$lf->sbox('Success'),
			map (qq{<li>$_</li>},@$msgs),
			$lf->ebox,
			$ini->val($ini_sec,'success_after'),
			;

	}elsif ($confirm ==1){
		$stuff= join "\n",
			$ini->val($ini_sec,'nodelete_before'),
			$q->msg("Batch(es) not deleted"),
			$ini->val($ini_sec,'nodelete_after'),
			;

		# print $q->redirect("aspbatches.pl?SID=$SID");
		# exit;
	}else{
		my $bnames = join ',',@$bids;
		my $q = new TPerl::CGI('');
		$stuff = join "\n",
			$ini->val($ini_sec,'confirm_before'),
			$lf->sbox("Confirm"),
			qq{Reversing a batch cannot be undone.  Are you sure you want to reverse batch $bnames},
			$q->start_form(-method=>'POST',action=>$ENV{SCRIPT_NAME}),
			$q->hidden(-name=>'SID',-value=>$SID),
			map ($q->hidden(-name=>'BID',-value=>$_),@$bids),
			$q->popup_menu(-class=>'input',-name=>'confirm',-default=>2,-values=>[1,2],-labels=>{1=>'No',2=>'Yes'}),
			$q->submit(-class=>'input', -value=>'Reverse this batch'),
			$q->endform,
			# $q->dumper({bids=>$bids}),
			$lf->ebox,
			$ini->val($ini_sec,'confirm_after'),
			;
	}
}else{
	my $asp = new TPerl::ASP(dbh=>$dbh);
	my $batchlist = ($args{show_all}) ? $asp->batch_list(SID=>$SID)
					: $asp->batch_list(SID=>$SID,table_only=>1);
	$q->mydie($asp->err()) unless $batchlist;
	my $bvals = [sort {$a <=> $b} keys %$batchlist];
	my $blabs = {};
	$blabs->{$_} = "$batchlist->{$_}->{TITLE} : ($_)" foreach @$bvals;
	my $options = <<OPTIONS;
<INPUT type="checkbox" name="show_all" value="1" id="show_all">
<label for="show_all"> Show deleted/partial batches</label>
<input type="submit" value="Refresh">
OPTIONS
	if (@$bvals){
		# $q->mydie ($q->dumper($rows));
		$stuff = join "\n",
			$ini->val($ini_sec,'choose_before'),
			$lf->sbox("Choose batch(es) to reverse"),
			$q->start_form(-method=>'POST',action=>$ENV{SCRIPT_NAME}),
			$q->hidden(-name=>'SID',-value=>$SID),
			# $q->popup_menu(-class=>'input',-name=>'BID',-values=>$bvals,-labels=>$blabs),
			$q->checkbox_group(-class=>'input',-name=>'BID',-values=>$bvals,-labels=>$blabs,-columns=>2),'<BR>',
			$q->submit(-class=>'input', -value=>'Reverse batch(es)'),
			$lf->ebox,
			$options,
			$q->endform,
			$ini->val($ini_sec,'choose_after'),
			;
	}else{
		$stuff = join "\n",
				$lf->sbox("Choose batch(es) to reverse"),
				$q->msg("No batches found for $SID <BR>"),
				$q->start_form(-method=>'POST',action=>$ENV{SCRIPT_NAME}),
				$q->hidden(-name=>'SID',-value=>$SID),
				$lf->ebox,
				$options,
				$q->endform,
				;
	}

}


print join "\n",
	$q->header,
	$q->start_html(-title=>"Batch reverse",-style=>{src=>"/$SID/style.css"}, -class=>"body"),
	$stuff,
	$q->end_html;


