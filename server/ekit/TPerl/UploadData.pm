package TPerl::UploadData;
#$Id: UploadData.pm,v 2.3 2005-08-31 04:37:28 triton Exp $
use strict;
use vars qw (@ISA);
use Date::Manip;
use File::Copy;
use File::Touch;
use POSIX;
use TPerl::CGI;
use TPerl::DBEasy;
use TPerl::LookFeel;
use TPerl::MyDB;
use TPerl::StatSplit;
use TPerl::Survey;
use TPerl::TableManip;
use TPerl::TritonConfig;
use TPerl::TSV;
use TPerl::Upload;

@ISA = qw (TPerl::TableManip);

sub table_create_list {
	return [qw(UPLOAD_DATA)];
}

sub table_sql {
	my $self = shift;
	my $table = shift;
	if ($table eq 'UPLOAD_DATA'){
		return q{
			CREATE TABLE UPLOAD_DATA (
				TITLE       VARCHAR(100)    NOT NULL,
				SID         VARCHAR(12)     NOT NULL,
				BID         INTEGER         NOT NULL,
				UPLOADED_BY VARCHAR(8)      NOT NULL,
				ORIG_NAME   VARCHAR(200)    NOT NULL,
				UPLOAD_EPOCH INTEGER        NOT NULL,
				ROWS INTEGER				NOT NULL,
				FILENAME  VARCHAR(100)    	NOT NULL,
				FILE_DATE_EPOCH	INTEGER			NOT NULL,
				DELETE_EPOCH INTEGER,
				PRIMARY KEY (BID,SID) )
		};
	}
}

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my %args = @_;
	my $self = $proto->SUPER::new(@_);
	$self->CGI($args{CGI}) if exists $args{CGI};
	$self->SID($args{SID}) if exists $args{SID};
	return $self;
}

sub incoming_dir { return 'upload_data'}	# name of dir to put stuff in.
sub deleted_dir { return 'upload_deleted'}	# name of dir to put deleted stuff in.
sub upload_base_name { return 'data' }   # call files data_1.txt

####### Now I'm putting in the stuff from the CGI, so I can call bits from the control panel.

sub CGI { my $self=shift;return $self->{CGI} = @_[0] if @_;return $self->{CGI} }
sub SID { my $self=shift;return $self->{SID} = @_[0] if @_;return $self->{SID} }
sub sulist { return [qw(ac mikkel)] }

# my $sulist = [qw(ac mikkel)];
# 
# my $q = new TPerl::CGI;
# my %args = $q->args();
# 
# my $upd = new TPerl::UploadData();
# 
# my $ez = new TPerl::DBEasy (dbh=>$self->dbh);
# my $SID = $args{SID} or print ($q->noSID.$q->dumper(\%args)) and exit;
# 
# my $incoming = $self->incoming_dir();  # name of dir to put files in.
# my $upload_base = $self->upload_base_name();	# call files data_1.txt
# 
# unless ($ENV{PATH_INFO}){
# 	#$q->mydie( $q->frameset(qs=>"?SID=$SID"));
# 	print $q->frameset(qs=>"?SID=$SID");
# 	exit;
# }
# print (top()) and exit if $ENV{PATH_INFO} eq '/top';
# print (left()) and exit if $ENV{PATH_INFO} eq '/left';
# print (upload()) and exit if $ENV{PATH_INFO} eq '/upload';
# print (file_manage()) and exit if $ENV{PATH_INFO} eq '/right';
# print (table_edit()) and exit if $ENV{PATH_INFO} eq '/table_edit';

sub top {
	my $self = shift;
	my $SID = $self->SID;
	my %args = @_;
	my $box_only = $args{box_only};
	my $q = $self->CGI;
	my $lf = new TPerl::LookFeel();
	# my $tt = new HTML::Tooltip::Javascript(javascript_dir=>"/$SID/");
	# my $lnk = sprintf (qq{<a href="/" class="mytable" %s>Top</a>},$tt->tooltip('Tip'));

	return join "\n",
		$q->header,
		$q->start_html(-style=>{src=>"/$SID/style.css"}),
		# $q->img({-align=>'bottom',-src=>"/$SID/banner.gif"}),
		"$SID Data Uploader",
		# $lnk,
		# $tt->at_end,
		$q->end_html;
}

sub file_manage {
	my $self = shift;
	my $SID = $self->SID;
	my $q = $self->CGI;
	my %args = $q->args();
	my $up = new TPerl::Upload (dbh=>$self->dbh,SID=>$SID);
	my $troot = getConfig ('TritonRoot');
	my $dir_base = $self->incoming_dir();
	my $dir = join '/',$troot,$SID,$dir_base;
	my $ez = new TPerl::DBEasy (dbh=>$self->dbh);

	my $table = 'UPLOAD_DATA';
	my $fields = $up->file_db_fields(table=>$table);
	delete $fields->{$_} foreach qw(FILENAME);

	my $update_messages;
	### If there is a _NEW_BID update the database.
	if ($args{_NEW_BID}){
		my $row = {};my $update_fields = {};
		foreach my $a (keys %args){
			if (my ($f) = $a =~/^_NEW_(.*)$/){
				$row->{$f} = $args{$a};
				$update_fields->{$f} = $fields->{$f};
			}
		}
		# $q->mydie({fields=>$update_fields,table=>$table, action=>'update',vals=>$row,keys=>['BID']});
		my $db_err = $ez->row_manip(fields=>$update_fields,table=>$table, action=>'update',vals=>$row,keys=>['BID']);
		if ($db_err){
			$update_messages.= $q->err($db_err);
		}else{
			$update_messages.= "Changes made sucessfully for BATCH '$args{_NEW_BID}'<BR>";
		}
		if ($args{_NEW_FILE_DATE_EPOCH}){
			if ($up->touch_file_from_table(table=>$table,file_field=>'FILENAME',epoch_field=>'FILE_DATE_EPOCH',id=>$args{_NEW_BID})){
				$update_messages.="Date changed for file $args{_NEW_BID}<BR>";
			}else{
				$q->mydie($up->err);
			}
		}
	}
	### if there is a _delete, delete the file and update the database.
	if (my $f = $args{_delete}){
		my $file = join '/',$dir,$f;
		my $del = join '/',$troot,$SID,$self->deleted_dir(),$f;
		if (-e $file){
			if (move ($file,$del)){
				$update_messages.="$f deleted";
			}else{
				$q->mydie("Could not move '$f' to '$del':$!");
			}
		}else{
			$update_messages.= "File '$file' does not exist<BR>";
		}
		if (my $BID = $args{BID}){
			my $sql = "update $table set DELETE_EPOCH=? where BID=?";
			my $dbh = $self->dbh;
			if ($dbh->do ($sql,{},time(),$BID)){
			}else{
				$q->mydie({sql=>$sql,dbh=>$dbh,params=>[time(),$BID]});
			}
		}
	}

	my $dbh = $self->dbh;
	$dbh->{ib_time_all} = 'ISO';
	my $list =  $up->file_db_list(table=>$table,dir=>$dir);
	# $q->mydie ($list);

	my %js_FILE_DATE_args = (new_field_name=>'_NEW_FILE_DATE_EPOCH',form_name=>'fd_form',function_name=>'getNewFileDate',
		code_ref=>\&TPerl::DBEasy::e2t,prompt=>'Enter a Stats page date');

	my $jscript = join "\n",
		$up->js_getNewText(prompt=>'Please enter a new data title'),
		$up->js_getNewText(%js_FILE_DATE_args);

	$fields->{edit}->{code}={ref=>$up->field_getNewText(SID=>$SID),names=>[qw(TITLE BID DELETE_EPOCH)]};
	$fields->{edit_FILE_DATE}->{code}={ref=>$up->field_getNewText(SID=>$SID,%js_FILE_DATE_args),names=>[qw(FILE_DATE_EPOCH BID DELETE_EPOCH)]};
	$fields->{edit_FILE_DATE}->{order}=8.5;
	$fields->{del}->{code}={ref=>$up->field_deleteBatch(SID=>$SID),names=>[qw(id file TITLE DELETE_EPOCH BID)]};

	my $ss = new TPerl::StatSplit (SID=>$SID);
	my ($count,$group) = $ss->countSplits();
	if ( $count <= 1){
		delete $fields->{$_} foreach qw (edit_FILE_DATE FILE_DATE_EPOCH);
	}

	$fields->{file}->{code} = {ref=>sub {my $file = shift;return undef unless $file;return sprintf(qq{<a href="/$SID/admin/$dir_base/%s">%s</a>},$file,$file)},names=>['file']};
	# {fmt=>qq{<a href="/$SID/admin/$dir_base/%s">%s</a>},names=>[qw(file file)]};

	my $state = {SID=>$SID};
	my $ez = new TPerl::DBEasy (dbh=>$self->dbh);
	my $lf = new TPerl::LookFeel();
	my $page = $args{next} if $args{submit} =~ /next/i;
	$page = $args{previous} if $args{submit} =~ /prev/i;
	$page = $args{page} if $args{submit} =~ /go/i;

	my $lister = $ez->lister(fields=>$fields,look=>$lf,rows=>$list,form_hidden=>$state,form=>1,limit=>10,page=>$page);
	my $html;
	if ($lister->{count}){
		$html .= "$lister->{count} rows";
		$html .= join '',@{$lister->{html}};
		$html .= join '',@{$lister->{form}};
	}elsif ($lister->{err}){
		$q->mydie($lister);
	}else{
		$html.='No Data';
	}
	my $dbh = $self->dbh;

	return join "\n",
		$q->header,
		$q->start_html(-title=>"$SID Uploaded Data",-style=>{src=>"/$SID/style.css"},script=>$jscript),
		$update_messages,
		$html,
		# $q->dumper(\%args),
		# scalar(localtime),
		# $q->dumper($fields),
		# $q->dumper($list),
		$q->end_html;
}

sub left {
	my $self = shift;
	my %args = @_;
	my $SID = $self->SID;
	my $q = $self->CGI;
	my $lf = new TPerl::LookFeel;
	my $sulist = $self->sulist;
	my $table_edit_link = qq{<a href="/cgi-adm/upload_data.pl/table_edit?SID=$SID" target="right">Table admin</a>} if grep $_ eq $ENV{REMOTE_USER},@$sulist;
	my $box_only = $args{box_only};
	my $title = $args{title} || 'Upload Extra Data';
	return join "\n",
		$box_only ? '' : $q->header,
		$box_only ? '' : $q->start_html(-title=>"$SID Data Control Panel",-style=>{src=>"/$SID/style.css"}),
		$lf->sbox($title),
		qq{<a href="/cgi-adm/upload_data.pl/upload?SID=$SID" target="right">Upload File</a>},
		'<BR>',
		qq{<a href="/cgi-adm/upload_data.pl/right?SID=$SID" target="right">Manage Files</a>},
# 		'<BR>',
# 		qq{<a href="/cgi-adm/adm_dirlist.pl?SID=$SID&dir=$incoming&filter=$upload_base&table=UPLOAD_DATA">Download Files</a>},
		$lf->ebox,
		$table_edit_link,
		$q->end_html;
}

sub upload {
	
	my $self = shift;
	my $SID = $self->SID;
	my $q = $self->CGI;
	my %args = $q->args();
	my $lf = new TPerl::LookFeel;

	my $ez = new TPerl::DBEasy (dbh=>$self->dbh);
	my $troot = getConfig('TritonRoot');
	my $upload_field_name = 'file';  # the name of the file upload field.
	my $upload_base = $self->upload_base_name();

	my $incoming = $self->incoming_dir();

	my $inc_dir = join '/',$troot,$SID,$incoming;
	unless (-d $inc_dir){
		mkdir ($inc_dir) or $q->my_die("Could not create '$inc_dir':$!");
	}

	my $ss = new TPerl::StatSplit (SID=>$SID);
	my $ini = $ss->ini() or $q->mydie ("Coold not get statsplit ini file".$ss->err);
	#use a data file to see which columns we accept/expect.
	

	my ($scount,$sgroup) = $ss->countSplits();
	# $q->mydie ($ini);
	my @groups = $ini->GroupMembers($sgroup);
	my $group = $args{group} || 0;
	my $ext = $ini->val($groups[$group],'ext');
	# my $start = UnixDate($ini->val($groups[$group],'start'),'%Y-%m-%d');
	# $q->mydie ("ext=$ext start=$start");
	my $dfn = $args{dfn} = join '/',$troot,$SID,'final',"$SID$ext.txt";
	my $group_msg ='';
	if ($scount>1){
		$group_msg = "<BR>Build a form to alter the group arg";
	}
	
	$q->mydie ("There is no data file '$dfn'") unless -e $dfn;

	my $dtsv = new TPerl::TSV (file=>$dfn);
	my $df_head = $dtsv->header() or $q->mydie("Could not get a header from '$dfn':".$dtsv->err);

	my $title = "Upload $SID data";

	if (my $upfile = $args{$upload_field_name}){
		# process the uploaded file.
 		my $up = new TPerl::Upload (expected=>$df_head,incoming=>$incoming);
 		my $orig_filename = "$upfile";
 		my ($end) = $orig_filename =~ /\.(\w+)$/;
		$q->mydie ("Uploaded file '$orig_filename' must be a csv or tab delimited text file") unless 
			grep $_ eq lc($end),'txt','csv';

		# Get next batch no. and copy file to incoming.
		my $id_no_fn = join '/',$troot,$SID,'config',"$incoming.txt";
		my $id_no = $up->next_id($id_no_fn) or $q->mydie ("Could not get batch number:".$up->err);
		my $new_filename = join '/',$inc_dir,"${upload_base}_$id_no.$end";
		copy ($upfile,$new_filename) or $q->mydie ("Could not copy $upfile to $new_filename:$!");

		# Find the overlapping 
		my $utsv = new TPerl::TSV (file=>$new_filename);
		my $uhead = $utsv->header or $q->mydie("Could not get header from uploaded file:".$utsv->err);
		my $overlap = [];
		{
			# Combine the heads
			my $head_l = [];
			my $head_h = {};
			foreach my $col (@$df_head,@$uhead){
				my $uf = uc ($col);
				push @$head_l ,$col unless $head_h->{$uf};
				$head_h->{$uf}++;
			}
			my $head_up = {};
			my $head_df = {};
			$head_up->{uc($_)}++ foreach @$uhead;
			$head_df->{uc($_)}++ foreach @$df_head;
			foreach my $col (@$head_l){
				my $uf = uc($col);
				my $style;
				if ($head_up->{$uf} && $head_df->{$uf}){
					$style='present';
				}elsif ($head_up->{$uf} && !$head_df->{$uf}){
					$style='added';
				}else{
					$style='missing';
				}
				push @$overlap, {style=>$style,name=>$col};
			}
		}
		while (my $urow = $utsv->row()){}
		my $dbh = dbh TPerl::MyDB or $q->mydie("Could not connect to database:".TPerl::MyDB->err());
		my $ez = new TPerl::DBEasy (dbh=>$dbh);
		my $count = $utsv->count;
		my $row = {SID=>$SID,BID=>$id_no,UPLOADED_BY=>$ENV{REMOTE_USER}||'_none_',
			TITLE=>$args{title},ORIG_NAME=>$orig_filename,ROWS=>$count||0,
			UPLOAD_EPOCH=>'now',DATAFILE=>$dfn,TITLE=>$args{TITLE}||'Data batch',
			FILE_DATE_EPOCH=>$args{FILE_DATE_EPOCH},FILENAME=>$new_filename};
		$q->mydie($_) if $_ = $ez->row_manip (table=>'UPLOAD_DATA',vals=>$row,action=>'insert');



		return join "\n",
			$q->header,
			$q->start_html(-title=>$title,-style=>{src=>"/$SID/style.css"}),
			$lf->sbox($title),
			"Uploaded '$orig_filename' with $count rows as batch $id_no",
			'<BR>',
			'Status of uploaded and existing data columns<BR>',
			'<span class="present">present in both files</span><BR>',
			'<span class="missing">In Survey, Missing from uploaded file</span><BR>',
			'<span class="added">Added by uploaded file</span><BR><BR>',
			'<table>',
			join ("\n",map qq{<tr><td class="$_->{style}">$_->{name}</td></tr>},@$overlap),
			'</table>',
			$lf->ebox,
			$q->end_html;
	}else{
		# display the form to upload
		my $tit_width=60;
		my $start = $ini->val($groups[$group],'start');
		$start = 'now';#  if $start eq '1970';
		return join "\n",
			$q->header,
			$q->start_html(-title=>$title,-style=>{src=>"/$SID/style.css"}),
			$lf->sbox($title),
			$group_msg,
			$q->start_multipart_form(-method=>'POST',-action=>"$ENV{SCRIPT_NAME}$ENV{PATH_INFO}"),
			'Please describe this batch','<BR>',
			$q->textfield(-class=>'input',-name=>'TITLE',size=>$tit_width,maxlength=>$tit_width,
				-title=>"Name of batch",default=>'Data Batch'),
			'<BR>',
			$q->filefield(-class=>'input',-name=>$upload_field_name),
			$q->hidden (-name=>'SID',-value=>$SID),
			$q->hidden (-name=>'FILE_DATE_EPOCH',-value=>$start),
			'<BR>',
			$q->submit(-class=>'input',-name=>'',-value=>'Upload File'),
			$q->end_form,
			"Upload a csv or tab delimited text file with some or all of these data columns <BR><BR>".join ('<BR>',@$df_head),
			$lf->ebox,
			$q->end_html;
	}

}

sub table_edit {
	my $self = shift;
	my $SID = $self->SID;
	my $q = $self->CGI;
	my %args = $q->args();
	my $sulist = $self->sulist;
	$q->mydie("Not in su list") unless grep $_ eq $ENV{REMOTE_USER},@$sulist;
	my $tables = $self->table_create_list;
	$args{table} ||=$tables->[0];
	if ($args{table} eq 'UPLOAD_DATA'){
		$args{_list_sql} = 'SELECT * FROM UPLOAD_DATA where SID=? order by BID desc';
		$args{_list_params} = [$SID];
	}
	my $ez = new TPerl::DBEasy (dbh=>$self->dbh);
	my $state = [qw(SID table edit new delete)] ;
	my $res = $ez->edit(_obj=>$self,_new_buttons=>$tables,
		_tablekeys=>{UPLOAD_DATA=>['BID']},
		_state=>$state,%args);
	if ($res->{err}){
		$q->mydie ($res->{err});
	}else{
		return join "\n",
			$q->header,
			$q->start_html(-title=>$0,-style=>{src=>"/$SID/style.css"},-class=>'body'),
			$res->{html},
			# $q->dumper(\%args),
			$q->end_html;
	}
}

1;
