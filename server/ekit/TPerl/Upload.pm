package TPerl::Upload;
use strict;
use File::Slurp;
use File::Touch;
use DirHandle;
use Carp qw (confess);
use TPerl::TritonConfig;
use Config::IniFiles;
use TPerl::Hash;
use TPerl::IniMapper;
use Data::Dumper;
use TPerl::DBEasy;

# This will do the copy, and field checking when uploading a file.
# you can pass stuff in or look in an ini file.

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self,$class;
    my %args = @_;
	
	my $bits = [qw (expected mapping incoming dbh SID troot)];
	foreach my $b (@$bits){
		$self->$b($args{$b}) if defined $args{$b};
	}
    return $self;
}

sub expected { my $self=shift;$self->{_expected}=$_[0] if @_;return $self->{_expected}}
sub mapping { my $self=shift;$self->{_mapping}=$_[0] if @_;return $self->{_mapping}}
sub incoming { my $self=shift;$self->{_incoming}=$_[0] if @_;return $self->{_incoming}}
sub err { my $self=shift;$self->{_err}=$_[0] if @_;return $self->{_err}}
sub troot { my $self=shift;$self->{_troot}=$_[0] if @_;return $self->{_troot}}
sub dbh { my $self=shift;$self->{_dbh}=$_[0] if @_;return $self->{_dbh}}
sub SID { my $self=shift;$self->{_SID}=$_[0] if @_;return $self->{_SID}}
sub html_template { my $self=shift;$self->{_html_template}=$_[0] if @_;return $self->{_html_template}}
sub plain_template { my $self=shift;$self->{_plain_template}=$_[0] if @_;return $self->{_plain_template}}

# This is a better version of check_uploadini
#
sub parse_uploadini {
	my $self = shift;

	my %args = @_;
	my $SID = $self->SID || confess("pass 'SID' to new()");
	my $troot = $self->troot || confess("pass 'troot' to new()");

	# if there is an upload.ini then we do things different.
	my $upload_ini = $self->uploadini_filename;
	my $ret = {};
	my $errs = [];
	my $warns = [];
	my $uini;
	if (-e $upload_ini){
		$uini = new Config::IniFiles (-file=>$upload_ini);
		unless ($uini){
			$self->err("Could not open '$upload_ini' as an ini file");
			return undef;
		}
	}elsif (-e $self->uploadcsv_filename){
		# make a fake one that matches the current check_upload.ini thing
		#
		my $fname = 'imaginary';
		$uini = new Config::IniFiles();
		$uini->newval('main','template_is_format','1');
		$uini->newval('formats',$fname,'Email');
		$uini->newval("format-$fname",'file','upload_csv.ini');
		$uini->newval("email-$fname",'plain','invite.txt');
		$uini->newval("email-$fname",'html','invite.html');
		$uini->newval("reminder1-$fname",'plain','reminder1.txt');
		$uini->newval("reminder1-$fname",'html','reminder1.html');
 		$uini->newval("reminder2-$fname",'plain','reminder2.txt');
 		$uini->newval("reminder2-$fname",'html','reminder2.html');
	}else{
		$self->err(sprintf "No '%s' or '%s' files",$upload_ini,$self->uploadcsv_filename);
		return undef;
	}
	unless ($uini->SectionExists('formats')){
		$self->err("no Section '[formats]' in upload.ini");
		return undef;
	}
	my $used_sections = {formats=>1};
	my @formats = $uini->Parameters('formats');
	unless (@formats){
		$self->err("No format definitions in '[formats]' section");
		return undef;
	}
	my $format_vals = {};
	$format_vals->{$_} = $uini->val('formats',$_) foreach @formats;
	$ret->{formats} = \@formats;
	$ret->{format_vals} = $format_vals;
	foreach my $f (@formats){
		my $s = "format-$f";
		if ($uini->SectionExists($s)){
			$used_sections->{$s}++;
			if (my $fi = $uini->val($s,'file')){
				my $file = join '/',$troot,$SID,'config',$fi;
				if (-e $file){
					$ret->{format_defns}->{$f}->{file} = $file;
				}else{
					push @$errs,"Format definition file '$file' does not exist";
				}
			}else{
				push @$errs,"No 'file=' in [$s] format definition [$s]";
			}
		}else{
			push @$errs,"Format definition section [$s] does not exist";
		}
	}
	if (my $tif = $uini->val('main','template_is_format')){
		$ret->{flags}->{template_is_format}=$tif;
		$ret->{emails} = \@formats;
		$ret->{email_vals} = $format_vals;
		$used_sections->{main}++;
	}else{
		unless ($uini->SectionExists('emails')){
			$self->err("no Section '[emails]' in upload.ini");
			return undef;
		}
		$used_sections->{emails}++;
		my @emails = $uini->Parameters('emails');
		$ret->{emails} = \@emails;
		$ret->{email_vals}->{$_} = $uini->val('emails',$_) foreach @emails;
	}
	# Now check each email for a email reminder1 reminder2 section
	my $emails = $ret->{emails};
	my $fn2email = {};
	foreach my $email (@$emails){
		foreach my $type (qw (email reminder1 reminder2)){
			my $s = "$type-$email";
			if ($uini->SectionExists($s)){
				$used_sections->{$s}++;
				my $either = 0;
				foreach my $part (qw (plain html)){
					if (my $f = $uini->val($s,$part)){
						$either++;
						my $file = join '/',$troot,$SID,'etemplate',$f;
						if (-e $file){
							$ret->{email_files}->{$email}->{$type}->{$part} = $file;

						}else{
							push @$errs,"Email '$email' '$part' file $file does not exist";
						}
					}
				}
				if ($either == 0){
					push @$errs,"Neither html or plain part specified for '$s'";
				}
			}else{
				if ($type eq 'email'){
					push @$errs,"No email template definition section [$s] in upload.ini";
				}else{	
					push @$warns,"You missed a chance to define a [$s] section in upload.ini";
				}
			}
		}
	}
	foreach my $s ($uini->Sections){
		push @$warns,"Section '$s' is not used" unless $used_sections->{$s};
	}
	$ret->{warns} = $warns;
	$ret->{errs} = $errs;
	return $ret;
}

sub uploadini_filename {
	my $self = shift;
	my %args = @_;
	my $SID = $self->SID || confess("pass 'SID' to new()");
	my $troot = $self->troot || confess("pass 'troot' to new()");
	return join '/',$troot,$SID,'config','upload.ini';
}

sub uploadcsv_filename {
	my $self = shift;
	my %args = @_;
	my $SID = $self->SID || confess("pass 'SID' to new()");
	my $troot = $self->troot || confess("pass 'troot' to new()");
	return join '/',$troot,$SID,'config','upload_csv.ini';
}

sub uploadcsv_defaults {
	my $self = shift;
	# These are the default behaviours that are controlled in the upload_csv.ini file
	# If its not mentioned here, then you get an error if you try and use it
	return {
		# Do produce postcard files for people without email addresses.
		postcards=>1,

		# We expect to send emails out to people.  write an emails.xls, reject
		# people with blank emails, unless we are doing postcards.
		email=>1,

		# Combine the postcards.xls into the emails.xls file.  Makes the
		# 'postcards' param unnecessary
		one_file=>0,

		# reject duplicate emails in batch.
		unique_email=>0,

		# Allow .tsv files to uploaded.  This does not work currently.
		allow_tsv=>0,

		# Don't generate passwords.  Use the password field in the batch.
		pwd_in_upload=>0,

		# Can see preview of the email.
		preview=>0,

		# Can edit the emails files.
		edit=>0,
	};
}

sub parse_uploadcsv {
	my $self = shift;
	my %args = @_;
	my $inifn = delete ($args{file}) || confess ("No 'file' supplied");

	# List of 'vars' allowed in asp_mappings, not defined in [columns] or [asp_mapping]
	my $external_vars = delete($args{vars}) || [];

	confess "Unrecognised args:".Dumper(\%args) if keys %args;

	my $ini =  new Config::IniFiles(-file=>$inifn);
	unless ($ini){
		$self->err("Could not open '$inifn' as an ini file");
		return undef;
	}
	my $errs = [];
	my $warns = [];
	my $ret = {err=>$errs,warns=>$warns};

	my $def_switches = $self->uploadcsv_defaults;
	$ret->{switches}->{$_} = $def_switches->{$_} foreach keys %$def_switches;
	if ($ini->SectionExists('main')){
		foreach my $k ($ini->Parameters('main')){
			$ret->{switches}->{$k} = $ini->val('main',$k);
			push @$warns,"No default value for '$k'" unless 
				exists $def_switches->{$k}
		}
	}

	my $used_sections = {};

	unless ($ini->SectionExists('columns')){
		$self->err("No '[columns]' section in '$inifn'");
		return undef;
	}
	my $columns = [$ini->Parameters('columns')];
	$ret->{columns} = $columns;

	my $col_names = {};
	tie %$col_names,'TPerl::Hash';

	foreach my $col (@$columns){
		my $val = $ini->val('columns',$col);
		$val = $col if $val eq '';
		$col_names->{$col} = $val;
	}

	$ret->{column_names} = $col_names;
	
	my $fields = {};

	{
		my $mapping_names = [$ini->Parameters('asp_mapping')];
        my $map_errors = {};
        my $im = new TPerl::IniMapper();
        my $count = 0;
		my @allowed_headings = @$external_vars;
        push @allowed_headings,@$columns;
        foreach my $m_name (@$mapping_names){
            my $m = $ini->val('asp_mapping',$m_name);
            if (my $field = $im->mapping2field(mapping=>$m,headings=>\@allowed_headings,name=>$m_name)){
                $field->{order} = $count++;
                $fields->{uc($m_name)}=$field;
                push @allowed_headings,$m_name;
            }else{
                $map_errors->{$m_name} = $im->err;
            }
        }
        if (%$map_errors){
			# my $msg = "These [asp_mapping] maps had the following errors:<table>".
			# join ('',map (qq{<tr><td><b>$_</b></td><td> $map_errors->{$_}</td></tr>},keys %$map_errors)).
			# "</table>";
            $self->err($map_errors);
			return undef;
        }
	}
	$ret->{fields} = $fields;
	return $ret;
}

sub uploadcsv2data {
	my $self = shift;
	my %args = @_;
	
	# return a hash.  the keys are
	# - the renamed columns
	# - the names of the [asp_mappings]
	# - the things in the extra hash
	
	# you can either specify a pup (parsed_uploadcsv) or a file but not both.
	# if you specify a file, an lot of dummy data will be inserted. If not we
	# expect a row that has the same cols as the columns section, that you got
	# from reading a tsv file.
	
	my $extra = delete $args{extra} || {};
	my $file = delete $args{file};

	my $row = delete $args{row} || {};
	my $pup = delete $args{pup};

	# All these confessions are programmer help.  
	confess("Unrecognised args:".Dumper(\%args)) if keys %args;
	confess("you must send a 'file' or a 'pup'") unless $file || $pup;
	my $fill_return_with_dummy_data = 1;
	if ($pup){
		$fill_return_with_dummy_data=0;
		confess ("Can't call this with 'pup' and 'file'") if $file;
	}else{
		confess ("We ignore 'row' if 'file' is parsed") if keys %$row;
		$pup = $self->parse_uploadcsv(file=>$file,vars=>[keys %$extra]) 
			|| return undef;
	}

	# u is the data we return.
	# working is needed because the fields in the mappings are the NOT renamed columns.
	my $working = {};
	tie %$working,'TPerl::Hash';

	my $u = {};
	tie %$u,'TPerl::Hash';
	$working->{$_} = $extra->{$_} foreach keys %$extra;
	$u->{$_} = $extra->{$_} foreach keys %$extra;

    my $fields = $pup->{fields};
    my $cols = $pup->{columns};
	my $lookup = $pup->{column_names};

	# We put the data into the 'column' data in first.  mappings can redefine it
	if ($fill_return_with_dummy_data){
		$u->{$lookup->{$_}} = $_ foreach @$cols;
		$working->{$_} = $_ foreach @$cols;
	}else{
		$u->{$lookup->{$_}} = $row->{$_} foreach @$cols;
		$working->{$_} = $row->{$_} foreach @$cols;
	}

	my $ez = new TPerl::DBEasy;
	foreach my $field (sort {$fields->{$a}->{order} <=> $fields->{$b}->{order} } keys %$fields){
        $working->{$field} = $ez->field2val(row=>$working,field=>$fields->{$field},no_nbsp=>1);
        $u->{$field} = $working->{$field};
    }
	return $u;
}

sub check_uploadini {
	# This is really a crap bit of code.  Try and use 
	# parse_uploadini instead.
	
	# This is from upload_csv_file and process_csv 
	# it looks in an upload.ini and decides based on
	# the format and template and other flags what the
	# use the html_template and plain_template methods to get the results
	# 'fatal' errors cause return undef, use err to get reason.
	
	my $self = shift;

	my %ARGS = @_;
	my $e=$ARGS{err};
	my $args=$ARGS{args};

	my $SID=$self->SID;
	
	my $troot = getConfig('TritonRoot');

	$args->{inifile} = join '/',$troot,$SID,'config','upload_csv.ini';

	my $upinifile = join '/',$troot,$SID,'config','upload.ini';
	my $html_template = 'invite.html';
	my $plain_template = 'invite.txt';

	if (-f $upinifile){
		$e->I("Reading upload config file: $upinifile");
		my $uini = new Config::IniFiles (-file=>$upinifile);
		unless ($uini){
			$self->err("Could not open '$upinifile' as an ini file");
			return undef;
		}
		# Die unless [formats] section does not exist?

		# choose first format as default if $args->{format} not defined.
		unless ($args->{format}){
			$args->{format}=($uini->Parameters('formats'))[0];
			$e->I("Default to first format '$args->{format}'");
		}
		my $file = $uini->val("format-$args->{format}",'file');
		if ($file ne ''){
			$args->{inifile} = join '/',$troot,$SID,'config',$file;
		}else{
			$e->E("Missing 'file=' section or value in upload.ini: [format-$args->{format}]");
		}
		unless ($args->{template}){
			$args->{template}=($uini->Parameters('emails'))[0];
			$e->I("Default to first template '$args->{template}'");
		}
		my $template = $args->{template};
		if ($uini->val('main','template_is_format')){
			# ie there is a one to one relationship bw format and template, and we don;t want to confuse them with a choice.
			$args->{template}=$args->{format};
			$template=$args->{format};
		}
		$html_template = $uini->val("email-$template",'html');
		$e->E("Missing section or value in upload.ini: [email-$template]<BR>html=") if (($template ne '') && ($html_template eq ''));
		$e->I("html_template=$html_template");
		$plain_template = $uini->val("email-$template",'plain');
		$e->E("Missing section or value in upload.ini: [email-$template]<BR>plain=") if (($template ne '') && ($plain_template eq ''));
		$e->I("plain_template=$plain_template");
		foreach my $r (qw (reminder1 reminder2)){
			my $sec_name = "$r-$template";
			if ($uini->SectionExists($sec_name)){
				$args->{"${r}_plain"} = $uini->val($sec_name,'plain');
				$args->{"${r}_html"} = $uini->val($sec_name,'html');
			}else{
				$e->W("Missed your chance to specify a $r for template $template with a [$sec_name]");
			}
		}
	}
	foreach my $r (qw (reminder1 reminder2)){
		$args->{"${r}_plain"} ||= 'reminder-plain1';
		$args->{"${r}_html"} ||= 'reminder-html1';
		$e->I("${r}_plain=".$args->{"${r}_plain"});
		$e->I("${r}_html=".$args->{"${r}_html"});
	}
	$args->{html_template} ||= $html_template;
	$args->{plain_template} ||= $plain_template;
	my $f_h_temp = join '/',$troot,$SID,'etemplate',$html_template;
	unless (-f $f_h_temp){
		$self->err("html_template '$f_h_temp' does not exist");
		return undef
	}
	$self->html_template($html_template);
	$self->plain_template($plain_template);
	return 1;
}

sub next_id {
	my $self = shift;
	my $fn = shift;
	my $batchno;
	unless ($fn){
		$self->err("no id filename sent");
		return undef;
	}
	if (-e $fn){
        $batchno = read_file ($fn);
    }else{
        $batchno=100;
    }
    unless (overwrite_file ($fn,$batchno+1)){
		$self->err("Could not write batchno file '$fn'");
		return undef;
	}
	return $batchno
}

sub file_db_list {
	my $self=shift;
	my %args = @_;

	my $table = $args{table};
	my $tableid = $args{tableid} || 'BID';
	my $dir = $args{dir};
	my $dbh = $args{dbh} || $self->dbh();
	my $SID = $args{SID} || $self->SID || confess "We need a SID here";
	my $stat = $args{stat};

	my $stat_labs = {
		dev=>0,
		ino=>1,
		mode=>2,
		nlink=>3  ,
		uid=>  4 ,
		gid=>  5,
		rdev=>6,
		size=> 7  ,
		atime=> 8,
		mtime=>9,
		ctime=>10  ,
		blksize=>11,
		blocks=>12
	};


	foreach (qw(table dir )){
		confess "$_ is a required arg" unless $args{$_};
	}

	unless (-d $dir){
		$self->err("dir '$dir' is not a directory");
		return undef;
	}
	my $sql = "select * from $table where SID=?";
	my $res = $dbh->selectall_hashref($sql,$tableid,{},$SID);
	unless ($res){
		$self->err({sql=>$sql,dbh=>$dbh});
		return undef;
	}
	my $dh = new DirHandle ($dir);
	my $f;
	my $rows = [];
	while (defined ($f = $dh->read)){
		next if $f =~ /^\./;
		my $fn = "$dir/$f";
		my $row = {};
		$row->{file} = $f;
		$row->{filename} = $fn;
		my @stat = stat($fn);
		if ($stat){
			$row->{"stat_$_"} = $stat[$stat_labs->{$_}] foreach keys %$stat_labs;
		}
		$row->{human_size} = $self->human_size($stat[7]);
		my ($id) = $f =~ /(\d+)/;
		$row->{id} = $id;
		if (my $dbhash=$res->{$id}){
			$row->{$_} ||= $dbhash->{$_} foreach keys %$dbhash;
		}
		push @$rows,$row;
	}
	foreach my $bid (keys %$res){
		my $rec = $res->{$bid};
		$rec->{id} = $bid;
		push @$rows,$rec if $rec->{DELETE_EPOCH};
	}
	@$rows = sort {$b->{id} <=> $a->{id}} @$rows;
	return $rows;
}
sub file_db_fields {
	my $self = shift;
	my %args = @_;
	my $table = $args{table};
	my $dbh = $args{dbh} || $self->dbh();
#     my %custom_info = ();
	my $ez = new TPerl::DBEasy(dbh=>$dbh);
	my $fields = $ez->fields(table=>$table);
	$fields->{id} = {pretty=>'Id',name=>'id',order=>-10};
	$fields->{file} = {pretty=>'File',name=>'file'};
	$fields->{size} = {pretty=>'Size',name=>'human_size'};
	$fields->{UPLOAD_EPOCH}->{pretty} = 'Uploaded' if $fields->{UPLOAD_EPOCH};
	$fields->{DELETE_EPOCH}->{pretty} = 'Deleted' if $fields->{DELETE_EPOCH};
	$fields->{FILE_DATE}->{pretty} = 'Stats Page Date' if $fields->{FILE_DATE};
	$fields->{$_}->{cgi}->{func} = 'hidden' foreach qw (BID SID);
	return $fields;
}

sub js_getNewText {
	### This java script is good for editing a text field in a form.
	my $self = shift;
	my %args = @_;
	my $form_name = $args{form_name} || 'textform';
	my $new_title_name = $args{new_field_name} || '_NEW_TITLE';
	my $prompt = $args{prompt} || 'Please enter a new batch title';
	my $fn_name = $args{function_name} || 'getNewText';

	return qq{
        function $fn_name (bid) {
            var formName = '$form_name'+bid;
			//alert ("formname="+formName);
            var myform = document.all.item(formName);
            var oldText = myform.$new_title_name.value
            //alert (oldText);
            var r = prompt ("$prompt",oldText);
            if (r == undefined) return false;
            if (r == oldText) return false;
            // alert (r);
            myform.$new_title_name.value=r;
            return true;
        }
    };
}

sub field_getNewText {
	my $self = shift;
	my %args = @_;
	my $form_name = $args{form_name} || 'textform';
	my $new_title_name = $args{new_field_name} || '_NEW_TITLE';
	my $new_bid_name = $args{new_bid_name} || '_NEW_BID';
	my $fn_name = $args{function_name} || 'getNewText';
	my $SID = $args{SID};
	my $submit_value = $args{submit} || 'Edit';
	my $title_sub = $args{code_ref};

    my $title_code_ref = sub {
            my $title = shift;
            my $bid = shift;
            my $del = shift;
            my $q = new CGI('');
			$title = &$title_sub($title) if $title_sub;
            return undef unless $bid;
            return undef unless $del eq '';
            return join "\n",
                # $q->image_button(-name=>'edit',-src=>'http://www.triton-tech.com/pix/edit.gif',-alt=>'Edit Batch Name',-onclick=>"$fn_name($bid)"),
                $q->start_form(-action=>"$ENV{SCRIPT_NAME}$ENV{PATH_INFO}",-method=>'POST',-name=>"$form_name$bid",-onSubmit=>"return $fn_name($bid)"),
                $q->hidden(-name=>$new_bid_name,-value=>$bid),
                $q->hidden(-name=>'SID',-value=>$SID),
                $q->hidden(-name=>$new_title_name,-value=>$title),
                # $q->textfield(-class=>'input',-name=>$new_title_name,-value=>$title,-size=>50,-maxlength=>100),
                $q->submit(-class=>'input',-name=>'submit',-value=>$submit_value),
                $q->end_form;
    };
	return $title_code_ref;


}

sub field_deleteBatch {
	my $self = shift;
	my %args = @_;
	my $SID = $args{SID};
	my $del_form_name = $args{del_form_name};
	my $submit_value = $args{submit_value} || 'Del';
	my $del_field_name = $args{del_field_name} || '_delete';

	my $code_ref = sub{
		my $id = shift;
		my $file = shift;
		my $title = shift ;
		my $del = shift;
		my $bid = shift;
		my $prompt = "Delete $title ($file:$id)?\\nThis cannot be undone";
		return undef unless $id;
		return undef if $title && $del;
		my $q = new CGI ('');
		return join "\n",
			$q->start_form(-action=>"$ENV{SCRIPT_NAME}$ENV{PATH_INFO}",-method=>'POST',-name=>"$del_form_name$id",-onSubmit=>"return confirm('$prompt')"),
			$q->hidden(-name=>'SID',-value=>$SID),
			$q->hidden(-name=>$del_field_name,-value=>$file),
			$q->hidden(-name=>'BID',-value=>$bid),
			$q->submit(-class=>'input',-name=>'submit',-value=>$submit_value),
			$q->end_form;

	};
	return $code_ref;
	
}

sub human_size {
	my $self = shift;
    my $num = shift;
    my $dec = shift || 1;
    my $thousand = 1024;
    my $labels = {0=>'',1=>'K',2=>'M',3=>'G',4=>'T'};

    my $order = 1;
    my $ans = $num;
    while (1){
        my $div = $thousand ** $order;
        if ($num < $div){
            return "$ans$labels->{$order-1}";
        }
        $ans = sprintf ('%2.2f',$num / $div);
        return "$ans$labels->{$order}" unless $labels->{$order};
        $order++;
    }

}

sub touch_file_from_table {
	my $self = shift;
	my %args = @_;
	my $table = $args{table};
	my $id = $args{id};
	my $table_id = $args{table_id} || 'BID';
	my $filefield = $args{file_field};
	my $epochfield = $args{epoch_field};
	my $dbh = $args{dbh} || $self->dbh();

	foreach (qw(table id file_field epoch_field )){
		confess "$_ is a required arg" unless $args{$_};
	}

	my $sql = "select * from $table where $table_id = ?";
	if (my $rs = $dbh->selectall_arrayref($sql,{Slice=>{}},$id)){
		if (my $r = $rs->[0]){
			return $self->touch_file(file=>$r->{$filefield},epoch=>$r->{$epochfield});
		}else{
			$self->err("Could not get a record from $table with $table_id=$id");
			return undef;
		}
	}else{
		$self->err({sql=>$sql,params=>[$id],dbh=>dbh});
		return undef;
	}
}
sub touch_file {
	my $self = shift;
	my %args = @_;
	my $file = $args{file};
	my $epoch = $args{epoch};
	foreach (qw(file epoch )){
		confess "$_ is a required arg" unless $args{$_};
	}
	unless (-e $file){
		$self->err("File '$file' does not exist");
		return undef;
	}
	my $toucher = new File::Touch(time=>$epoch);
	if (my $ret = $toucher->touch($file)){
		return $ret;
	}else{
		$self->err("Could not touch '$file' with '$epoch' seconds:$!:");
		return undef;
	}
}

# Where we store the uploaded args in an ini file
sub packet_dir {
	my $self = shift;
	my $troot = $self->troot || confess ("No 'troot' supplied");
	my $SID = $self->SID || confess ("No SID supplied");
	return join '/',$troot,$SID,'binfo';
}

# Where we store incoming files.
sub incoming_dir {
	my $self = shift;
	my $troot = $self->troot || confess ("No 'troot' supplied");
	my $SID = $self->SID || confess ("No SID supplied");
	return join '/',$troot,$SID,'incdir';
}

sub filtered_dir {
	my $self = shift;
	my $troot = $self->troot || confess ("No 'troot' supplied");
	my $SID = $self->SID || confess ("No SID supplied");
	return join '/',$troot,$SID,'filtered';
}

sub batchnofile {
	my $self = shift;
	my $troot = $self->troot || confess ("No 'troot' supplied");
	my $SID = $self->SID || confess ("No SID supplied");
	return join '/',$troot,$SID,'config','batchno.txt';
}

sub next_batchno {
	my $self = shift;
	my $batchnofile = $self->batchnofile();
	return $self->next_id($batchnofile);
}


1;
