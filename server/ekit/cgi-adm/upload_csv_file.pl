#!/usr/bin/perl
#$Id: upload_csv_file.pl,v 1.28 2006-11-23 03:54:53 triton Exp $
#
# Copyright Triton Information Technology 2004
#
# This script handles uploading of files.  GET/POST args are saved away in a
# TPerl::Upload->packet_dir() dir so that other things (filter_csv.pl process_csv.pl) can do stuff
# with them.  There are 2 parts, one presenting a form (you thought that would
# be easy...) and then handling the submit (again you thought it would be easy).  
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
use TPerl::TSV;
use TPerl::ASP;
use TPerl::ASP::Security;
use TPerl::DBEasy;
use TPerl::LookFeel;
use Config::IniFiles;
use File::Slurp;
use TPerl::qtdb;
use TPerl::Error;
use POSIX;
use Template;
use TPerl::IniMapper;
use TPerl::Upload;
use File::Basename;


my $troot = getConfig('TritonRoot');
my $q = new TPerl::CGI;
my %args = $q->args;
my $lf = new TPerl::LookFeel;
my $whoru = $ENV{REMOTE_USER};
$whoru = 'anon' if (($^O =~ /win32/i) && ($whoru eq ''));
my $def_html = '';

my $SID = $args{SID} || $args{survey_id};
$q->mydie("no SID sent") unless $SID;

my $us_date = getConfig('us_date');
$q->mydie("Server.ini is missing us_date= setting") unless $us_date;

# suspect globals.

### $ttfile is the template that the results are put into. This allows customization etc...
# %data fills this.  

# show_manual sets this var.
my $ttfile = 'upload_csv_file.htm';
my ($blank,$cgipath,$cgiscript) = split(/\//,$ENV{SCRIPT_NAME});

my %data=();
$data{SID} = $SID;
$data{script_name} = $ENV{SCRIPT_NAME};

## This bit could be a sub, in Upload.pm, cause its needed in the process one.
{
	my $uptemplate = join '/',$troot,$SID,'html','admin','upload_csv_file.htm';
	$ttfile = $uptemplate if -f $uptemplate;
	$q->mydie("Upload template file $ttfile $uptemplate missing\n") unless -f $ttfile;
}

my $tt = new Template({ ABSOLUTE => 1, });

my $dbh = dbh TPerl::MyDB () or $q->mydie ("could not connect to database :".DBI->errstr);
my $ev = new TPerl::Event(dbh=>$dbh);
my $ez = new TPerl::DBEasy(dbh=>$dbh);
my $FILEUP = $ev->number('File Upload');
my $qtdb = new TPerl::qtdb (dbh=>$dbh);
my $up = new TPerl::Upload(SID=>$SID,troot=>$troot);

my $lfn = join '/',$troot,'log','upload_csv_file.log';
my $lfh = new FileHandle (">> $lfn") or $q->mydie ("Could not open log file: $lfn:$!");
my $e = new TPerl::Error (noSTDOUT=>1,ts=>1,fh=>$lfh);

$e->I("STARTING SID=$SID ------------------------------------");

my $cfgdir = join '/',$troot,$SID,'config';

## check_uploadini put some stuff in the args hash.
$q->mydie ($up->err) unless $up->check_uploadini(err=>$e,args=>\%args);


my $html_template = $args{html_template};
my $plain_template = $args{plain_template};
my $inifile = $args{inifile};

$e->I("Loading .ini file: $inifile");
$q->mydie ("Ini file '$inifile' does not exist") unless -e $inifile;
my $ini = new TPerl::ConfigIniFiles (-file=>$inifile) or $q->mydie("Could not open '$inifile' as an ini file");
my $ini_sec = fileparse ($ENV{SCRIPT_NAME}||$0,qr{\..*$});
$ini->sanity_logging (err=>$e,ini_sec=>$ini_sec,ini_fn=>$inifile);

#
# Bring in params section, for use in html template
#
foreach my $col ($ini->Parameters('params'))
	{
	$data{$col} = $ini->val('params',$col);
	}


my $do_aspemail=1;
$do_aspemail = $ini->val('main','email') if defined $ini->val('main','email');
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


my $incdir = $up->incoming_dir();
my $pktdir = $up->packet_dir();

mkdir($incdir,0755) unless -f $incdir;
$q->mydie ( "Incoming dir '$incdir' does not exist") unless -d $incdir;
mkdir($pktdir,0755) unless -f $pktdir;
$q->mydie ( "Packet dir '$pktdir' does not exist") unless -d $pktdir;


### Now thats done, decide if we are presenting a form, or accepting data (and then maybe presenting a form.)
my $justform=1;

my $upfile = $args{filename};
$justform = 0 if ($upfile ne '');
my $nmanual = 0;

### Its pretty disastrous if we end up 
# my $batchno_file = join '/',$troot,$SID,'config','batchno.txt';

# This gets set in process_manual, or in the accept upload bit.
my $batchno ;
my $bfile;

our @manual_default_cols = ('fullname','email');
our $MAX_MANUAL = 10;
if ($args{manual})
	{
	$MAX_MANUAL = $ini->val('main','max_manual') if defined $ini->val('main','max_manual');
	$nmanual = process_manual();
	$justform = 0 if ($nmanual > 0);
	}


if ($justform){
	# We should be here if there was no manual data, or if there is no file uploaded....

	$data{warning}  = qq{<BR>You must enter a filename here} if ($args{title} ne '');	

	my $SID2 = $ini->val('related_survey','SID2');		# If there is a related survey to check on...
	if ($SID2 ne '') {
		my $sql = "select * from $SID2 where PWD=? order by TS DESC";
		$e->I("Looking into related survey $SID2, sql=$sql ($args{password})");
		my %resp = ();
		$data{password} = $args{password};
		$data{tag} = $args{tag};
		if (my $res = $dbh->selectall_arrayref($sql,{Slice=>{}},$args{password})){
			#error ($q->dumper($res));
			my $row = $res->[0] or error ("$ENV{REMOTE_USER} not found in the database. (sql=$sql)") ;
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
	my $asp = new TPerl::ASP(dbh=>$dbh);
	if ($args{manual}){
		$data{$_} = $args{$_} foreach keys %args;		# CGI arguments override other data (poss read from related survey
		#changes the ttfile template...
		show_manual() 
	}else{
		my $limbo = $asp->limbo_batches(SID=>$SID,who=>$ENV{REMOTE_USER}) || $q->mydie ($asp->err);
		if ($do_aspemail && @$limbo ){
			## we have found some limbo batches.  offer choices form and deal with them.
			## Limbo only makes sense for jobs that are sending email, not QIMR105 for eaxample.

			if (my $action = $args{limbo_action}){
				if ($action == 2){
					$e->I("Detected limbo batches, redirecting to aspsendbatches.pl");
					print $q->redirect("aspsendbatches.pl?SID=$SID");
					exit;
				}
			}else{
				my $b4 = $ini->val($ini_sec,'limbo_before') || 
					qq{I found some batches that are currently unconfirmed. 
						<P>This may be because of a problem you encountered last time you were here. 
						<P>You can ignore these and continue to the upload page, or go ahead and deal with them now. };
				my $title = 'Found unconfirmed batches';
				print join "\n",
					$q->header,
					$q->start_html(-title=>"$title",-style=>{src=>"/$SID/style.css"},-class=>'body'),
					$lf->sbox ("Found unconfirmed batches"),
					$q->start_form(),
					$b4,
					'<BR><BR>',
					$q->radio_group(-name=>'limbo_action',-values=>[1,2],-labels=>{1=>' Continue to upload page ',2=>' Deal with them now'}),
					$q->hidden(-name=>'SID',-value=>$SID),
					($args{password}?$q->hidden(-name=>'password',-value=>$args{password}):''),
					'<BR><BR>',
					$q->submit(-value=>'Go'),
					$q->endform,
					$lf->ebox,
					$ini->val($ini_sec,'limbo_after'),
					# $q->dumper(\%ENV),
					# $q->dumper(\%args),
					$q->end_html;
				$e->E("Error: Format mismatch");
				exit;
			}
		}
	}		

	my $bfields = $asp->batch_fields;
	my $tit_width = $bfields->{TITLE}->{DBI}->{PRECISION} || '100';


	my $title = "$SID batch upload page";
	my $schedule = '';
	$data{upload_format} = '';

#
# Note that the config item "us_date" governs the date format used here
# 
	my $redstar = qq{<FONT color="red" size="+1">*</font>};
	if ($ini->val('main','schedule')){
		my ($preview,$edit);
		my $dfmt = ($us_date) ? '%m/%d/%Y' : '%d/%m/%Y';
		my $invite_date = $data{invite_date} || $ez->epoch2text(time,$dfmt);
		my $reminder1_date = $data{reminder1_date} || $ez->epoch2text(time+24*3600*7,$dfmt);
		my $reminder2_date = $data{reminder2_date} || $ez->epoch2text(time+24*3600*14,$dfmt);

		$data{us_date} = $us_date;
		$data{date_fmt} = ($us_date) ? "MM/DD/YYYY" : "DD/MM/YYYY";
		my $tf = $q->textfield(-class=>'input',-name=>'invite_date',-value=>"$invite_date",size=>20,-title=>"Date of invitation");
		my $inv_file = join '/',$troot,$SID,'etemplate',$html_template;
		$preview = ($can_preview) ? qq{[<A HREF="previewemail3.pl?SID=$SID&file=$args{html_template}" target="_blank">Preview</A>]} : '';
		$edit = ($can_preview) ? qq{[<A target="_blank" href="editemailMCE.pl?SID=$SID&file=$args{html_template}">Edit</a>]} : '';
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
		my $rem1_file = join '/',$troot,$SID,'etemplate',$args{reminder1_html};
		$preview = ($can_preview) ? qq{[<A HREF="previewemail3.pl?SID=$SID&file=$args{reminder1_html}" target="_blank">Preview</A>]} : '';
		$edit = ($can_preview) ? qq{[<A target="_blank" href="editemailMCE.pl?SID=$SID&file=$args{reminder1_html}">Edit</a>]} : '';
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
		my $rem2_file = join '/',$troot,$SID,'etemplate',$args{reminder2_html};
		$preview = ($can_preview) ? qq{[<A HREF="previewemail3.pl?SID=$SID&file=$args{reminder2_html}" target="_blank">Preview</A>]} : '';
		$edit = ($can_preview) ? qq{[<A target="_blank" href="editemailMCE.pl?SID=$SID&file=$args{reminder2_html}">Edit</a>]} : '';
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
		$q->start_html(-title=>"$title",-style=>{src=>"/$SID/style.css"},-class=>'body'),
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

	$e->I("Presenting upload form");
}else{
#--------------------------------------------------------------------------------
#
# This is the code that gets run to handle the uploaded file
#
#--------------------------------------------------------------------------------
	$e->I("Checking uploaded file");
	if ($nmanual == 0){
		$q->mydie ("No file uploaded") unless $upfile;
		unless ($allow_tsv){
			$q->mydie ("Uploaded file '$upfile' must be a .csv file") unless $upfile =~ /csv$/i;
		}
### get next batchno
		$batchno = $up->next_batchno();
	
### copy the uploaded file and do an event
		my $end = 'csv';
		$end = 'txt' if $allow_tsv;
		$bfile = join '/',$incdir,"batch_$batchno.$end";
		copy ($upfile, $bfile) or $q->mydie ("Could not copy $upfile to $bfile:$!");
		$ev->I(SID=>$SID,msg=>"Uploaded batch $batchno from $upfile",code=>$FILEUP,who=>$whoru,pwd=>$batchno);
	}
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
	
	my $broadcast_header = [qw(EMAIL FULLNAME PASSWORD UID RECSTATUS)];
	
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

	
	$e->I("Checking headers in uploaded file: $bfile");
### check that the headers are in the uploaded file.
	my $tsv;
	{
# don't need csv_args, cause TPerl::TSV handles it..
		$tsv = new TPerl::TSV (file=>$bfile,nocase=>1);
		my $uheader = $tsv->header or $q->mydie ($tsv->err);
		my $uheader_hsh = $tsv->header_hash;
#		$q->mydie($tsv);
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
			$def_html .= join "\n",
				$q->header,
				$q->start_html(-title=>"$title",-style=>{src=>"/$SID/style.css"},-class=>'body'),
				$lf->sbox($title),
				qq{Here is a list of the columns that are expected in uploaded files.  
					<BR>Columns are marked as <span class="present">present</span> or 
					<span class="missing">missing</span> from the uploaded file.<BR>},
				map(qq{<BR><span class="$_->{style}">$_->{name}</span>},@$list),
				$lf->ebox,
				$q->end_html;
			print $def_html;
			$e->E("Error: Format mismatch");
			exit;
		}else{
			my $n = 0;
			$n++ while ($tsv->row());
			$e->I("Finished prepare. Inserting into batch table");
			my $asp = new TPerl::ASP(dbh=>$dbh);

			my $fields = $asp->batch_fields;
			my $zero = $ez->epoch2text(0);
			my $b_desc = $args{title};
			$b_desc ||= "Batch $batchno ".strftime('%b %d %Y',localtime);
			my $zero = $ez->epoch2text(0);

			my $or_name = "$upfile";
			my $length = $fields->{ORIG_NAME}->{DBI}->{PRECISION} || 100;
			$length = -$length;
			$or_name = substr $or_name,$length;
			my $row = {NAMES_FILE=>$bfile,UPLOAD_EPOCH=>'now',BID=>$batchno,SID=>$SID,
					UPLOADED_BY=>$whoru,ORIG_NAME=>$or_name,
					GOOD=>$n,BAD=>0,TITLE=>$b_desc,
					};
			$row->{TAG} = $args{tag} if ($args{tag});			# Option to tag the batch record, used by EMBA director to denote which program it is for.
			#This fixes mike wanting to write crap in old databases...
			foreach my $f (qw(DELETE_EPOCH CLEAN_EPOCH)){
				$row->{$f} = $zero unless $fields->{$f}->{DBI}->{NULLABLE};
			}
			$row->{STATUS} = 1 if $fields->{STATUS};
			$row->{MODIFIED_EPOCH} = 'now' if $fields->{MODIFIED_EPOCH};
			# $q->mydie({row=>$row,fields=>$fields});

			# $row->{NAMES_FILE} = $broadcast_file if $do_aspemail;
			$q->mydie($_) if $_=$ez->row_manip(table=>'BATCH',action=>'insert',vals=>$row,fields=>$fields);
			my $title = 'Success';
			$def_html = join "\n",
				$q->start_html(-title=>"$title",-style=>{src=>"/$SID/style.css"},-class=>'body'),
				$lf->sbox($title),
				$ini->val($ini_sec,'success_before'),
				"The format of your upload data looks good.  $n rows uploaded.",
				qq{<BR><form onsubmit="return(0)"><input type="button" onclick="document.location='/$cgipath/aspsendbatches.pl?SID=$SID'" value="Click here to go to confirmation step">},
				$lf->ebox,
				$ini->val($ini_sec,'success_after');

			my $pkt_ini_fn =  join '/',$pktdir,"$batchno.ini";
			$e->E("Overwriting $pkt_ini_fn") if -f $pkt_ini_fn;
			my @cont = ('[args]');
			push @cont,"$_=$args{$_}" foreach keys %args;
			push @cont, '[main]';
			push @cont, "batchno=$batchno";
			overwrite_file ($pkt_ini_fn,join "\n",@cont) or $q->mydie ("Could not write packet file $pkt_ini_fn:$!");
		}
	}
		
	$ttfile = "uploaded.htm";
	my $uptemplate = join '/',$troot,$SID,'html','admin','uploaded.htm';
	$ttfile = $uptemplate if -f $uptemplate;
}
#### Both bits end up printing this stufff out.

	if (-f $ttfile){
		$e->I("Using template '$ttfile'");
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
################################################################
# END OF MAIN LINE CODE
################################################################

sub error {
	my $msg = shift;
	print $q->header() unless  $q->{".header_printed"};
	my $title = $msg;
	print $q->start_html(-title=>"$title",-style=>{src=>"/$SID/style.css"},-class=>'body');
	print $q->err($msg);
	exit;
}
#
# Stuff for manual display and processing
#

sub show_manual{
	$ttfile = 'upload_csv_manual.htm';
	my $uptemplate = join '/',$troot,$SID,'html','admin','upload_csv_manual.htm';
	$ttfile = $uptemplate if -f $uptemplate;
	$q->mydie("Upload template file $ttfile $uptemplate missing\n") unless -f $ttfile;
	my @cols = $ini->Parameters('manual');
	@cols = @manual_default_cols if ($#cols == -1);
		
	$data{entry_grid} = <<HDR;
 <TABLE border="0" class="mytable" cellpadding="4" cellspacing=0>
 <TR><TH class="heading">&nbsp;
HDR
	foreach my $col (@cols){
		my $name = ($ini->val('manual',$col) ne '') ? $ini->val('manual',$col) : $col;
		$data{entry_grid} .= qq{<TH class="heading" align="left">$name</TD>};
	}
	my $options;
	for (my $n=1;$n<=$MAX_MANUAL;$n++)
		{
		$options = ($options eq "options") ? "options2" : "options";
		$data{entry_grid} .= qq{\n<TR><TD class="$options">$n.};
		foreach my $col (@cols){
			my $size = ($col eq 'email') ? qq{size="40"} : qq{size="20"};
			$data{entry_grid} .= qq{<TD class="$options"><input name="${col}_$n" type="text" $size>};
		}
	}
	$data{entry_grid} .= qq{</TABLE>};
}

sub process_manual{
	my $nrows = 0;
	my @cols = $ini->Parameters('manual');
	@cols = @manual_default_cols if ($#cols == -1);
#	$e->I("Checking for presence of manual data: ".join(",",@cols));
	my $filebuf = "";		
	$filebuf = join(",",@cols)."\n";
	for (my $n=1;$n<=$MAX_MANUAL;$n++){
		my $row = 0;
		my @mdata = ();
		foreach my $col (@cols){
			my $fname = "${col}_$n";
			push @mdata,$args{$fname};
			$row = 1 if ($args{$fname} ne '');
		}
		if ($row){
			$filebuf .= join(",",@mdata)."\n";
			$nrows++;
		}	
	}
	if ($nrows > 0){
# Now save the data to the file...
		$batchno = $up->next_batchno();
		$bfile = join '/',$incdir,"batch_$batchno.csv";
		$upfile="Manual";
		$e->I("Saving manually entered data to file: $bfile");
		write_file($bfile,$filebuf);
	}
#	$e->I("filebuf: $filebuf");
	$nrows;
}
