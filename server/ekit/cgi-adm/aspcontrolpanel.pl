#!/usr/bin/perl
#$Id: aspcontrolpanel.pl,v 1.24 2006-11-23 03:54:53 triton Exp $

use strict;
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::TritonConfig;
use TPerl::MyDB;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::StatSplit;
use TPerl::PFinder;
use Config::IniFiles;
use File::Slurp;
use TPerl::UploadData;
use TPerl::Template;

my $q = new TPerl::CGI;
my %args = $q->args;

my $SID = $args{SID} || $args{survey_id};
$q->mydie("no SID sent") unless $SID;

my $dbh = dbh TPerl::MyDB() or $q->mydie("Cannot connect to database:".TPerl::MyDB->err);
my $asp = new TPerl::ASP (dbh=>$dbh);
my $sec = new TPerl::ASP::Security ($asp);
my $esec = $sec->edit_security($ENV{REMOTE_USER},$SID);

$q->mydie ($_) if $_ = $esec->{err};

## If we are here we get a control panel.
my $lf = new TPerl::LookFeel(twidth=>180);

my $ss = new TPerl::StatSplit (SID=>$SID);
$ss->fixSplits();
# $q->mydie($ss->ini);
my $mnu = $ss->ini2menu(link_base=>"/$SID/admin/") or $q->mydie($ss);
# $q->mydie($mnu);

my $troot=getConfig("TritonRoot");
my $upload_ini = join '/',$troot,$SID,'config','upload_csv.ini';
my $upload_box = undef;
if (-e $upload_ini){
	my $ini = new Config::IniFiles(-file=>$upload_ini);
	my $do_aspemail = 1;
	$do_aspemail = $ini->val('main','email') if defined $ini->val('main','email');
	my $upload_csv = join "\n",
		qq{<A href="/cgi-adm/upload_csv_file.pl?SID=$SID" target="right">Upload Batch<a>},
		'<BR>';

	$upload_csv= join "\n",
		qq{<A href="/cgi-adm/upload_csv.pl?SID=$SID" target="right">Upload Batch<a>},
		'<BR>' if $ini->val('main','old_upload');

	$upload_box = join "\n",
		'<BR>',
		$lf->sbox('Batches'),
		qq{<A href="/cgi-adm/aspbatchstatus.pl?SID=$SID" target="right">Batch Disposition<a>},
		'<BR>',
		qq{<A href="/cgi-adm/aspbatchlist.pl?SID=$SID" target="right">Batch Detail<a>},
		'<BR>',
		$upload_csv,
		qq{<A href="/cgi-adm/aspbatchreverse.pl?SID=$SID" target="right">Reverse Batch<a>},
		'<BR>',
		qq{<A href="/cgi-adm/aspsendbatches.pl?SID=$SID" target="right">Unconfirmed Batches<a>},
		'<BR>',
		qq{<A href="/cgi-adm/previewemail3.pl?SID=$SID" target="right">Preview Email<a>},
		$lf->ebox;
	$upload_box .= qq{<A class="options" href="/cgi-adm/editemailMCE.pl?SID=$SID" target="right">Edit Email<a><BR>} if $ENV{REMOTE_USER} eq 'ac';
		
}

my $files_box = undef;
if (1){
	my $inifn = join '/',$troot,$SID,'config','cp_files.ini';
	unless (-e $inifn){
		my $sections = [qw(final doc incoming postcards emails rejects incdir filtered binfo)];
		my $pretties = {final=>'Data',doc=>'Labels',incdir=>'Incoming'};
		$pretties->{$_} ||= ucfirst($_) foreach @$sections;
		my $cont = join '',map qq{[$_]\npretty=$pretties->{$_}\nfilter=\n\n} ,@$sections;
		overwrite_file ($inifn,$cont) or die "Could not create '$inifn'";
	}
	my $ini = new Config::IniFiles (-file=>$inifn);
	my @sections = $ini->Sections;
	my $links = [];
	foreach my $subdir (@sections) {
		my $fs = join '/',$troot,$SID,'html','admin',$subdir;
		my $lk = join '/','',$SID,'admin',$subdir,'';
		if (-e $fs){
			my $limit = $ini->val($subdir,'display');
			my $pretty = $ini->val($subdir,'pretty');
			my $filter = $ini->val($subdir,'filter');
			my $qs = {};
			$qs->{filter}=$filter if $filter;
			$qs->{limit}=$limit if $limit;
			my $qs_str = join '&',map "$_=$qs->{$_}",keys %$qs;
			$qs_str="&$qs_str" if $qs_str;
			push @$links, qq{<a href="adm_dirlist.pl?survey_id=$SID&dir=$subdir$qs_str" target="right">$pretty</a>};
		}
	}
	if (@$links){
		$files_box = join "\n",
			'<BR>',
			$lf->sbox('Files'),
			join ("<BR>\n",@$links),
			$lf->ebox;
	}
}


my $pf = new TPerl::PFinder(SID=>$SID,look=>$lf);

my $cp_inifn = join '/',$troot,$SID,'config','controlpanel.ini';
unless (-e $cp_inifn){
	my $content = qq{[show]\neventlog=1\nsearch=1\n#upload_data=Extra Data\n};
	$content .= qq{\n\n#[Custom 1]\n#url=/cgi-adm/goose.pl?SID=[%SID%]\n#pretty=do the goose\n#users=ac,mikkel\n#target=};
	overwrite_file ($cp_inifn,$content) or die "Could not write $cp_inifn:$!";
}
my $cp_ini = new Config::IniFiles(-file=>$cp_inifn);
$q->mydie ("Could not parse $cp_inifn") unless $cp_ini;

my $upload_data_box;
if (my $title = $cp_ini->val('show','upload_data')){
	my $upd = new TPerl::UploadData(SID=>$SID,CGI=>$q);
	$upload_data_box = '<BR>'.$upd->left(box_only=>1,title=>$title);
}

my $event_box = join ("\n",
	'<BR>',
	$lf->sbox(''),
	qq{<A href="/cgi-adm/aspeventlog.pl?SID=$SID" target="right">Event Log<a>},
	$lf->ebox) if $cp_ini->val('show','eventlog');

my $serach_box = join "\n",
	'<BR>',
	$pf->left(action=>'/cgi-adm/asppfinder_cp.pl/right1',target=>'right')
		if $cp_ini->val('show','search');

my $extra_box;
my $extra_box_group = 'Custom';
if (my @groups = $cp_ini->GroupMembers($extra_box_group)){
	my $cnt = 0;
	my $orders = {};
	my $lines = {};
	foreach my $g (@groups){
		$cnt++;
		my $url = $cp_ini->val($g,'url');
		next unless $url;
		my $tt = new TPerl::Template(template=>$url);
		$url=$tt->process({sid=>$SID,remote_user=>$ENV{REMOTE_USER}}) || $q->my_die($tt->err);
		my $box_title = $cp_ini->val($g,'box') || 'Custom';

		my $pretty = $cp_ini->val($g,'pretty') || $url;
		my $target = $cp_ini->val($g,'target') || 'right';
		if (my $user = $cp_ini->val($g,'users')){
			my @users = split /,/,$user;
			next unless grep $ENV{REMOTE_USER} eq $_,@users
		}
		push @{$lines->{$box_title}},qq{<a href="$url" target=$target>$pretty</a>};
		$orders->{$box_title} ||= $cnt;
	}
	foreach my $title (sort {$orders->{$a} <=> $orders->{$b}} keys %$lines){
		if (my $lns = $lines->{$title}){
			$extra_box .= join "\n",
				'<BR>',
				$lf->sbox($title),
				map ("$_<BR>",@$lns),
				$lf->ebox;
		}
	}
	# $extra_box .= $q->dumper($orders);
}

my $dl_show = [split /,/,$cp_ini->val('show','datalist')];
push @$dl_show,'ac','mikkel';

my $data_list = qq{<a href="datalist.pl?survey_id=$SID&show=20" target="right">Datalist</a>} if grep $ENV{REMOTE_USER} eq $_,@$dl_show;

my $aspadmin = qq{ | <a href="aspadmin.pl" target="right">aspadmin</a>} if grep $_ eq $ENV{REMOTE_USER},qw(ac mikkel);

print join "\n",
	$q->header,
	$q->start_html(-style=>$q->adm_style($SID),-title=>"$SID Control Panel"),
	"$data_list$aspadmin",
	$lf->sbox($SID),
	$mnu->{menu},
	$mnu->{edit_custom_link},
	$lf->ebox,
	$files_box,
	$upload_box,
	$extra_box,
	$upload_data_box,
	$serach_box,
	$event_box,
	$q->end_html;




