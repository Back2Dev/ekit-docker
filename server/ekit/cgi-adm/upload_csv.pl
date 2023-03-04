#!/usr/bin/perl
#$Id: upload_csv.pl,v 1.53 2009-03-31 12:04:09 triton Exp $
#
# Copyright Triton Information Technology 2004
#
# Script to upload CSV data to (optionally) send emails, and schedule reminder(s)
#
$|++;
use strict;
use CGI (-debug);
use CGI::Carp qw(fatalsToBrowser);
use TPerl::CGI;
use TPerl::TritonConfig;
use TPerl::Dump;
use File::Copy;
use TPerl::Event;
use Spreadsheet::WriteExcel;
use TPerl::TSV;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::DBEasy;
use TPerl::CmdLine;
use TPerl::LookFeel;
use Config::IniFiles;
use File::Slurp;
# use TPerl::qtdb;
use TPerl::Error;
use POSIX;
use Template;
use TPerl::IniMapper;
use TPerl::Upload;
use TPerl::Engine;


my $troot = getConfig('TritonRoot');
my $def_html = '';
my $q = new TPerl::CGI;
my %args = $q->args;
my $lf = new TPerl::LookFeel;
my $whoru = $ENV{REMOTE_USER};
$whoru = 'anon' if (($^O =~ /win32/i) && ($whoru eq ''));

my $SID = $args{SID} || $args{survey_id};
$q->mydie("no SID sent") unless $SID;

my $SSID = $args{SSID} || $args{ssurvey_id};
#$q->mydie("no Source SID (SSID) sent") unless $SSID;		# SSID is optional

# print header later on.  Mydie prints crap if this is done. print $q->header;
my $sql = "select SEQ from $SSID where pwd=?";
our %data;
$data{SID} = $SID;
$data{SSID} = $SSID;
$data{script_name} = $ENV{SCRIPT_NAME};
my $ttfile = 'upload.htm';
my $uptemplate = join '/',$troot,$SID,'html','admin','upload.htm';
$ttfile = $uptemplate if -f $uptemplate;
$q->mydie("Upload template file $ttfile $uptemplate missing\n") unless -f $ttfile;
my $tt = new Template({
	ABSOLUTE => 1,
#		INCLUDE_PATH => '/here:/there',
		});


my $b_desc = $args{title};

my $dbh = dbh TPerl::MyDB () or $q->mydie ("could not connect to database :".DBI->errstr);
my $ev = new TPerl::Event(dbh=>$dbh);
my $ez = new TPerl::DBEasy(dbh=>$dbh);
my $FILEUP = $ev->number('File Upload');
my $qtdb = new TPerl::Engine (dbh=>$dbh);

my $lfn = join '/',$troot,'log','upload_csv.log';
my $lfh = new FileHandle (">> $lfn") or $q->mydie ("Could not open log file: $lfn:$!");
my $e = new TPerl::Error (fh=>$lfh,ts=>1);

$e->I("STARTING SID=$SID");

my $cfgdir = join '/',$troot,$SID,'config';
my $inifile = join '/',$troot,$SID,'config','upload_csv.ini';
my $upinifile = join '/',$troot,$SID,'config','upload.ini';
my $html_template = 'invitation-html1';
my $plain_template = 'invitation-plain1';
if (-f $upinifile)
	{
	$e->I("Reading upload config file: $upinifile");
	my $uini = new Config::IniFiles (-file=>$upinifile) or $q->mydie("Could not open '$upinifile' as an ini file");
	# Die unless [formats] section does not exist?

	# choose first format as default if $args{format} not defined.
	unless ($args{format}){
		$args{format}=($uini->Parameters('formats'))[0];
		$e->I("Default to first format '$args{format}'");
	}
	my $file = $uini->val("format-$args{format}",'file');
	if ($file ne '')
		{
		$inifile = join '/',$troot,$SID,'config',$file;
		}
	else
		{$e->E("Missing section or value in upload.ini: [format-$args{format}]<BR>file=");}
#??? Blindly assumed that either args{template} or args{format} is set can be a problem, especially first time thru
	my $template = $args{template};
	if ($uini->val('main','template_is_format')){
		# ie there is a one to one relationship bw format and template, and we don;t want to confuse them with a choice.
		$template=$args{format};
	}
	$html_template = $uini->val("email-$template",'html') if ($uini->val("email-$template",'html') ne '');
	$e->E("Missing section or value in upload.ini: [email-$template]<BR>html=") if (($template ne '') && ($html_template eq ''));
	$e->I("html_template=$html_template");
	$plain_template = $uini->val("email-$template",'plain') if ($uini->val("email-$template",'plain'));
	$e->E("Missing section or value in upload.ini: [email-$template]<BR>plain=") if (($template ne '') && ($plain_template eq ''));
	$e->I("plain_template=$plain_template");
	my $f_h_temp = "$cfgdir/$html_template";
	$e->F("html_template '$f_h_temp' does not exist") unless -f $f_h_temp
	}
# ??? Need to check templates exist at this point 

$e->I("Loading .ini file: $inifile");
$q->mydie ("Ini file '$inifile' does not exist") unless -e $inifile;
my $ini = new Config::IniFiles (-file=>$inifile) or $q->mydie("Could not open '$inifile' as an ini file");
my $do_pc = 1;
$do_pc = $ini->val('main','postcards') if defined $ini->val('main','postcards');
my $us_date = getConfig('us_date') || '0';
my $do_aspemail=1;
$do_aspemail = $ini->val('main','email') if defined $ini->val('main','email');
my $one_file=0;
$one_file = $ini->val('main','one_file') if defined $ini->val('main','one_file');
my $unique_email=0;
$unique_email = $ini->val('main','unique_email') if defined $ini->val('main','unique_email');
my $unique_uid=1;
$unique_uid = $ini->val('main','unique_uid') if defined $ini->val('main','unique_uid');
my $allow_tsv = 0;
$allow_tsv = $ini->val('main','allow_tsv') if defined $ini->val('main','allow_tsv');
my $pwd_in_upload = 0;
$pwd_in_upload = $ini->val('main','pwd_in_upload') if defined $ini->val('main','pwd_in_upload');
my $can_preview=0;
$can_preview = $ini->val('main','preview') if defined $ini->val('main','preview');
my $can_edit=0;
$can_edit = $ini->val('main','edit') if defined $ini->val('main','edit');

# $q->mydie("pc=$do_pc");

my $incdir = join '/',$troot,$SID,'incoming';
my $pcdir = join '/',$troot,$SID,'postcards';
my $emdir = join '/',$troot,$SID,'emails';
my $rejectdir = join '/',$troot,$SID,'rejects';

mkdir($incdir,0755) unless -f $incdir;
$q->mydie ( "Incoming dir '$incdir' does not exist") unless -d $incdir;
mkdir($rejectdir,0755) unless -f $rejectdir && $unique_uid;
$q->mydie ( "Rejects dir '$rejectdir' does not exist") if (!(-d $rejectdir) && $unique_uid);
if ($do_pc){
	mkdir($pcdir,0755) unless -f $pcdir;
	$q->mydie ( "Postcard dir '$pcdir' does not exist") unless -d $pcdir;
}
if ($do_aspemail){
	mkdir($emdir,0755) unless -f $emdir;
	$q->mydie ( "Emails dir '$emdir' does not exist") unless -d $emdir;
}


my $upfile = $args{filename};
unless ($upfile){
	my $asp = new TPerl::ASP(dbh=>$dbh);
	my $SID2 = $ini->val('related_survey','SID2');		# If there is a related survey to check on...
	if ($SID2 ne '') {
		my $sql = "select * from $SID2 where PWD=? order by TS DESC";
		$e->I("Looking into related survey $SID2, sql=$sql");
		my %resp = ();
		$data{password} = $args{password};
		if (my $res = $dbh->selectall_arrayref($sql,{Slice=>{}},$args{password})){
			#error ($q->dumper($res));
			my $row = $res->[0] or error ("$ENV{REMOTE_USER} not found in the database.") ;
			my $seq = $row->{SEQ} or error ("$ENV{REMOTE_USER} has not completed the signup form");
			my $fn = join '/',$troot,$SID2,'web',"D$seq.pl";
			error ("$fn does not exist") unless -e $fn;
			eval read_file $fn;
			error ("Eval error in '$fn':$@") if $@;
		# 	error ("fn=$fn");
			my @related_fields = split(/,/,$ini->val('related_survey','transfer'));
			foreach my $fld (@related_fields) {
				my $newname = ($ini->val('related_survey',$fld) eq '') ? $fld : $ini->val('related_survey',$fld);
				$data{$newname} = $resp{$fld};
			}
		}else{
#			error($q->dberr(sql=>$sql,dbh=>$dbh,params=>[$ENV{REMOTE_USER}]));
		}
	}
	my $limbo = $asp->limbo_batches(SID=>$SID,who=>$ENV{REMOTE_USER}) || $q->mydie ($asp->err);
	if ($do_aspemail && @$limbo ){
		## we have found some limbo batches.  offer choices form and deal with them.
		## Limbo only makes sense for jobs that are sending email, not QIMR105 for eaxample.

		if (my $action = $args{limbo_action}){
			if ($action == 2){
				print $q->redirect("aspsendbatches.pl?SID=$SID");
				exit;
			}
		}else{
			print join "\n",
				$q->header,
				$q->start_html(-title=>'Found unconfirmed batches',-style=>{src=>"/$SID/style.css"}),
				$lf->sbox ("Found unconfirmed batches"),
				$q->start_form(),
				qq{I found some batches that are currently unconfirmed. 
					<P>This may be because of a problem you encountered last time you were here. 
					<P>You can ignore these and continue to the upload page, or go ahead and deal with them now. },
				'<BR><BR>',
				$q->radio_group(-name=>'limbo_action',-values=>[1,2],-labels=>{1=>' Continue to upload page ',2=>' Deal with them now'}),
				'<BR><BR>',
				$q->hidden(-name=>'SID',-value=>$SID),
				$q->submit(-value=>'Go'),
				$q->endform,
				$lf->ebox,
				$q->end_html;
			exit;
		}
	}

	$data{warning}  = qq{<BR>You must enter a filename here} if ($args{title} ne '');
	my $asp = new TPerl::ASP (dbh=>$dbh);
	my $bfields = $asp->batch_fields;
	my $tit_width = $bfields->{TITLE}->{DBI}->{PRECISION} || '100';

	my $title = "$SID batch upload page";
	my $schedule = '';
	$data{upload_format} = '';
	my $jscript = <<JS;
JS
#
# Note that the config item "us_date" governs the date format used here
# 
	my $redstar = qq{<FONT color="red" size="+1">*</font>};
	if ($ini->val('main','schedule'))
		{
		my ($preview,$edit);
		my $dfmt = ($us_date) ? '%m/%d/%Y' : '%d/%m/%Y';
		my $invite_date = $data{invite_date} || $ez->epoch2text(time,$dfmt);
		my $reminder1_date = $data{reminder1_date} || $ez->epoch2text(time+24*3600*7,$dfmt);
		my $reminder2_date = $data{reminder2_date} || $ez->epoch2text(time+24*3600*14,$dfmt);

		$data{us_date} = $us_date;
		$jscript = <<JS;
MORE
JS
		$data{date_fmt} = ($us_date) ? "MM/DD/YYYY" : "DD/MM/YYYY";
		my $tf = $q->textfield(-class=>'input',-name=>'invite_date',-value=>"$invite_date",size=>20,-title=>"Date of invitation");
		my $inv_file = join '/',$troot,$SID,'config',$html_template;
		$preview = ($can_preview) ? qq{[<A HREF="/cgi-adm/previewemail.pl?SID=$SID&email_msg=invitation1" target="_blank">Preview</A>]} : '';
		$edit = ($can_preview) ? qq{[<A target="_blank" href="/cgi-adm/editemail.pl?SID=$SID">Edit</a>]} : '';
		$data{invite_html} = qq{<font color="red"><B>Email template not present for invitation</B></font> $edit};
		$data{invite_check} = qq{	if (!checkd(document.q.invite_date,$us_date,1)) return false;};
		$data{invite_html} = <<INVITE if (-f $inv_file);
Please choose a date for the INVITE to be sent $preview $edit
<BR>
$redstar
$tf
<a href="javascript:show_calendar('q.invite_date',null,null,'$data{date_fmt}');" onmouseover="window.status='Date Picker';return true;" onmouseout="window.status='';return true;">
<img src="/pix/show-calendar.gif" width=24 height=22 border=0 align="top" alt="Pick date from pop-up calendar"></a>
INVITE
		my $tf = $q->textfield(-class=>'input',-name=>'reminder1_date',-value=>"$reminder1_date",size=>20,-title=>"Date of reminder #1");
		my $rem1_file = join '/',$troot,$SID,'config','reminder-html1';
		$preview = ($can_preview) ? qq{[<A HREF="/cgi-adm/previewemail.pl?SID=$SID&email_msg=reminder1" target="_blank">Preview</A>]} : '';
		$edit = ($can_preview) ? qq{[<A target="_blank" href="/cgi-adm/editemail.pl?SID=$SID&email_msg=reminder1">Edit</a>]} : '';
		$data{reminder1_html} = qq{(Email template not present for reminder 1) $edit};
		$data{reminder1_check} = qq{	if (!checkd(document.q.reminder1_date,$us_date,0)) return false;};
		$data{reminder1_html} = <<INVITE if (-f $rem1_file);
Please choose a date for REMINDER #1 to be sent $preview $edit
<BR>
$tf
<a href="javascript:show_calendar('q.reminder1_date',null,null,'$data{date_fmt}');" onmouseover="window.status='Date Picker';return true;" onmouseout="window.status='';return true;">
<img src="/pix/show-calendar.gif" width=24 height=22 border=0 align="top" alt="Pick date from pop-up calendar"></a>
<font color="red">(leave blank for no reminder 1)</font>
INVITE
		my $tf = $q->textfield(-class=>'input',-name=>'reminder2_date',-value=>"$reminder2_date",size=>20,-title=>"Date of reminder #2");
		my $rem2_file = join '/',$troot,$SID,'config','reminder-html2';
		$preview = ($can_preview) ? qq{[<A HREF="/cgi-adm/previewemail.pl?SID=$SID&email_msg=reminder2" target="_blank">Preview</A>]} : '';
		$edit = ($can_preview) ? qq{[<A target="_blank" href="/cgi-adm/editemail.pl?SID=$SID&email_msg=reminder2">Edit</a>]} : '';
		$data{reminder2_check} = qq{	if (!checkd(document.q.reminder2_date,$us_date,0)) return false;};
		$data{reminder2_html} = qq{(Email template not present for reminder 2) $edit};
		$data{reminder2_html} = <<INVITE if (-f $rem2_file);
Please choose a date for REMINDER #2 to be sent $preview $edit
<BR>
$tf
<a href="javascript:show_calendar('q.reminder2_date',null,null,'$data{date_fmt}');" onmouseover="window.status='Date Picker';return true;" onmouseout="window.status='';return true;">
<img src="/pix/show-calendar.gif" width=24 height=22 border=0 align="top" alt="Pick date from pop-up calendar"></a>
<font color="red">(leave blank for no reminder 2)</font><BR>
INVITE
		$schedule = join("\n",
						$data{invite_html},
						$data{reminder1_html},
						$data{reminder2_html},);
		my $upload_ini = join '/',$troot,$SID,'config','upload.ini';
		if (-f $upload_ini){
			my $uini = new Config::IniFiles (-file=>$upload_ini) or $q->mydie("Could not open '$upload_ini' as an ini file");
			my @formats = $uini->Parameters('formats');
			my $options = '';
			my $checked = "CHECKED";
			foreach my $i (0..$#formats){
				my $fmt = @formats[$i];
				my $name = $uini->val('formats',$fmt);
				$options .= qq{<input type="radio" id="format$fmt" };
				$options .= qq{name="format" value='$fmt' $checked><LABEL for="format$fmt">$name</LABEL><BR>};
				$checked = "";
				}
			my @formats = $uini->Parameters('emails');
			my $emoptions = '';
			my $checked = "CHECKED";
			foreach my $i (0..$#formats){
				my $fmt = @formats[$i];
				my $name = $uini->val('emails',$fmt);
				$emoptions .= qq{<input type="radio" id="template$fmt" };
				$emoptions .= qq{name="template" value='$fmt' $checked><LABEL for="template$fmt">$name</LABEL><BR>};
				$checked = "";
				}
			$data{upload_format} .= <<UPLOAD_SELECT;
<TABLE border=0><TR><TD valign="top">Select upload format: <TD>$options</TABLE>
UPLOAD_SELECT
			$data{upload_format} .= <<UPLOAD_SELECT if (@formats);
<TABLE border=0><TR><TD valign="top">Select email template: <TD>$emoptions</TABLE>
UPLOAD_SELECT
			}
		}
	$def_html = join "\n",
		$q->header,
		$q->start_html(-title=>"$title",-style=>{src=>"/$SID/style.css"}),
		$jscript,
		$lf->sbox($title),
		# $q->start_multipart_form(-method=>'POST',-action=>$ENV{SCRIPT_NAME},-name=>"q",-onsubmit=>"return QValid();"),
		$q->start_multipart_form(-method=>'POST',-action=>$ENV{SCRIPT_NAME},-name=>"q"),
		'Please describe this batch',
		'<BR> ',
		$redstar,
		$q->textfield(-class=>'input',-name=>'batch_desc',size=>$tit_width,maxlength=>$tit_width,-title=>"Name of batch"),
		'<BR>',
		'Please choose a file to upload',
		'<BR>',
		$redstar,
		$q->hidden (-name=>'SID',-value=>$SID),
		$q->filefield(-class=>'input',-name=>'filename',size=>80),
		"<BR><BR>",
		$data{upload_format},
		$schedule,
		'<BR>',
		$q->submit(-class=>'input',-name=>'',-value=>'Upload File'),
		$q->end_form,
		# $q->dumper($bfields),
		$q->end_html;

	if (-f $ttfile){
		print $q->header;
		$tt->process ($ttfile,\%data)
				or $q->mydie($tt->error);
	}
	else{
		print $def_html;
	}
	exit;
}
#--------------------------------------------------------------------------------
#
# This is the code that gets run to handle the uploaded file
#
#--------------------------------------------------------------------------------
$e->I("Checking uploaded file");
$q->mydie ("No file uploaded") unless $upfile;
unless ($allow_tsv){
	$q->mydie ("Uploaded file '$upfile' must be a .csv file") unless $upfile =~ /csv$/i;
}
my $orig_filename = "$upfile";

### Get important stuff from ini file.
$q->mydie("[columns] section in inifile: $inifile' does not exist") unless $ini->SectionExists('columns');
# Uppercase list of fields that we need from the file.
my $up_header = [map uc($_),$ini->Parameters('columns')];
my $up_header_hash = {};
$up_header_hash->{$_}++ foreach @$up_header;

my $up2asp = {};  ### This controls how we turn the uploaded fields into the 'aspinvite' fields.  
### It used to be just a lookup hash, but now it is a DBEasy field, and you use $ez->field2val to evaluate the values.

my $crucial_asp_fields = [];
push @$crucial_asp_fields,'password' if $pwd_in_upload;
push @$crucial_asp_fields, 'uid' if $unique_uid;
push @$crucial_asp_fields ,qw (fullname email) if $do_aspemail;
	# $q->mydie ($q->dumper( $up_header));
$q->mydie("[asp_mapping] section in inifile $inifile' does not exist") unless $ini->SectionExists('asp_mapping');

### 
foreach my $crucial (@$crucial_asp_fields){
	$q->mydie ("Could not find crucial mapping for '$crucial' in 'asp_mapping' of $inifile") unless $ini->val('asp_mapping',$crucial);
}

my $broadcast_header = [qw(EMAIL FULLNAME PASSWORD UID recstatus)];

my $mapping_names = [$ini->Parameters('asp_mapping')];
{
	my $map_errors = {};
	my $im = new TPerl::IniMapper();
	my $count = 0;
	my $special_vars = ['PASSWORD'];
	my @allowed_headings = @$up_header;
	push @allowed_headings,@$special_vars;
	foreach my $m_name (@$mapping_names){
		my $m = $ini->val('asp_mapping',$m_name);
		if (my $field = $im->mapping2field(mapping=>$m,headings=>\@allowed_headings,name=>$m_name)){
			$field->{order} = $count++;
			$up2asp->{uc($m_name)}=$field;
			push @allowed_headings,$m_name;
			push @$broadcast_header,uc($m_name);
		}else{
			$map_errors->{$m_name} = $im->err;
		}
	}
	if (%$map_errors){
		my $msg = "These [asp_mapping] maps had the following errors:<table>".
			join ('<BR>',map (qq{<tr><td><b>$_</b></td><td> $map_errors->{$_}</td></tr>},keys %$map_errors)).
			"</table>";
		# $q->mydie($map_errors);
		$q->mydie($msg);
	}
}
# $q->mydie($q->dumper($up2asp));
# If there is a related survey to bring stuff in from, then the necessary context information
# is available now as CGI arguments, which can be obtained from the %args hash.
my %related = ();
my $SID2 = $ini->val('related_survey','SID2');		
if ($SID2 ne '') {
	my @related_fields = split(/,/,$ini->val('related_survey','transfer'));
	foreach my $fld (@related_fields) {
		my $newname = ($ini->val('related_survey',$fld) eq '') ? $fld : $ini->val('related_survey',$fld);
		push @$broadcast_header,uc($newname);
		$related{uc($newname)} = $args{$newname};
	}
}

### get next batchno
my $up = new TPerl::Upload;
my $batchno_file = join '/',$troot,$SID,'config','batchno.txt';
my $batchno;
if (1){
	$batchno = $up->next_id($batchno_file);
}else{
	# If you are going to use this for debugging, you can clear the database tables
	# perl scripts/db.pl 'delete from email_work where SID=?' -p POW101 && perl scripts/db.pl 'delete from POW101 where BATCHNO=100' && perl scripts/db.pl 'delete from BATCH where SID=?' -p POW101
	$batchno=100;
}

### copy the uploaded file and do an event
my $end = 'csv';
$end = 'txt' if $allow_tsv;
my $bfile = join '/',$incdir,"batch_$batchno.$end";
copy ($upfile, $bfile) or $q->mydie ("Could not copy $upfile to $bfile:$!");

$e->I("Checking headers in uploaded file");
### check that the headers are in the uploaded file.
my $tsv;
{
	# don't need cvs_args, cause TPerl::TSV handles it..
	$tsv = new TPerl::TSV (file=>$bfile,nocase=>1);
	my $uheader = $tsv->header or $q->mydie ($tsv->err);
	my $uheader_hsh = $tsv->header_hash;
	#$q->mydie($tsv);
	my $list = [];
	my $missing = undef;
	foreach my $expected (@$up_header){
		my $style = 'present';
		unless ($uheader_hsh->{$expected}){
			$style = 'missing';
			$missing++;
		}
		push @$list ,{name=>$expected,style=>$style};
	}
	if ($missing){
		unlink $bfile;
		my $title="Column Error in uploaded file";
		print join "\n",
			$q->header,
			$q->start_html(-style=>{src=>"/$SID/style.css"},-title=>$title),
			$lf->sbox($title),
			qq{Here is a list of the columns that are expected in uploaded files.  
				<BR>Columns are marked as <span class="present">present</span> or 
				<span class="missing">missing</span> from the uploaded file.<BR>},
			map(qq{<BR><span class="$_->{style}">$_->{name}</span>},@$list),
			$lf->ebox,
			$q->end_html;
		exit;
	}
}

$ev->I(SID=>$SID,msg=>"Uploaded batch $batchno from $upfile",code=>$FILEUP,who=>$whoru,pwd=>$batchno);

my $sheets = [];
### get ready to process file.  open files and write headers
my ($em_file,$em_sheet,$em_book);
if ($do_aspemail){
	$em_file = join '/',$emdir,"emails_$batchno.xls";
	$em_book = new Spreadsheet::WriteExcel($em_file) or $q->mydie ("Could not make $em_file:$!");
	$em_sheet = $em_book->addworksheet('Emails') or $q->mydie ("Could not make email sheet");
	push @$sheets,$em_sheet;

}

my ($pc_book,$pc_file,$pc_sheet);
if ($do_pc){
	$pc_file = join '/',$pcdir,"postcards_$batchno.xls";
	$pc_book = new Spreadsheet::WriteExcel($pc_file) or $q->mydie ("Could not make $pc_file:$!");
	$pc_sheet = $pc_book->addworksheet('Postcards');
	push @$sheets,$pc_sheet;
}

my ($rej_book,$rej_sheet,$rej_file);
if ($unique_uid || $unique_email){
	$rej_file = join '/',$rejectdir,"dupes_$batchno.xls";
	$rej_book = new Spreadsheet::WriteExcel ($rej_file) or $q->mydie ("Could not open dups spreadsheet:$!");
	$rej_sheet = $rej_book->add_worksheet();
	push @$sheets,$rej_sheet;
}

my $broadcast_file = join '/',$cfgdir,"broadcast$batchno";
my $broadcast_fh = new FileHandle ("> $broadcast_file") or $q->mydie("Could not make $broadcast_file");
foreach my $col (@$up_header){
	unless ( grep /^$col$/i,@$broadcast_header){
		push @$broadcast_header,$col;
	}
}

# Change the column headings as we output to the broadcast file:, and the dups and postcards, and ufiles.
# the row value will always have upper case headings.
my %lookup = ();
foreach my $col ($ini->Parameters('columns')){
	my $val = $ini->val('columns',$col);
	$val =$col if $val eq '';
	$lookup{uc($col)} = $val;
}
# now make sure all the broadcast_header are in the lookup hash.
foreach my $h (@$broadcast_header){
	$lookup{$h} = $h if $lookup{$h} eq '';
}

my @mapped_br_header = map($lookup{$_},@$broadcast_header);
print $broadcast_fh join ("\t",@mapped_br_header)."\n";

foreach my $sh (@$sheets){
	foreach my $i (0..$#mapped_br_header){
		$sh->write_string(0,$i,$mapped_br_header[$i]);
	}
}

# $q->mydie({br_head=>$broadcast_header,lookup=>\%lookup,mapp_head=>\@mapped_br_header});

$e->I("About to process $bfile");

my $pc_row=0;
my $em_row=0;
my $dup=0;
my $rows =0;
my $preps =0;

while (my $row = $tsv->row){
	$rows++;
	my $pwd;
	unless ($pwd_in_upload){
		$q->mydie ($qtdb->err()) unless $pwd = $qtdb->db_getnextpwd($SID);
		$row->{PASSWORD} = $pwd
	}
	# Now do the rest of the fields.  if you do them in the order in the file, then you can get functions of functions....
	foreach my $field (sort {$up2asp->{$a}->{order} <=> $up2asp->{$b}->{order} } keys %$up2asp){
		$row->{$field} = $ez->field2val(row=>$row,field=>$up2asp->{$field},no_nbsp=>1);
	}
	foreach my $fld (keys %related){
		$row->{$fld} = $related{$fld};
	}
	my $uid = $row->{UID};
	my $fullname = $row->{FULLNAME};
	my $email = $row->{EMAIL};
	my $ok = 1;
	my $need_to_write_dup=0;
	my @db_save_pwd_full_args = ($SID,$uid,$pwd,$fullname,0,$batchno,$email);
	my @broadcast_line = map $row->{$_},@$broadcast_header;
	# $q->mydie({r=>$row,l=>\@broadcast_line,h=>$broadcast_header});
	if ($unique_uid){
	 	if (check_uid_dup ($dbh,$SID,$uid)<1){
		}else{
			$dup++;
			$need_to_write_dup++;
			$ok = 0;
		}
	}else{
		$db_save_pwd_full_args[1]='';
	}
	if (($email ne '') && $unique_email){
	 	if (check_email_dup ($dbh,$SID,$email)<1){
		}else{
			$dup++;
			$need_to_write_dup++;
			$ok = 0;
		}
	}
	if ($ok){
		if ($qtdb->db_save_pwd_full(@db_save_pwd_full_args)){
			mk_ufile($pwd,$row,\%lookup);
			$preps++;
		}else{
			my $dberr = $qtdb->err;
			if ($dberr->{dbh}->errstr =~ /violation of PRIMARY or UNIQUE KEY/i){
				$dup++;
				$need_to_write_dup++;
				$ok=0;
			}else{
				$q->mydie( $dberr );
			}
		}
	}
	if ($need_to_write_dup){
		foreach my $i (0..$#broadcast_line){
			$rej_sheet->write_string($dup,$i,$broadcast_line[$i]);
		}
	}
	if ($ok){
		if (($email && $do_aspemail) || ($one_file)){
			my ($firstname, $lastname, $recstatus,$fullemail);
			$recstatus = "DNS" if (!$email);
			# write to aspmailer mail.
			s/[\t\n\r]//g foreach @broadcast_line;
			print $broadcast_fh join ("\t",@broadcast_line)."\n";
			$em_row++;
			foreach my $i (0..$#broadcast_line){
				$em_sheet->write_string($em_row,$i,$broadcast_line[$i]);
			}
		}else{
			# prepare and write to postcard file
			if ($do_pc){
				$pc_row++;
				foreach my $i (0..$#broadcast_line){
					$pc_sheet->write_string($pc_row,$i,$broadcast_line[$i]);
				}
			}
		}
	}
}
close $broadcast_fh;
$pc_book->close() if $pc_book;
$em_book->close() if $em_book;
$rej_book->close() if $rej_book;
# close $rej_fh;
unlink $rej_file unless $dup;

$e->I("Finished prepare. Inserting into batch table");

$def_html .= $q->start_html(-title=>"$SID batch upload page",-style=>{src=>"/$SID/style.css"});
# print $q->dumper(\%args);
# now put the entry in the batches asp table.

my $asp = new TPerl::ASP(dbh=>$dbh);
my $sec = new TPerl::ASP::Security($asp);

my $fields = $asp->batch_fields;
my $zero = $ez->epoch2text(0);
$b_desc ||= "Batch $batchno ".strftime('%b %d %Y',localtime);
my $zero = $ez->epoch2text(0);


my $row = {NAMES_FILE=>$bfile,UPLOAD_EPOCH=>'now',BID=>$batchno,SID=>$SID,
		UPLOADED_BY=>$whoru,ORIG_NAME=>$orig_filename,
		CLEAN_EPOCH=>$zero,DELETE_EPOCH=>$zero,
		GOOD=>$preps,BAD=>$dup,TITLE=>$b_desc,
		STATUS=>7};


$row->{NAMES_FILE} = $broadcast_file if $do_aspemail;

$q->mydie($_) if $_=$ez->row_manip(table=>'BATCH',action=>'insert',vals=>$row,fields=>$fields);

my $prep_msg = qq{<BR>Records my be <a href="aspbatchreverse.pl?SID=$SID">removed</a> here};

my $em_mess = "<li>$em_row new emails were processed" if $do_aspemail;
$em_mess .= "</ul>";
$em_mess .= "Please indicate whether you wish to proceed with sending the emails or delete them" if $em_row;
my $pc_msg = qq{<li>$pc_row postcard entries were written to $pc_file} if $do_pc;
$def_html .= join "\n",
	$lf->sbox("File Uploaded Successfully"),
	qq{Batch $batchno ($b_desc) has been successfully uploaded to $SID.},
	'<ul>',
	qq{<LI>It contains $rows rows of which $dup are duplicates.},
	qq{<li>$preps records have been inserted into the database.},
	qq{$pc_msg},
	qq{$em_mess},
	$lf->ebox;
if ($do_aspemail){
	## Not all jobs need the "Houston, we have a problem" message if there is no emailing to be done....
	if ( $em_row){
# 		my $url = "aspsendbatches.pl?SID=$SID";
# 		my $inv_args = {};
# 		foreach (qw (invite_date reminder1_date reminder2_date html_template plain_template)){
# 			$inv_args->{$_} = $args{$_} if $args{$_} ne '';
# 		}
# 		my $date_qs = join "&",map "$_=$inv_args->{$_}",keys %$inv_args;
# 		$url .= "&$date_qs" if $date_qs;
# 		$def_html .= qq{<a href="$url">Click Here</A> to continue</a>};

		my $nobuttons=0;
		my $ret = $sec->confirm_broadcast_send (dbh=>$dbh,file=>$broadcast_file,SID=>$SID,nobuttons=>$nobuttons,BID=>$batchno,
				invite_date=>$args{invite_date},
				reminder1_date=>$args{reminder1_date},
				reminder2_date=>$args{reminder2_date},
				html_template=>qq{$cfgdir/$html_template},
				plain_template=>qq{$cfgdir/$plain_template},
				);
		$def_html .= '<BR>'.$ret->{page};
	} else {
	$def_html .= join "\n",
		"<br>",
		$lf->sbox("Houston, we have a problem."),
		qq{After processing the file you just uploaded ($upfile), there were no valid rows remaining.<br>},
		qq{There are a few reasons that could cause this:},
		qq{<UL>},
			qq{<li>The file has been uploaded before, and the rows are therefore all duplicated},
			qq{<li>All the rows have been eliminated due to missing mandatory fields, or invalid email addresses},
		qq{</ul>},
		qq{Please check your file, and try again.<BR>},
		qq{<form onsubmit="return false;"><input type="button" onclick="window.history.go(-1)" value="Go Back"></form>},
		$lf->ebox;
	}
}

$ttfile = "uploaded.htm";
my $uptemplate = join '/',$troot,$SID,'html','admin','uploaded.htm';
$ttfile = $uptemplate if -f $uptemplate;
if (-f $ttfile){
	print $q->header;
	$data{def_html} = $def_html;
	$tt->process ($ttfile,\%data)
            or $q->mydie($tt->error);
}
else {
	print $q->header;
	print $def_html;
	print $q->end_html;
}

sub check_uid_dup {
	my $dbh = shift;
	my $SID = shift;
	my $uid = shift;

	my $sql = "select count(*) from $SID where UID=?";
	if (my $res = $dbh->selectall_arrayref($sql,{Slice=>{}},$uid)){
		return $res->[0]->{COUNT};
	}else{
		print $q->dberr(sql=>$sql,dbh=>$dbh,params=>[$uid]);
		exit;
	}
}

sub check_email_dup {
	my $dbh = shift;
	my $SID = shift;
	my $uid = shift;

	my $sql = "select count(*) from $SID where email=?";
	if (my $res = $dbh->selectall_arrayref($sql,{Slice=>{}},$uid)){
		return $res->[0]->{COUNT};
	}else{
		print $q->dberr(sql=>$sql,dbh=>$dbh,params=>[$uid]);
		exit;
	}
}

sub trim
	{
	my $thing = shift;
	$thing =~ s/^\s+//;
	$thing =~ s/\s+$//;
	$thing;
	}

sub mk_ufile
	{
	my $password = shift;
	my $href = shift;
	my $lkref = shift;
	
	my $ufile = "$troot/$SID/web/u$password.pl";
	my $when = localtime;
	my $fh = new FileHandle ("> $ufile") or die "Can't make ufile '$ufile':$!";
	print $fh "#!/usr/bin/perl\n# $when\n# Data for user: $password\n%ufields = (\n";
	$$href{password} = $password;			# Make sure we have the password in the hash
	foreach my $key (sort keys %{$href})
		{
		my $lkey = ($$lkref{$key} ne '') ? $$lkref{$key} : $key;
		$lkey = lc($lkey);
		my $val = trim($$href{$key});
		$val =~ s/([\\'])/\\$1/g;
		print $fh "\t'$lkey' => '$val',\n";
		}
	print $fh "\t);\n\n";
	print $fh "# Please leave this soldier alone:\n1;\n";
	close $fh;
	}

sub error {
	my $msg = shift;
	print $q->header() unless  $q->{".header_printed"};
	print $q->start_html(-title=>$msg,-style=>{src=>"/$SID/style.css"}),$q->err($msg);
	exit;
}
