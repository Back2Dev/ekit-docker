#!/usr/bin/perl
#$Id: process_csv.pl,v 1.25 2006-10-05 21:59:10 triton Exp $
#
# Copyright Triton Information Technology 2004
#
# Script to process uploaded CSV data to (optionally) send emails, and schedule
# reminder(s) This is basically the second half of what used to be
# upload_csv.pl. This has now been reduced in size and functionality, so that
# it basically just handles the file upload, leaving a packet of information
# regarding what needs to be done. This script picks up that packet, and does
# the work of assembling files, inserting into the database etc.
#
use strict;
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
use TPerl::ConfigIniFiles;
use File::Basename;
use File::Slurp;
use TPerl::qtdb;
use TPerl::Error;
use TPerl::Error;
use POSIX;
use Template;
use TPerl::IniMapper;
use TPerl::Upload;
use Data::Dumper;
use Getopt::Long;
use Mail::Sender;
use File::Path;
use TPerl::DoNotSend;


#
# Check the primary parameter first to avoid processing if it's missing
#
my $e = new TPerl::Error (ts=>1);
#
# Variable declarations and initialisation
#
my $troot = getConfig('TritonRoot');
my $def_html = '';
my $whoru = 'system';
#
# All sorts of initialisation code, necessary to create all the multifarious objects we need
#
my $dbh = dbh TPerl::MyDB(attrs=>{PrintError=>0,RaiseError=>0}) or $e->F ("could not connect to database :".DBI->errstr);
my $ev = new TPerl::Event(dbh=>$dbh);
my $ez = new TPerl::DBEasy(dbh=>$dbh);
my $qtdb = new TPerl::Engine(dbh=>$dbh);

my $us_date = getConfig('us_date');
$e->F ("Server.ini is missing us_date= setting") unless $us_date;
my ($SID,$batchno);
{
	##Check if there is anything to do, and then update the batch table
	my $sql = 'select * from BATCH where status=4 order by UPLOAD_EPOCH ASC';
	if (my $res = $dbh->selectall_arrayref($sql,{Slice=>{}})){
		if (@$res == 0){
			# $e->I("Quitting Nothing to do");
			exit;
		}
		$SID = $res->[0]->{SID} or
			$e->F("Could not get SID from this record".Dumper $res->[0]);
		$batchno = $res->[0]->{BID} or
			$e->F("Could not get batchno from this record".Dumper $res->[0]);
	}else{
		$e->F({sql=>$sql,dbh=>$dbh});
	}

}
{
	##Check if anyone is in 'BEING PREPARED' status and quit if they are.
	my $sql = 'select count(*) from BATCH where status =5';
	if (my $res = $dbh->selectall_arrayref($sql)){
		if ($res->[0]->[0] >0){
			$e->I("Quitting. Someone else is being prepared");
			exit;
		}
	}else{
		$e->F({sql=>$sql,dbh=>$dbh});
	}
}


$e->I("Starting batch $batchno for $SID");
my $lfn = join '/',$troot,'log',"process_csv-$SID-batch-$batchno.log";
my $lfh = new FileHandle (">> $lfn") or $e->F("Could not open '$lfn':$!");
$e->fh([$lfh,\*STDOUT]);


# Look for a file in the queue dir.
# These lines should be in the Upload.pm...
my $up = new TPerl::Upload(SID=>$SID,troot=>$troot);
my $incdir = $up->filtered_dir();
my $pktdir = $up->packet_dir;
$e->F("pkt dir does not exist") unless -d $pktdir;
my $pkt_ini_fn = join '/',$pktdir,"$batchno.ini";
$e->F("Ini file $pkt_ini_fn does not exist") unless -f $pkt_ini_fn;
my $bfile;
my %args=();
{ 
	my $ini = new Config::IniFiles(-file=>$pkt_ini_fn) or
		$e->F("Could not open '$pkt_ini_fn' as an ini file");
	foreach my $arg ($ini->Parameters('args')){
		$args{$arg} = $ini->val('args',$arg);
	}
	# Fix this crap up here and in the upload one.  use FileBasename...
	my $end = 'csv';
	# $end = 'txt' if $allow_tsv;
	$bfile=  join '/',$incdir,"batch_$batchno.$end";
}

# Get the admin_email and the from email.
my ($from_email,$to_email);

{	
	my $sql = 'select * from JOB where SID=?';
	my $ps = [$SID];
	if (my $res = $dbh->selectall_arrayref($sql,{Slice=>{}},@$ps)){
		$from_email=$res->[0]->{EMAIL};
	}else{
		$e->F({sql=>$sql,params=>$ps,dbh=>$dbh});
	}
	$to_email=$args{admin_email} || $from_email;
}

my $brddir = join '/',$troot,$SID,'broadcast';
mkpath ($brddir,1) unless -d $brddir;
my $inifile = join '/',$troot,$SID,'config','upload_csv.ini';

$e->F ($up->err) unless $up->check_uploadini(err=>$e,args=>\%args);


my $html_template = $args{html_template};
my $plain_template = $args{plain_template};
my $inifile = $args{inifile};


# my $upinifile = join '/',$troot,$SID,'config','upload.ini';
# my $html_template = 'invitation-html1';
# my $plain_template = 'invitation-plain1';
# # I have plans for this bit.  It needs sanity check the various ini files and them optionally return 
# # a file name for the bit we are intersted in 
# if (-f $upinifile){
# 	$e->I("Reading upload config file: $upinifile");
# 	my $uini = new Config::IniFiles (-file=>$upinifile) or $e->F("Could not open '$upinifile' as an ini file");
# 	# Die unless [formats] section does not exist?
# 
# 	# choose first format as default if $args{format} not defined.
# 	unless ($args{format}){
# 		$args{format}=($uini->Parameters('formats'))[0];
# 		$e->I("Default to first format '$args{format}'");
# 	}
# 	my $file = $uini->val("format-$args{format}",'file');
# 	if ($file ne ''){
# 		$inifile = join '/',$troot,$SID,'config',$file;
# 	}else{
# 		$e->E("Missing section or value in upload.ini: [format-$args{format}]file=");
# 	}
# #??? Blindly assumed that either args{template} or args{format} is set can be a problem, especially first time thru
# 	my $template = $args{template};
# 	if ($uini->val('main','template_is_format')){
# 		# ie there is a one to one relationship bw format and template, and we don;t want to confuse them with a choice.
# 		$template=$args{format};
# 	}
# 	$html_template= $uini->val("email-$template",'html');
# 	$plain_template= $uini->val("email-$template",'plain');
# 	$args{html_template} ||= $html_template;
# 	$args{plain_template} ||= $plain_template;
# }
# # ??? Need to check templates exist at this point 

$e->I("Loading .ini file: $inifile");
$e->F ("Ini file '$inifile' does not exist") unless -e $inifile;
my $ini = new TPerl::ConfigIniFiles (-file=>$inifile) or $e->F("Could not open '$inifile' as an ini file");
my $ini_sec = fileparse ($ENV{SCRIPT_NAME}||$0,qr{\..*$});
$ini->sanity_logging (err=>$e,ini_sec=>$ini_sec,ini_fn=>$inifile);
my $do_pc = 1;
$do_pc = $ini->val('main','postcards') if defined $ini->val('main','postcards');
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

my $pcdir = join '/',$troot,$SID,'postcards';
my $emdir = join '/',$troot,$SID,'emails';
my $rejectdir = join '/',$troot,$SID,'rejects';

mkdir($incdir,0755) unless -f $incdir;
$e->F ( "Incoming dir '$incdir' does not exist") unless -d $incdir;
mkdir($rejectdir,0755) unless -f $rejectdir && $unique_uid;
$e->F ( "Rejects dir '$rejectdir' does not exist") if (!(-d $rejectdir) && $unique_uid);
if ($do_pc){
	mkdir($pcdir,0755) unless -f $pcdir;
	$e->F ( "Postcard dir '$pcdir' does not exist") unless -d $pcdir;
}
if ($do_aspemail){
	mkdir($emdir,0755) unless -f $emdir;
	$e->F ( "Emails dir '$emdir' does not exist") unless -d $emdir;
}


#--------------------------------------------------------------------------------
#
# This is the code that gets run to handle the uploaded file
#
#--------------------------------------------------------------------------------
my $upfile = $args{filename};
$e->I("Checking uploaded file $upfile ($bfile)");

### Get important stuff from ini file.
$e->F("[columns] section in inifile: $inifile' does not exist") unless $ini->SectionExists('columns');
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
	# $e->F ($q->dumper( $up_header));
$e->F("[asp_mapping] section in inifile $inifile' does not exist") unless $ini->SectionExists('asp_mapping');

### 
foreach my $crucial (@$crucial_asp_fields){
	$e->F ("Could not find crucial mapping for '$crucial' in 'asp_mapping' of $inifile") unless $ini->val('asp_mapping',$crucial);
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
			join ('',map (qq{<tr><td><b>$_</b></td><td> $map_errors->{$_}</td></tr>},keys %$map_errors)).
			"</table>";
		# $e->F($map_errors);
		$e->F($msg);
	}
}
# $e->F($q->dumper($up2asp));
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
push @$broadcast_header,'TAG' if $args{tag};

### copy the uploaded file and do an event

$e->I("Checking headers in uploaded file $bfile");
### check that the headers are in the uploaded file.
# don't need cvs_args, cause TPerl::TSV handles it..
my $tsv = new TPerl::TSV (file=>$bfile,nocase=>1);
{
	my $uheader = $tsv->header or $e->F ($tsv->err);
	my $uheader_hsh = $tsv->header_hash;
	#$e->F($tsv);
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
		$e->F( join "\n",
			$title,
			map(qq{<span class="$_->{style}">$_->{name}</span>},@$list));
	}

    ## Now add any headers in the the uploaded file to the $up_header.
    my $already = {};
    $already->{$_}=1 foreach @$up_header;
    foreach my $h (@$uheader){
        push @$up_header, $h unless $already->{$h};
    }
}
my $FILEUP = $ev->number('File Upload');
$ev->I(SID=>$SID,msg=>"Uploaded batch $batchno from $upfile",code=>$FILEUP,who=>$whoru,pwd=>$batchno);

my $sheets = [];
### get ready to process file.  open files and write headers
my ($em_file,$em_sheet,$em_book);
if ($do_aspemail){
	$em_file = join '/',$emdir,"emails_$batchno.xls";
	$em_book = new Spreadsheet::WriteExcel($em_file) or $e->F ("Could not make $em_file:$!");
	$em_sheet = $em_book->addworksheet('Emails') or $e->F ("Could not make email sheet");
	push @$sheets,$em_sheet;

}

my ($pc_book,$pc_file,$pc_sheet);
if ($do_pc){
	$pc_file = join '/',$pcdir,"postcards_$batchno.xls";
	$pc_book = new Spreadsheet::WriteExcel($pc_file) or $e->F ("Could not make $pc_file:$!");
	$pc_sheet = $pc_book->addworksheet('Postcards');
	push @$sheets,$pc_sheet;
}

my ($rej_book,$rej_sheet,$rej_file);
if ($do_aspemail || $unique_uid || $unique_email){
	$rej_file = join '/',$rejectdir,"dupes_$batchno.xls";
	$rej_book = new Spreadsheet::WriteExcel ($rej_file) or $e->F ("Could not open dups spreadsheet:$!");
	$rej_sheet = $rej_book->add_worksheet();
	push @$sheets,$rej_sheet;
}

my $sh_broadcast_file = "broadcast$batchno";
my $broadcast_file = join '/',$brddir,$sh_broadcast_file;
my $broadcast_fh = new FileHandle ("> $broadcast_file") or $e->F("Could not make $broadcast_file");
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

# $e->F({br_head=>$broadcast_header,lookup=>\%lookup,mapp_head=>\@mapped_br_header});

$e->I("About to process $bfile. Update the batch status to 'BEING PREPARED'");
{
	my $asp = new TPerl::ASP(dbh=>$dbh);
	my $fields = $asp->batch_fields();
	my $row = {BID=>$batchno,SID=>$SID,MODIFIED_EPOCH=>'now',STATUS=>5};
	foreach (keys %$fields){
		delete $fields->{$_} unless exists $row->{$_};
	}
	$e->F($_) if $_ = $ez->row_manip(vals=>$row,fields=>$fields,action=>'update',
		keys=>['SID','BID'],table=>'BATCH');
}



my $pc_row=0;
my $em_row=0;
my $dup=0;
my $rows =0;
my $preps =0;

my $dns = new TPerl::DoNotSend(dbh=>$dbh);

while (my $row = $tsv->row){
	$rows++;
	my $pwd;
	unless ($pwd_in_upload){
		$e->F ($qtdb->err()) unless $pwd = $qtdb->db_getnextpwd($SID);
		$row->{PASSWORD} = $pwd
	}
	# Now do the rest of the fields.  if you do them in the order in the file, then you can get functions of functions....
	foreach my $field (sort {$up2asp->{$a}->{order} <=> $up2asp->{$b}->{order} } keys %$up2asp){
		$row->{$field} = $ez->field2val(row=>$row,field=>$up2asp->{$field},no_nbsp=>1);
	}
	foreach my $fld (keys %related){
		$row->{$fld} = $related{$fld};
	}
	$row->{TAG} = $args{tag} if $args{tag};
	my $uid = $row->{UID};
	my $fullname = $row->{FULLNAME};
	my $email = $row->{EMAIL};
	my $ok = 1;
	my $need_to_write_dup=0;
	my @db_save_pwd_full_args = ($SID,$uid,$pwd,$fullname,0,$batchno,$email);
	# $e->F({r=>$row,l=>\@broadcast_line,h=>$broadcast_header});
	if ($unique_uid){
	 	if (check_uid_dup ($dbh,$SID,$uid)<1){
		}else{
			$dup++;
			$need_to_write_dup++;
			$ok = 0;
			$row->{RECSTATUS} = 'Duplicate UID';
		}
	}else{
		# The UID should go in if possible.
		$db_save_pwd_full_args[1]=$uid || '';
	}
	if (($email ne '') && $unique_email){
	 	if (check_email_dup ($dbh,$SID,$email)<1){
		}else{
			$dup++;
			$need_to_write_dup++;
			$ok = 0;
			$row->{RECSTATUS} = 'Duplicate Email';
		}
	}
	my $email_valid = 1;
	if ($email eq ''){
		if (!$do_pc){
			$row->{RECSTATUS} = 'Blank Email';
			$email_valid = 0;
		}
	}else{
		if (Email::Valid->address($email)){
			if (my $dns_msg = $dns->exists($email)){
				$row->{RECSTATUS} = "Rejected by DoNotSend list id:$dns_msg->{DNS_ID}";
				$email_valid = 0;
				unless ($do_pc){
					$need_to_write_dup++;
					$dup++;
					$ok=0;
				}
			}
		}else{
			$row->{RECSTATUS} = 'Reject by Email::Valid';
			$email_valid = 0;
			unless ($do_pc){
				$need_to_write_dup++;
				$dup++;
				$ok=0;
			}
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
				$e->E( $dberr );
				$ok=0;
				$row->{RECSTATUS} = $e->fmterr($dberr);
				$need_to_write_dup++;
			}
		}
	}

	my @broadcast_line = map $row->{$_},@$broadcast_header;
	if ($need_to_write_dup){
		foreach my $i (0..$#broadcast_line){
			$rej_sheet->write_string($dup,$i,$broadcast_line[$i]);
		}
	}
	if ($ok){
		if (($email && $do_aspemail && $email_valid) || ($one_file)){
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
unlink $pc_file unless $pc_row;

{
	$e->I("Finished prepare. Updating batch table");
	my $asp = new TPerl::ASP(dbh=>$dbh);
	my $fields = $asp->batch_fields();
	my $row = {BID=>$batchno,SID=>$SID,GOOD=>$preps,BAD=>$dup,MODIFIED_EPOCH=>'now',STATUS=>6};
	foreach (keys %$fields){
		delete $fields->{$_} unless exists $row->{$_};
	}
	$e->F($_) if $_ = $ez->row_manip(vals=>$row,fields=>$fields,action=>'update',
		keys=>['SID','BID'],table=>'BATCH');
}

my $prep_msg = qq{Records my be <a href="aspbatchreverse.pl?SID=$SID">removed</a> here};

my $em_mess = "$em_row new emails were processed\n" if $do_aspemail;
my $pc_msg = qq{$pc_row postcard entries were written to $pc_file\n} if $do_pc;
$def_html .= join "\n",
	"File Uploaded Successfully",
	qq{Batch $batchno has been successfully uploaded to $SID.},
	qq{It contains $rows rows of which $dup are duplicates.},
	qq{$preps records have been inserted into the database.},
	qq{$pc_msg},
	qq{$em_mess};
if ($do_aspemail){
	## Not all jobs need the "Houston, we have a problem" message if there is no emailing to be done....
	if ($em_row){
		my $s = new TPerl::Survey (SID=>$SID,TritonRoot=>$troot);
		my $i = new TPerl::Survey::Inviter($s);
		my $asp = new TPerl::ASP(dbh=>$dbh);
		# not doing a confirm step any more.  use the stuff from aspsendbatch.pl to whack things in email_work.
        my $errs = [];# These are any sql errors.
		my $new_rows = []; #These are the hashes that get inserted to email_work
		my $bsql = "select * from BATCH where BID=$batchno and SID=?";
		my $batch_info = {BID=>$batchno};
		if (my $res = $dbh->selectall_arrayref($bsql,{Slice=>{}},$SID)){
			$batch_info = $res->[0];
		}else{
			push @$errs,{sql=>$bsql,dbh=>$dbh};
		}
        my $wt = 1;             #wt=1 means invite
        my $when =  $args{invite_date};
        $when = "now" if ($when eq '');
        my ($plain_1,$html_1) = $i->invites;
        my $versions = {${wt}=>{plain=>$plain_1->active_files,html=>$html_1->active_files}};

        $def_html.= "Scheduled invitation to be sent : $when\n";
        my $fields = $asp->email_work_fields;
        my $row = {};
        $row->{PREPARED} = 1;
        $row->{NAMES_FILE} = $sh_broadcast_file;
        $row->{PLAIN_TMPLT} = $versions->{$wt}->{plain}->{1}->{file};
        $row->{PLAIN_TMPLT} = $args{plain_template}
                            if ($args{plain_template} ne '');
        $row->{HTML_TMPLT} = $versions->{$wt}->{html}->{1}->{file};
        $row->{HTML_TMPLT} = $args{html_template}
                            if ($args{html_template} ne '');
        $row->{START_EPOCH} = $when;
        $row->{INSERT_EPOCH} = 'now';
        $row->{PRIORITY} = 5;
        $row->{BID} = $batchno;
        $row->{SID} = $SID;
        $row->{WORK_TYPE} = $wt;
        $row->{EWID} = $ez->next_ids(table=>'EMAIL_WORK',keys=>['EWID'],dbh=>$dbh)->[0];
		$e->I("Using html_template $row->{HTML_TMPLT}");
		$e->I("Using plain_template $row->{PLAIN_TMPLT}");
        if (my $err = $ez->row_manip(fields=>$fields,dbh=>$dbh,action=>'insert',table=>'EMAIL_WORK',vals=>$row,keys=>['EWID'])){
            push @$errs,$err;
        }else{
            push @$new_rows,$row;
        }
        my ($plain_1,$html_1) = $i->reminders;
		{
			$e->I("Finished schedule. Updating batch table");
			my $asp = new TPerl::ASP(dbh=>$dbh);
			my $fields = $asp->batch_fields();
			my $row = {BID=>$batchno,SID=>$SID,GOOD=>$preps,BAD=>$dup,MODIFIED_EPOCH=>'now',STATUS=>7};
			foreach (keys %$fields){
				delete $fields->{$_} unless exists $row->{$_};
			}
			$e->E($_) if $_ = $ez->row_manip(vals=>$row,fields=>$fields,action=>'update',
				keys=>['SID','BID'],table=>'BATCH');
		}

        $wt++;                                              # Move on to do the same for reminders
        my $versions = {${wt}=>{plain=>$plain_1->active_files,html=>$html_1->active_files}};
        my $remno = 1;
        foreach my $thing (qw{reminder1 reminder2}){
            my $when =  $args{"${thing}_date"};
            next if ($when eq '');                          # Skip reminders if scheduled date is blank
            $def_html.= "Scheduled $thing to be sent: $when\n";
            my $fields = $asp->email_work_fields;
            my $row = {};
            $row->{PREPARED} = 1;  ## remimders are always prepared...
            $row->{NAMES_FILE} = $sh_broadcast_file;
            $row->{PLAIN_TMPLT} = $versions->{$wt}->{plain}->{$remno}->{file};
			$row->{PLAIN_TMPLT} = $args{"${thing}_plain"} if $args{"${thing}_plain"} ne '';
            $row->{HTML_TMPLT} = $versions->{$wt}->{html}->{$remno}->{file};
			$row->{HTML_TMPLT} = $args{"${thing}_html"} if $args{"${thing}_html"} ne '';
            $row->{START_EPOCH} = $when;
            $row->{INSERT_EPOCH} = 'now';
            $row->{PRIORITY} = 5;
            $row->{BID} = $batchno;
            $row->{SID} = $SID;
            $row->{WORK_TYPE} = $wt;
            $row->{EWID} = $ez->next_ids(table=>'EMAIL_WORK',keys=>['EWID'],dbh=>$dbh)->[0];
            if (my $err = $ez->row_manip(fields=>$fields,dbh=>$dbh,action=>'insert',table=>'EMAIL_WORK',vals=>$row,keys=>['EWID'])){
                push @$errs,$err;
            }else{
                push @$new_rows,$row;
            }
            $remno++;
        }
		my ($inv_summ,$rem1_summ,$rem2_summ);
		if (my $row = $new_rows->[0]){
			$inv_summ = qq{Invitation Scheduled: $row->{START_EPOCH}\n}.
						qq{Template(s): $row->{HTML_TMPLT} $row->{PLAIN_TMPLT}\n\n};
		}
		if (my $row = $new_rows->[1]){
			$rem1_summ= qq{Reminder 1 Scheduled: $row->{START_EPOCH}\n}.
						qq{Template(s): $row->{HTML_TMPLT} $row->{PLAIN_TMPLT}\n\n};
		}
		if (my $row = $new_rows->[2]){
			$rem2_summ= qq{Reminder 2 Scheduled: $row->{START_EPOCH}\n}.
						qq{Template(s): $row->{HTML_TMPLT} $row->{PLAIN_TMPLT}\n\n};
		}
		$def_html .= join "\n",
#			qq{Report for initial processing of Batch $batchno},
			'',
			qq{Batch Title : }.$batch_info->{TITLE},
			qq{Uploaded by : $batch_info->{UPLOADED_BY}},
			qq{Uploaded Date : }.$ez->epoch2text($batch_info->{UPLOAD_EPOCH}),
			qq{Lines in file : $rows},
			qq{DataBase Inserts : }.$batch_info->{GOOD},
			qq{Rejects : }.$batch_info->{BAD},
			'',
			$inv_summ,
			$rem1_summ,
			$rem2_summ,
			'',
			$ini->val($ini_sec,'inserts_email_after'),
			'';
	} else {
		$def_html = join "\n",
#			qq{Report for initial processing of Batch $batchno},
			'',
			qq{Lines in file : $rows},
			qq{DataBase Inserts: $preps},
			qq{Rejects: $dup},
			$em_mess,
			$pc_msg,
			'',
			$ini->val($ini_sec,'no_inserts_email_after'),
			'';
	}
	$def_html .= join ("\n",
		'',
		'The Rejects file is attached to for your information',
		'') if $dup;
}

# update the status of the batch.

# my $pkt_ini_fn = join '/',$pktdir, (read_dir($pktdir))[0];
# move ($pkt_ini_fn,$pkt_fin_dir) or $e->F("Could not move '$pkt_ini_fn' to '$pkt_fin_dir':$!");
$e->I($def_html);

# Do the email..
{
	my $smtp = getConfig('smtp_host') || 'localhost';
	my $bcc = 'ac@market-research.com';
	my $subject = "Upload processing results for batch $batchno";
	my $sender = new Mail::Sender {from=>$from_email,smtp=>$smtp,bcc=>$bcc,subject=>$subject,to=>$to_email};
	my $res0 = $sender->OpenMultipart;
	my $res4 = $sender->Body;
	my $res1 = $sender->SendLineEnc($def_html);
	my $res3 = $sender->Attach({file=>$rej_file}) if $dup;
	my $res2 = $sender->Close;
	$res0 = 'good' if ref $res0;
	$res1 = 'good' if ref $res1;
	$res2 = 'good' if ref $res2;
	$res3 = 'good' if ref $res3;
	$res4 = 'good' if ref $res4;
	$e->I( "Sent to'$to_email' smtp=$smtp return values:open=$res0 body=$res4 sendlines=$res1  attach=$res3 and close=$res2");
}

sub check_uid_dup {
	my $dbh = shift;
	my $SID = shift;
	my $uid = shift;

	my $sql = "select count(*) from $SID where UID=?";
	if (my $res = $dbh->selectall_arrayref($sql,{Slice=>{}},$uid)){
		return $res->[0]->{COUNT};
	}else{
		$e->F({sql=>$sql,dbh=>$dbh,params=>[$uid]});
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
		$e->F({sql=>$sql,dbh=>$dbh,params=>[$uid]});
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

