#$Id: DBEasy.pm,v 1.113 2011-10-13 21:51:04 triton Exp $
package TPerl::DBEasy;
use strict;
use Carp qw(confess);
use Data::Dumper;
use DBI;
use Date::Manip;
use CGI;
use Time::Local;
use TPerl::LookFeel;
use TPerl::CGI;
use TPerl::Error;
use FileHandle;

use vars qw ($VERSION);
$VERSION = sprintf "%d.%d", q$Revision: 1.113 $ =~ /: (\d+)\.(\d+)/;


=head1 SYNOPSIS

Writing database forms should be easy.  Hopefully this helps.

 my $ez = new TPerl::DBEasy;

=head1 DESCRIPTION

The fields hash is the central piece of this module. It holds a summary of info
from the database like NULLABLE TYPE, SIZE etc  (see the DBI manpage) and a few perl like  extensions.
We use the fields hash for drawing form elements, validating data, and lots of
other stuff.

There may be information that you know that the database does not.
Say you may have an integer field called EPOCH to hold some epoch seconds, 
a FLAG field that holds 1 for yes and 0 for no,
and a ID field whose values should not be edited, but should show up 
as a <input type="hidden"/> on a form.
It should be easy to put this info into the fields hash.

 my %custom_info = ();
 $custom_info{EPOCH} = $ez->field (type=>'epoch');
 $custom_info{FLAG} = $ez->field (type=>'yesno');
 $custom_info{ID} = $ez->field (type=>'hidden');

Now get the fields hash.  What follows assumes you are editing a table called
GOOSE with the fields above (and possibly some others).  Calling fields this way
means one (extra) database hit.  It collects info from an executed DBI::sth
object.  If you happen to have one of these lying around (How are you getting
the data to edit?), pass it in as a sth=>$sth parameter.

 # get a DBI::dbh from somewhere.
 my $dbh = dbh TPerl::MyDB (db=>'ib');  
 my $fields = $ez->fields(table=>'GOOSE',	
 	dbh=>$dbh,%custom_info);

Get the values to edit

 my $row = $sth->fetchrow_hashref;
 # or if you are making a new entry 
 my $row = {ID=>23,EPOCH=>12342321,FLAG=>1,
 	CRAP=>23,NAME=>'andrew'};

Now get the form text.  Marry the info about the database, with info from the database, some calls to CGI.pm funcions.

 my $form = $dbh->form(row=>$row,fields=>$fields);

Once $form is submitted, there should be some params coming back in 
to your web page.  The keys are (uc) fields names.  Collect these some how. 
(very easy in HTML::Mason), also very easy in TPerl::CGI->args();

 my %params = (key,value,key,value......);

You wanna see if you can insert or update the table

 my $err = $ez->row_manip(action=>'update',fields=>$fields,
 	dbh=>$dbh,table=>'GOOSE',vals=>\%params,keys=>['ID']);

 if ($err->{validate}){
 	# validation failed.  get the form again, 
	# this time an extra column for errors
	print "<h2>Please fix these errors</h2>");
	print $ez->form(row=>\%params,dbh=>$dbh,
		fields=>$fields,valid=>$err->{validate});
 }elsif ($err) {
 	# validation succeeded, 
	# but some other database error ocurred
	print Dumper $err;
 }else{
 	# success
 }

=head1 Fields hash customisation.

customising the calls to the CGI methods.

 $fields->{BATCHNO}->{cgi}->{func}='popup_menu';
 $fields->{BATCHNO}->{cgi}->{args}={-default=>'',-values=>[0,1,2],-labels=>{0=>'BATCH 0',2=>'BATCH 2'};

each time an element is displayed, use sprintf to and values from the row.

 $fields->{PWD}->{sprintf}={
 	fmt=>qq{<a target="right2" href="$ENV{SCRIPT_NAME}/right2?SID=$SID&PWD=%s">%s</a>},
	names=>[qw(PWD PWD)]
	};

make an anonymous sub routine ref to get executed for each row.  Other values
from the row can be passed to this.

 my $code_ref = sub {
	my $def = shift;
	my $pwd = shift;
	my $q = new CGI ('');
	my $val= join "\n",
			$q->start_form(-action=>"$ENV{SCRIPT_NAME}/right1"),
			$q->popup_menu(-name=>'NEW_STAT',-values=>[0,1,2,3,4,5,6],-labels=>$stat_labels,-default=>$def),
			$q->hidden(-name=>'NEW_PWD',-default=>$pwd),
			$q->submit(-name=>'submit',-value=>'Save');
	$val .= $q->hidden(-name=>$_,-default=>$state->{$_})."\n" foreach keys %$state;
	$val .= $q->end_form;
	return $val;
 }
 $fields->{STAT}->{code}={ref=>$code_ref,names=>[qw(STAT PWD)]};

You can get values for a field from some SQL also.  The first to entries in
each row returned are used as the key value pairs in the cgi calls.

 $fields->{UID}->{value_sql}={sql=>'select VALUE,LABEL from some_table where X=? and Y=?',params=>[PWD,STATUS]};
				  

=head1 Method documentation

=head2 new

Using the dbh param it initialisation saves having to pass it to each
successive call

 my $ez = new TPerl::DBEasy (dbh=>$dbh);

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	my %args = @_;
	$self->{dbh} = $args{dbh} if $args{dbh};
	bless $self,$class;
	return $self;
}

sub sort_fields {
	my $self = shift;
	my $fields = shift;
	return sort {$fields->{$a}->{order} <=> $fields->{$b}->{order}} keys %$fields;
}

sub dbh {
    my $self = shift;
    return $self->{dbh} if $self->{dbh};
    $self->err("No dbh supplied");
    return;
}

sub params { my $self = shift; $self->{params} = $_[0] if @_; return $self->{params}; }
sub sql { my $self = shift; $self->{sql} = $_[0] if @_; return $self->{sql}; }
sub vals { my $self = shift; $self->{vals} = $_[0] if @_; return $self->{vals}; }
sub err {
    my $self = shift;
    my $err = $_[0];
    if (ref ($self)){
        return $self->{err} = $err if @_;
        return $self->{err};
    }elsif ($err){
        confess TPerl::Error->fmterr($err);
    }else{
        # Do nuthing.  sometimes we call err with '' just to reset it.
        # in TPerl::DoNotSend->exists() for instance.
    }
}


# This is messy.  At least we keep the messy stuff in one place.
# the windows DBI version is old.
sub sa_ar_slice {
	my $self = shift;
	my $attr = {Slice=>{}}; 
	$attr = {dbi_fetchall_arrayref_attr=>{}} if $DBI::VERSION eq '1.14';
	return $attr;
}

sub row2fields {
	my $self = shift;
	my $row = shift;
	my $fields = {};
	$fields->{$_} = {name=>$_} foreach keys %$row;
	foreach my $n (keys %$fields) {
		$fields->{$n}->{pretty} = $self->name2pretty($n) 
	}
	return $fields;
}

=head2 lister

This lists records from a database formatted in HTML.  In its
most basic form, it makes a table with one row for each row in the database.
With a little imagination and a funky fields hash, you can turn it into a nifty
DB editing tool.

 # Have to use one form to keep buttons in a line
 # so the text of the buttons is important.
 my $page = $args{next} if $args{submit} =~ /next/i;
 $page = $args{previous} if $args{submit} =~ /prev/i;
 $page = $args{page} if $args{submit} =~ /go/i;
 my $l = $ez->lister(sql=>$sql,page=>$page,form=>1,limit=>10);

Other options include

 look=>TPerl::LookFeel->new();
 limit=>$row_per_page,
 page=>$which_page_do_we_want,

You may need to send your paging form some more information.

 form=$do_a_next_previous_form,
 action=>'http://somewhere.else.com/page', # $ENV{SCRIPT_NAME} is the default.
 method=>'GET', # POST is the default
 form_hidden=>{state_var_name1=>'state_var_value1',state_var_name2=>'state_var_value2'}, # No default values
 target=>'frame_name', # no default.

=cut

sub lister_wrap {
	my $self = shift;
	my %args = @_;

	my $no_data = $args{_no_data} || 'No Data';
	my $row_count_sprintf = $args{_row_count} || "%s rows";
	my $page_args = delete $args{_page_args} || \%args;
	my $state = delete $args{_state} || [];
	my $b4html = delete $args{_b4html};
	my $afhtml = delete $args{_afhtml};

	my $page = $args{page};
	$page = $page_args->{next} if $page_args->{submit} =~ /next/i;
	$page = $page_args->{previous} if $page_args->{submit} =~ /prev/i;
	$page = $page_args->{page} if $page_args->{submit} =~ /go/i;
	$page = $page->[0] if ref ($page) eq 'ARRAY';

	$args{page} = $page;# unless exists $args{page};
	# use Carp qw(confess);confess (Dumper $state);
	$args{form_hidden}->{$_}=$page_args->{$_} foreach @$state;

	my $lister = $self->lister(%args);
	# return Dumper $lister;
	if ($lister->{err}){
		$self->err($lister);
		return undef;
	}elsif ($lister->{count}){
		my $res = sprintf ($row_count_sprintf,$lister->{count});
		$res .= $b4html;
		$res .= join "\n",@{$lister->{html}};
		$res .= $afhtml;
		$res .= join "\n",@{$lister->{form}} if $args{form};
		return $res;
	}else{
		return $no_data;
	}
}
sub lister {
	my $self = shift;
	my %args = @_;
	my $sql = $args{sql};
	my $dbh = $args{dbh};
	my $fields = $args{fields};
	my $custom_info = $args{custom_info} || {};
	my $params = $args{params} || [];
	my $sth = $args{sth};
	my $limit= $args{limit};
	$limit = shift @$limit if ref($limit) eq 'ARRAY';
	$limit ||= 200;
	my $page = $args{page} || 1;
	my $lf = $args{look};
	my $rows = $args{rows}||[];
	my $get_fields = $args{get_fields};

	$page = 1 if $page<1;
	$limit = abs($limit);

	# and some args for the form
	my $action = $args{action};
	my $target = $args{target};
	my $form = $args{form};
	my $form_hidden = $args{form_hidden} || {};
	my $form_name = $args{form_name} || 'lister';


	my $head_in_trow = $args{heads_in_trow};

	my $list_in_form = 1 if $form ==2;
	my $start_form = undef;


	

	my @html = ();
	my $count = undef;
	my $disp = undef;

	$self->value_sql2labels(field=>$_) foreach values %$fields;

	# now we want to be able to pass in an array of hashes instead of getting them 
	# from the database.
	my $rows_idx = 0;


	if ($sql){
		$dbh ||= $self->dbh;
		return {err=>'No dbh supplied supplied to lister()'} unless $dbh;
		if ($sth = $dbh->prepare($sql)){
			if ($sth->execute (@$params) ){
			}else{
				return {err=>$dbh->errstr,sql=>$sql,params=>$params};
			}
		}else{
			return {err=>$dbh->errstr,sql=>$sql };
		}
	}
	$fields = $self->fields (sth=>$sth,%$custom_info) if $sth and ! keys %$fields;
	confess ("'rows' parameter must be an array ref") if $rows and ref($rows) ne 'ARRAY';
	$fields = $self->row2fields ($rows->[0]) if @$rows and ! keys %$fields;
	my @f = $self->sort_fields($fields);

	if ($form){	
		my $q = new CGI ('');
		my %sfargs = ();
		$sfargs{-action} = $action if $action;
		$sfargs{-target} = $target if $target;
		$sfargs{-name} = $form_name if $form_name;
		$start_form = $q->start_form(%sfargs);
	}

	while (1){
		my $row = undef;
		if ($sth){
			$row = $sth->fetchrow_hashref();
			die Dumper {sql=>$sql,err=>$DBI::err,errstr=>$DBI::errstr,count=>$count,fields=>$fields} if $DBI::err;
		}else{
			$row = $rows->[$rows_idx++];
		}
		last unless defined $row;
		$count++;
		if ($count ==1){
			push @html,$start_form if $list_in_form;
			my @head = map $fields->{$_}->{pretty},
				grep $fields->{$_}->{cgi}->{func} ne 'hidden',@f;
			# push @html,"in lister limit=$limit page=$page sql=$sql";
			if ($lf){
				$lf->{_last_row}=2;
				my $save_width = $lf->twidth;
				unless ($save_width){
					# If you want 100% set it in the lf b4 you call this.
					# this might break the look of a few things, but you'll get over it.
					# $lf->twidth('100%');
				}
				if ($head_in_trow){
					push @html, $lf->st,$lf->trow(\@head);
				}else{
					push @html, $lf->stbox(\@head);
				}
				$lf->twidth($save_width) if $save_width;
			}else{
				push @html,qq{<TABLE BORDER="1"><TR>};
				push @html, map qq{\t<TH>$_</TH>},@head;
				push @html,'</TR>';
			}
		}
		if ($count > ($page-1)*$limit && $count <= $page*$limit){
			$disp++;
			if ($lf){
				### Put hidden fields into the html, if they are form fields.  
				push @html,map $self->field2val(dbh=>$dbh,field=>$fields->{$_},row=>$row),
					grep $fields->{$_}->{form} && ($fields->{$_}->{cgi}->{func} eq 'hidden'),@f;

				### Put non hidden feilds onto form.
				my @vals = map $self->field2val(dbh=>$dbh,field=>$fields->{$_},row=>$row),
					grep $fields->{$_}->{cgi}->{func} ne 'hidden',@f;
				push @html,$lf->trow (\@vals);
			}else{
				push @html,'<TR>';
				foreach (@f){
					my $field = $fields->{$_};
					next if $field->{cgi}->{func} eq 'hidden';
					push @html, "\t<TD>".$self->field2val(dbh=>$dbh,field=>$field,row=>$row).'</TD>';
				}
				push @html,'</TR>';
			}
		}
			# 	push @html,"<TR><TD>count=$count</td></tr>";
	}
	if ($count){
		if ($lf){
			push @html,$lf->etbox;
		}else{
			push @html,'</TABLE>';
		}
	}
	$count ||='0';
	$disp ||=0;
	my $ret = {count=>$count,html=>\@html};
	$ret->{pages} = int($count /$limit)+1 ;
	$ret->{pages} -=1 if $ret->{pages} and ! ($count % $limit);
	$page = $ret->{pages}+1 if $page>$ret->{pages};
	$ret->{previous} = $page-1 if $count && $page>1;
	$ret->{next} = $page+1 if $count && $count > $page*$limit;
	$ret->{display} = $disp;
	if ($form){
		my $q = new CGI ('');
		my @form = ('<TABLE><TR><TD>');
		push @form,$start_form unless $list_in_form;
		if (my $previous = $ret->{previous}){
			push @form, 
				$q->submit(-name=>'submit',-value=>"Previous",-class=>'small'),
				$q->hidden(-name=>'previous',-value=>$previous),
		}
		if ($ret->{pages}>1){
			my $pages = $ret->{pages};
			push @form,'Page ',
				$q->textfield(-size=>length($pages),-maxlength=>length($pages),-value=>$page,-name=>'page',class=>'small'),
				" of $pages ",
				$q->submit(-name=>'submit',-value=>"Go",-class=>'small');
		}else{
			if ($list_in_form){
				push @form,$q->submit(-value=>'Go');
			}
		}
		if (my $next = $ret->{next}){
			push @form, 
				$q->submit(-name=>'submit',-value=>"Next",-class=>'small'),
				$q->hidden(-name=>'next',-value=>$next),
		}
		if ($count){
			push @form,
				'Display:',
				$q->textfield(-size=>length($limit),-value=>$limit,-class=>'small',-name=>'limit');
			delete $form_hidden->{limit};
		}
		foreach my $key (keys %$form_hidden){
			if (ref $form_hidden->{$key} eq 'ARRAY'){
				foreach (@{$form_hidden->{$key}}){
					push @form,$q->hidden(-name=>$key,-value=>$_);
				}
			}else{
				push @form,$q->hidden(-name=>$key,-value=>$form_hidden->{$key});
			}
		}
		push @form ,$q->endform,'</TD></TR></TABLE>';
		$ret->{form} = \@form;
	}
	return $ret;
}

=head2 form

Here are the args to pass to the form() method.

 print $ez->form(
 	### One of these two are required.
   fields->$ez->fields(), 
   table=>$table_name,

   row=>{TB_FIELD_NAME1=>TB_FIELD_VAL1,...},
   valid=>'see DESCRIPTION above',
   
   # passed to CGI->start_form
   action=>$action, 
   target=>$target,
   method=>$method,
   name=>$name,

	#these are special state vars.
   new=>$new,	
   edit=>$edit, 

   # Need some hidden fields in your form
   stat_vars=>{key=>val,key=>val....},

   # formatting
   border=>1,  #pixels
   heading=>'My Form',
   compact=>1	# use BR instead of a table.
   button_val=>'Search',  # defaults to 'Make Changes' or 'Create' if new is set.
   order=>[qw(Field names in order)],

=cut

sub form {
	my $self = shift;
	my %args = @_;
	my $fields = $args{fields};
	my $row = $args{row};
	my $valid = $args{valid};
	my $dbh=$args{dbh} || $self->dbh;
	my $script_name = $ENV{SCRIPT_NAME};
	my $path_info;
	if ($ENV{PATH_INFO}) {
		$path_info = $ENV{PATH_INFO};
	} else {
		$path_info = "";
	}
	my $action;
	$action = $args{action} || $script_name . $path_info;
	my $target = $args{target} || '_self';
	my $method = $args{method} || 'POST';
	my $name = $args{name} ||'form';
	my $border = $args{border} || '0';
	my $heading = $args{heading};
	my $table = $args{table};
	my $state_vars = $args{state_vars};
	my $compact = $args{compact};
	my $button_val = $args{button_val};
	my $twidth = $args{twidth};
	
	$button_val = $args{new}?'Create':'Make Changes' unless $button_val;

	# use order to specify form order, or to limit the fields displayed
	my $order = $args{order} ||[];

	### edit table and new are also valid args

	$fields ||= $self->fields(table=>$table) if $table;
	confess "fields or table are required fields" unless $fields;
	# programmer help
	foreach (qw(row )){
		confess "$_ is a reqired param" unless $args{$_};
	}

	unless (@$order){
		push @$order,$_ foreach (sort {$fields->{$a}->{order} <=> $fields->{$b}->{order}} keys %$fields)
	}

	my @html = ();
	my $q = new CGI ('');
	my $onsubmit = join ";\n",grep $_, map $fields->{$_}->{js},@$order;
	my $form_args = {-action=>$action,-name=>$name,-method=>$method,target=>$target};
	$form_args->{-onSubmit} = $onsubmit if $onsubmit;
	push @html ,$q->startform(%$form_args);
	foreach (qw(edit new table)){
		push @html,$q->hidden(-name=>$_,-value=>$args{$_}) if exists $args{$_}
	}
	my $wid;
	if ($twidth) {
		$wid = qq{width="$twidth"};
	} else {
		$wid = "";
	}
	my $bor;
	if ($border) {
		$bor = qq{BORDER="$border"};
	}else { 
		$bor = "";
	}
	push @html, qq{<TABLE CELLSPACING="0" CELLPADDING="5" $bor $wid class="mytable">};
	push @html, qq{<TR class="heading"><TD colspan="3" align="center">$heading</TD></TR>} if $heading;
	push @html, qq{<TR class="options"><TD colspan="3">} if $compact;
	foreach my $key (@$order){
		my $f = $fields->{$key};
		my $do_tr = 1;
		if ($f->{cgi}->{func}) {
			if ($f->{cgi}->{func} eq 'hidden') {
				$do_tr = "";
			}
		}
		my $f2val = $self->field2val (dbh=>$dbh,field=>$f,row=>$row,form=>1,compact=>$compact);
		my $err;
		$err = join "\n<BR>",map $_->{msg},@{$valid->{err}->{$key}} if $valid;
		$err ||='&nbsp;' if $ENV{SERVER_SOFTWARE};
		if ($do_tr){
			if ($compact){
				push @html,qq{$f->{pretty}:<BR>$f2val<BR>};
			}else{
				push @html,qq{<TR class="options"><TD>$f->{pretty}</TD><TD>};
				push @html,$f2val;
				push @html,qq{</TD><TD>$err} if $err;
				push @html,qq{</TD></TR>} 
			}
		}else{
			push @html,$f2val;
		}
	}
	push @html,qq{</TD></TR>} if $compact;
	my $state = undef;
	if ($state_vars){
		my $states = [];
		foreach my $st(keys %$state_vars){
			next if grep $_ eq $st , qw(new edit delete table);
			push @$states, $st unless $fields->{$st};
		}
		$state = join "\n",map $q->hidden(-name=>$_,-default=>$state_vars->{$_}),@$states;
	}

	push @html,
		$state,
		'<TR class="options"><TD COLSPAN="3">',
		$q->submit(-name=>'submit',-value=>$button_val),
		'</TD></TR>',
		'</TABLE>',
		$q->endform;
	my $htmlOut;
	foreach my $line(@html) {
		if ($line) {
			if ($line ne "") {
				$line .= "\n";
				$htmlOut .= $line;
			}
		}
	}
	if ($htmlOut) {
		return $htmlOut;
	} else {
		return;
	}
}

sub next_ids {
    my $self     = shift;
    my %args     = @_;
    my $dbh      = delete $args{dbh} || $self->dbh;
    my $keys     = delete $args{keys};
    my $table    = delete $args{table};
    my $only_one = delete $args{only_one};

    # programmer help
    confess( 'Unrecognised args:' . Dumper \%args ) if %args;
    confess("No dbh supplied") unless $dbh;
    confess("'keys' is a required arg") unless $keys;
    confess("'table' is a required arg") unless $table;

    $keys = $keys->{$table} if ref($keys) eq 'HASH';

    #### mysql barfs at the space in 'max (goose)'
    my @max = map " MAX($_) ", @$keys;

    my $sql = 'select ' . join( ',', @max ) . "from $table";
    if ( my $res = $dbh->selectall_arrayref($sql) ) {
        # print Dumper $res;
        my $row = $res->[0];
        $_ = $_ + 1 foreach (@$row);
        return $row->[0] if $only_one && @$row == 1;
        return $row;
    } else {
        ### check your dbh
        my $keysss = join ' ', @$keys;
        $self->err( "Error trying to get next_id for columns '$keysss' with sql '$sql' "
          . $dbh->errstr);
        return undef;
    }
}

##The e2t and t2e are the same as the epoch2text and text2epoch, except the don;t expect the self thing as first parameter.
sub e2t {
	my $ep = shift;
	my $format = shift;
	$format ||= "%l";
	return undef unless defined $ep;
	return undef if $ep eq '';
	my @t= localtime ($ep);
	return $ep unless $ep eq timelocal(@t);
	my $text = sprintf ("%4d%02d%02d%02d:%02d:%02d",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);
	return UnixDate ($text,$format);
}
sub t2e {
	my $t = shift; 
	return undef unless $t;
	local $SIG{__DIE__} = sub {};
	die "Cannot understand date '$t'\n" unless 
	my $now = ParseDate($t);
	my ($y,$mon,$d,$h,$min,$s) = $now=~ /(\d{4})(\d{2})(\d{2})(\d{2}):(\d{2}):(\d{2})/;
	my $epoch = timelocal($s,$min,$h,$d,$mon-1,$y-1900);
	return $epoch;
}

sub epoch2text {
	my $self = shift;
	my $ep = shift;
	my $format = shift;
	$format ||= "%l";
	return undef unless defined $ep;
	return undef if $ep eq '';
	my @t= localtime ($ep);
	return $ep unless $ep eq timelocal(@t);
	my $text = sprintf ("%4d%02d%02d%02d:%02d:%02d",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);
	return UnixDate ($text,$format);
}
sub text2epoch {
	my $self = shift;
	my $t = shift; 
	return undef unless $t;
	local $SIG{__DIE__} = sub {};
	die "Cannot understand date '$t'\n" unless 
	my $now = ParseDate($t);
	my ($y,$mon,$d,$h,$min,$s) = $now=~ /(\d{4})(\d{2})(\d{2})(\d{2}):(\d{2}):(\d{2})/;
	my $epoch = timelocal($s,$min,$h,$d,$mon-1,$y-1900);
	return $epoch;
}

#### Now we have fields with _interval that are like _epoch
#we need to have i2e and e2i to translate intervals to and from epochs

sub i2e {
	my $i = shift;
	return undef if $i eq '';
	local $SIG{__DIE__} = sub {};
	die "Cannot understand interval '$i'\n" unless
		my $e = ParseDateDelta($i);
	# print "parsed '$i'=$e\n";
	my $aval = Delta_Format($e,'approx',0,'%sh');
	if (my ($last_num) = $aval =~ /\s(\d+)$/){
		return 0 if $last_num eq '0' and $e eq '+0:0:0:0:0:0:0';
		die "Could not turn '$i' into seconds.  Try using a number of WEEKS instead of YEARS and MONTHS.  (Detail here it works from the command line. Parsed '$i' into interval '$e', but Delta_Format($e,'approx',0,'%sh') returns '$aval' which we try to fix to be '$last_num')\n" if $last_num eq '0' ;
		return $last_num;
	}
	return $aval;
}
sub e2i {
	my $e = shift;
	return undef if $e eq '';
	my $parsed = ParseDateDelta ("$e seconds");
	# return $parsed;
    my @parts = qw(y M w d h m s);
    my %labels = (
        y=>'year',
        M=>'month',
        w=>'week',
        d=>'day',
        h=>'hour',
        m=>'minute',
        s=>'second',
    );
    my @fmts = map "\%${_}v",@parts;
    my @bits = Delta_Format($parsed,'approx',0,@fmts);
	# print "Content-Type: text/plain\n\n".Dumper \@bits;
	if (@bits ==1){
		return undef;
	}
	shift @bits if @bits >7;
    my @out = ();
    foreach my $part (@parts){
        my $bit = shift @bits;
        my $plural ='s' unless $bit eq '1' or $bit eq '-1';
        push @out, "$bit $labels{$part}$plural" if $bit ne '0';
    }
	my $val = join ' ',@out;
	return '0 days' if $val eq '';
    return $val;
}

# Now we also have 

sub date2iso {
	my $self = shift;
    my $date = shift;
    my $us_date=shift;
    my @n = split /[^\d]/,$date;
	unless (@n==3){
		$self->err("Could not parse '$date'");
		return undef;
	}
    if ($us_date){
        return "$n[2]-$n[0]-$n[1]";
    }else{
        return "$n[2]-$n[1]-$n[0]";
    }
}


sub field {
	my $self = shift;
	my %args = @_;

	my $type=$args{type};
	if ($type eq 'yesno'){
		return {
          'cgi' => { 'args' => {
                                 '-values' => [ 0, 1 ],
                                 '-labels' => { '0' => 'No', '1' => 'Yes' }
                               },
                     'func' => 'popup_menu'
                   }
				};
	}elsif ($type eq 'hidden'){
		return { cgi=>{func=>'hidden'} };
	}elsif ($type eq 'epoch'){
		my $text2epoch = sub {
			my $t = shift; 
			return undef unless $t;
			local $SIG{__DIE__} = sub {};
			die "Cannot understand date '$t'\n" unless 
			my $now = ParseDate($t);
			my ($y,$mon,$d,$h,$min,$s) = $now=~ /(\d{4})(\d{2})(\d{2})(\d{2}):(\d{2}):(\d{2})/;
			my $epoch = timelocal($s,$min,$h,$d,$mon-1,$y-1900);
			return $epoch;

		};
		my $epoch2txt = sub	{
			my $ep = shift;
			my $format = shift;
			$format ||= "%l";
			return undef unless defined $ep;
			return undef if $ep eq '';
			my @t= localtime ($ep);
			return $ep unless $ep eq timelocal(@t);
			my $text = sprintf ("%4d%02d%02d%02d:%02d:%02d",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);
			return UnixDate ($text,$format);
		};
		return {
			code=>{ref=>$epoch2txt},
			pre_validate=>{ref=>$text2epoch},
		};
	}else{
		return {};
	}
}
sub name2pretty {
	my $self = shift;
	my $name = shift;
	
	$name =~ s/EPOCH$/TIME/;
	$name =~ s/_FLAG$//;
	my @words = split /_/,$name;
	my $pretty =join (' ',map ucfirst(lc($_)),@words);
	return $pretty;
}

sub fields {
	my $self = shift;
	my %args = @_;

	my $sth = $args{sth};
	my $table = $args{table};
	my $dbh = $args{dbh} || $self->dbh;
	# my $get_dbi = $args{dbi_info};
	my $get_dbi = 1;

	confess "'fields needs 'table' or 'sth' parameters set" unless $table || $sth;

	my @dbi_words = qw (TYPE PRECISION SCALE NULLABLE );
	my $dbi_info = {};
	my %fields = ();
	my @names = ();
	if ($sth){
		@names = @{$sth->{NAME_uc}};
	}
	my $need_sth_finnish=0;
	if ($table && !$sth){
		confess "'fields' need a dbh" unless $dbh;
		# confess "dbh '$dbh' is not a DBI::db" unless ref $dbh eq 'DBI::db'; # or Apache::DBI::db
		my $sql = "select * from $table";
		$sth = $dbh->prepare ($sql) or die Dumper {sql=>$sql,err=>$dbh->errstr};
		$sth->execute or die Dumper {sql=>$sql,err=>$dbh->errstr};
		@names = @{$sth->{NAME}};
		# print "here ".dumper \@names;
		# print "<br>here ".dumper $sth->{type};
		$need_sth_finnish = 1;
		# $sth->finish;
	}
	# need to get save these arrays away so we can call finninsh if we started the sth.
	if ($get_dbi){
		$dbi_info->{$_} = $sth->{$_} foreach @dbi_words;
	}
	# print "\n<BR>DBI_INFO ".Dumper $dbi_info;
	my $dbi_info_index = 0;
	foreach my $key (keys %args){
		next unless uc($key) eq $key;
		push @names, $key unless grep $_ eq $key,@names;
	}
	$sth->finish if $need_sth_finnish;
	foreach my $name (@names){
		my %hsh = ();
		if ($get_dbi){
			$hsh{DBI}->{$_} = $dbi_info->{$_}->[$dbi_info_index] foreach @dbi_words;
		}
		$hsh{name} = $name;
		foreach my $th (qw(pretty code sprintf cgi pre_validate)){
			if (exists $args{$name}){
				$hsh{$th} = $args{$name}->{$th} if exists $args{$name}->{$th};
			}
		}
		$hsh{pretty} = $self->name2pretty($name) unless exists $hsh{pretty};
		$hsh{order} = $dbi_info_index;
		$fields{$name} = \%hsh;

		$dbi_info_index++;
	}
	my $e2t = \&e2t;
    my $t2e = \&t2e;
	my $i2e = \&i2e;
	my $e2i = \&e2i;
    foreach my $f ( keys %fields ) {
        if ( $f =~ /_EPOCH$/ ) {
            $fields{$f}->{pre_validate} ||= { ref => $t2e };
            $fields{$f}->{code}         ||= { ref => $e2t };
        }
        if ( $f =~ /_INTERVAL$/ ) {
            $fields{$f}->{pre_validate} ||= { ref => $i2e };
            $fields{$f}->{code}         ||= { ref => $e2i };
        }
        if ( $f =~ /_FLAG$/ ) {
            $fields{$f}->{cgi} ||= {
                'args' => {
                    '-values' => [ 0, 1 ],
                    '-labels' => { '0' => 'No', '1' => 'Yes' }
                },
                'func' => 'popup_menu'
            };
        }
        if (
            exists( $fields{$f}->{DBI} )
            && exists( $fields{$f}->{DBI}->{NULLABLE} )
            && !$fields{$f}->{DBI}->{NULLABLE}
          )
        {
            $fields{$f}->{js} = qq{
				if ( this.$f. value == '' ) {
					alert('"$fields{$f}->{pretty}" must not be blank');
					this.$f.focus();
					return false;
				}
			};
        }
    }
	$self->{last_fields} = \%fields;
	return \%fields;
}

=head2 table2file

prints a lot of insert statements to a file handle

 my $err = $ez->table2file (fh=>$fh,table=>'TABLE_NAME');

=cut

sub table2file {
    my $self  = shift;
    my %args  = @_;
    my $fh    = $args{fh};
    my $table = $args{table};
    my $dbh   = $args{dbh} || $self->dbh;

    my $drop_sql = $args{drop_sql};
    my $drop_params = $args{drop_params} || [];

    my $missing_table_not_fatal = $args{missing_table_not_fatal};

    return "No fh supplied" unless $fh;
    my $count = 0;
    if ( exists $args{table} ) {
		# Bloody mysql on windows always uses lowercase table names....
		my @tablist = $dbh->tables;
		s/^\W*.*?\W*?\./$1/ foreach @tablist;	# Strip dbname (mysql does that to us)
        unless ( grep /^\W*$table\W*$/i, @tablist ) {
            if ($missing_table_not_fatal) {
                $self->{table2file} = { count => $count, drop_message => '' }
                  if ref $self;
                return undef;   #which is success in this arse about function...
            } else {
                return "Table '$table' not in database";
            }
        }
    }
    my $sql    = $args{sql}    || "select * from $table";
    my $params = $args{params} || [];
    $params = [$params] unless ref $params;
    my $sth = $dbh->prepare($sql)
      or return { sql => $sql, err => $dbh->errstr };
    $sth->execute(@$params)
      or return { sql => $sql, err => $dbh->errstr, params => $params };
    my $fields = $self->fields( sth => $sth );
    # print "$table ".Dumper $fields;
    while ( my $row = $sth->fetchrow_hashref ) {
        $count++;
        my $ins = $self->insert(
            dbh       => $dbh,
            table     => $table,
            vals      => $row,
            fields    => $fields,
            as_string => 1
        );
        return "write failed:$!" unless print $fh "$ins;\n";
    }
    my $err = $dbh->errstr;
    $sth->finish;
    $self->{table2file}->{count} = $count if ref $self;
    return { sql => $sql, err => $err, params => $params } if $err;
    if ($drop_sql) {
        if ( $dbh->do( $drop_sql, {}, @$drop_params ) ) {
            $self->{table2file}->{drop_message} = "$drop_sql executed";
            $self->{table2file}->{drop_message} .= " with @$drop_params"
              if @$drop_params;
            return undef;
        } else {
            return {
                sql    => $drop_sql,
                params => $drop_params,
                errstr => $dbh->errstr
            };
        }
    }
    return undef;
}

sub field2val {
	my $self = shift;
	my %args = @_;

	my $field = $args{field};
	my $row = $args{row};
	my $form = $args{form} || $field->{form};
	my $dbh = $args{dbh};  # in case we have some value_sql to do.
	my $nonbsp = $args{no_nbsp};
	my $debug = $args{debug};
	my $name_prefix;
	if ($args{name_prefix}){
		$name_prefix = $args{name_prefix};
	} else {
		$name_prefix = ""
	}
	$field->{cgi}->{args}->{-class} = 'input' if exists ($field->{cgi}) && keys %{$field->{cgi}};

    my $val = $row->{$field->{name}};
	# print $dfh "Now fields=$field->{name} val=$val form=$form\n";
    if ($field->{sprintf}){
        my @subs = ();
        push @subs,$row->{$_} foreach @{$field->{sprintf}->{names}};
        $val = sprintf ( $field->{sprintf}->{fmt},@subs );
    }
	# print  "in field2val field:".Dumper $field if $debug;
	# print  "in field2val row:".Dumper $row if $debug;
    if ($field->{code}){
        my @args = ();
		my @arg_names = ();
		if ( $field->{code}->{names}){
			@arg_names = @{$field->{code}->{names}};
		}else{
			@arg_names = ($field->{name});
		}
		if (my $lst = $field->{code}->{args_list}){
			foreach my $arg (@$lst){
				if ($arg->{type} eq 'literal'){
					push @args,$arg->{name};
				}else{
					push @args,$row->{$arg->{name}};
				}
			}
		}else{
        	push @args, $row->{$_} foreach @arg_names;
		}
		print "args=".Dumper \@args if $debug;
        $val = &{$field->{code}->{ref}} (@args);
    }
    # use labels if there are any
    if ($form){
        my $q = new TPerl::CGI ({});
        my %args = ();
        my $func = undef;
        my $name;
        if ($field->{name}) {
        	$name = $field->{name};
        } else {
        	$name = "";
        }
        if ($field->{cgi}){
            %args = %{$field->{cgi}->{args}} if $field->{cgi}->{args};
            $func = $field->{cgi}->{func} if $field->{cgi}->{func};
        }
        $func ||= 'textfield';
		if ($func eq 'textfield'){
			if (exists $field->{DBI}){
				my $prec = $field->{DBI}->{PRECISION};
				my $type = $field->{DBI}->{TYPE} ;
				if ($type==1 || $type == 12){
					$args{-maxlength} = $prec ;
					# If you want sizes, put them in the field yourself.
					# my $size = $prec;
					# $size = 40 if $size>40;
					# $args{-size} ||= $size;
				}
			}
		}
        if ($field->{value_sql} && ($func eq 'popup_menu' || $func eq 'radio_group')){
			$dbh ||= $self->dbh;
			confess "need a dbh for value_sql" unless $dbh;
			my $sql = $field->{value_sql}->{sql};
			my $params_names;
			$params_names = $field->{value_sql}->{params} || [];
			my @params = ();
			push @params,$row->{$_} foreach @$params_names;
			# die Dumper {row=>$row,nam=>$params_names,p=>\@params};
            if (my $res = $dbh->selectall_arrayref($sql,{},@params)){
				my %labels = ();
				my @vals = ();
				foreach (@$res){
					push @vals,$_->[0];
					$labels{$_->[0]} = $_->[1];
				}
				# print Dumper \%labels;
				# print Dumper \@vals;
                $args{-labels} = \%labels;
                $args{-value} = \@vals;
            }else{
				my $params = \@params;
				confess Dumper {sql=>$sql,msg=>'Value Sql1',params=>$params,
					field=>$field,row=>$row,err=>'<PRE>'.$dbh->errstr().'</PRE>'};
			}
        }
        $args{-name} = "$name_prefix$name";
		$args{-name} = $self->field2val(row=>$row,field=>$field->{form_name}) if $field->{form_name};
        if (grep $func eq $_, qw (hidden popup_menu radio_group textfield)){
            $args{-default} = $val
        }else{
            $args{-value} = $val
        }
        $val = $q->$func(%args);
    }else{
	 my $dfh = new FileHandle ">> /tmp/field2val";
        # display only.
        if ($field->{cgi}){
            $val = $field->{cgi}->{args}->{-labels}->{$val} if
                $field->{cgi}->{args} && $field->{cgi}->{args}->{-labels} && exists $field->{cgi}->{args}->{-labels}->{$val};
        }
    }
	# print $dfh "Here code val=($val)\n";
    $val = '&nbsp;' if ($ENV{SERVER_NAME} and !$nonbsp) and ($val eq '');
	# print $dfh "tHere code val=($val)\n";
    return $val;
}

sub value_sql2labels {
	my $self = shift;
	my %args = @_;
	my $field = $args{field};
	my $row = $args{row}||{};
	my $dbh = $args{dbh} || $self->dbh;
	if ($field->{value_sql}  and !exists $field->{cgi}->{args}->{-labels}){
		# print "<BR>Doing valueqsl";
		confess "need a dbh for value_sql" unless $dbh;
		my $sql = $field->{value_sql}->{sql};
		my $params_names = $field->{value_sql}->{params} || [];
		my @params = ();
		push @params,$row->{$_} foreach @$params_names;
		# die Dumper {row=>$row,nam=>$params_names,p=>\@params};
		if (my $res = $dbh->selectall_arrayref($sql,{},@params)){
			my %labels = ();
			my @vals = ();
			foreach (@$res){
				push @vals,$_->[0];
				$labels{$_->[0]} = $_->[1];
			}
			$field->{cgi}->{args}->{-labels}=\%labels;
			# print Dumper \%labels;
			# print Dumper \@vals;
		}else{
			confess Dumper {sql=>$sql,msg=>'Value Sql',params=>\@params,
				field=>$field,row=>$row,err=>'<PRE>'.$dbh->errstr().'</PRE>'};
		}
	}
}

sub validate {
    my $self = shift;
    my %args = @_;

    my $fields = $args{fields} || {};
    my $vals = $args{vals} || {};

    my $new_args = {};
	my %err=();
	my %pre_valid_err = ();
	foreach (qw(fields vals)){
		confess "'$_' is a required parameter" unless $args{$_};
	}
    foreach my $f (keys %$fields){
        my $field = $fields->{$f};
        my $name = $field->{name};
        my $val;
        $val = $vals->{$name};
		if ($field->{pre_validate}){
			my @args = ();
			push @args,$val;
			push @args,@{$field->{pre_validate}->{extra_args}} if 
				$field->{pre_validate}->{extra_args};
			my $newval = undef;
        	eval {$newval = &{$field->{pre_validate}->{ref}} (@args);};
			if ($@){
				push @{$err{$name}},{val=>$val,msg=>$@} ;
				$pre_valid_err{$name}++;
			}else{
				$val = $newval;
			}
		}
        if (exists $field->{DBI} && !$pre_valid_err{$name}){
			#check for nullness 
			if (!$val) {
				$val = "";
			}
            if ($val eq '' || !defined $val){
                push @{$err{$name}},{val=>$val,msg=>"Database column [$field->{pretty}] must not be empty (looking for $name)"} unless
                    $field->{DBI}->{NULLABLE};
            }
			#check length for strings
			if ($field->{DBI}->{TYPE} == 12){
				my $len = length ($val);
				my $limit = $field->{DBI}->{PRECISION};
				push @{$err{$name}},{val=>$val,
					msg=>"cannot put $len characters into a $limit character field"} if
						$len>$limit;
			}
			if ($field->{DBI}->{TYPE} == 4){
				# looks like anumebr
				my @bool = DBI::looks_like_number($val);
				push @{$err{$name}},{val=>$val,
					msg=>"value '$val' does not look like a number"} if $val && !$bool[0];
			}
        }
        $new_args->{$name} = $val;
    }
    my $ret = ();
	if (%err){
		$ret->{err}=\%err;
		# $ret->{vals}=$vals;
	}else{
	}
    	$ret->{vals} = $new_args;
    return $ret;
}

sub update 	{
	my $self = shift;
	my %args = @_;

	my $vals = $args{vals};
	my $table = $args{table};
	my $fields = $args{fields};
	my $key = $args{keys};
	foreach (qw(vals table keys)){
		confess "'$_' is a requred param" unless $args{$_};
	}

	my $sql = "UPDATE $table SET ";
	my @f = ();
	my @p = ();
	my @w = ();

	$fields ||= $self->row2fields($vals);
	my $key_hash = {};
	$key_hash->{$_}++ foreach @$key;

	foreach my $f (keys %$fields){
		next if $key_hash->{$f};
		next if $fields->{$f}->{DBI} && !$fields->{$f}->{DBI}->{TYPE};
		next if grep $_ eq $f,@$key;
		push @f, qq{$f = ?};
		# push @p, $vals->{$f};
		if ($fields->{$f}->{DBI} && $fields->{$f}->{DBI}->{NULLABLE} && $vals->{$f} eq ''){
			push @p, undef;
		}else{
			push @p, $vals->{$f};
		}
	}
	foreach (@$key){
		push @w,qq{$_=?};
		push @p,$vals->{$_};
	}
	$sql .= join ', ',@f;
	$sql .= " where ";
	$sql .= join  ' AND ',@w;
	return {sql=>$sql,params=>\@p};
}

sub insert {
    my $self   = shift;
    my %args   = @_;
    my $vals   = delete $args{vals};
    my $table  = delete $args{table};
    my $fields = delete $args{fields};
    my $as_str = delete $args{as_string};
    my $dbh    = delete $args{dbh};

    confess( "Unrecognised args:" . Dumper \%args ) if %args;

    confess("'vals' is a required arg")  unless $vals;
    confess("'table' is a required arg") unless $table;
    confess("'dbh' is required if 'as_str' is set") if $as_str and !$dbh;

    $fields = $self->row2fields($vals) unless $fields;

    my @f  = ();    #fields
    my @p  = ();    #param vaules
    my @qm = ();    # question marks

    foreach my $f ( keys %$fields ) {
        next if exists( $fields->{$f}->{DBI} ) && !$fields->{$f}->{DBI}->{TYPE};
        push @f,  $f;
        push @qm, '?';
        # push @p, $vals->{$f};
        if (   exists( $fields->{$f}->{DBI} )
            && $fields->{$f}->{DBI}->{NULLABLE}
            && $vals->{$f} eq '' )
        {
            push @p, undef;
        } else {
            push @p, $vals->{$f};
        }
    }
    if ($as_str) {
        confess " dbh is required with as_str " unless $dbh;
        my $sql = " INSERT INTO $table ";
        $sql .= '(' . join( ',', @f );
        foreach (@p) {
            $_ = $dbh->quote($_);
        }
        # $sql .= ') VALUES ('.DBI::neat_list(\@p) .')';
        $sql .= ') VALUES (' . join( ',', @p ) . ')';
        return $sql;
    } else {
        my $sql = " INSERT INTO $table ";
        $sql .= '(' . join( ',',          @f );
        $sql .= ') VALUES (' . join( ',', @qm ) . ')';
        return { sql => $sql, params => \@p };
    }
}
sub delete {
	my $self = shift;
	my %args = @_;

	# print "delete args ".Dumper \%args;
	my $vals = $args{vals};
	my $table = $args{table};
	my $fields = $args{fields};
	my $key = $args{keys};

	foreach (qw(vals table fields keys)){
		confess "'$_' is a requred param" unless $args{$_};
	}

	my $sql = "DELETE FROM $table WHERE ";
	my @f = ();
	my @p = ();
	my @w = ();

	foreach (@$key){
		push @w,qq{$_=?};
		push @p,$vals->{$_};
	}
	$sql .= join  ' AND ',@w;
	return {sql=>$sql,params=>\@p};
}

sub select {
# Deal with key val of different types.
#  perl -MTPerl::DBEasy -MData::Dumper -e 'print Dumper (TPerl::DBEasy->select(keys=>[qw(goose crap)],vals=>[0,[1,2]],table=>"goose"))'
#  perl -MTPerl::DBEasy -MData::Dumper -e 'print Dumper (TPerl::DBEasy->select(keys=>{test=>[1,3],crap=>[5,6]},table=>"goose"))'
    my $self = shift;
    my %args = @_;

	confess ("Both 'keys' and 'key' sent") if exists $args{keys} && exists $args{key};
	confess ("Both 'vals' and 'val' sent") if exists $args{vals} && exists $args{val};

    my $table = delete $args{table};
    my $keys  = delete $args{keys} || delete $args{key};
    my $vals  = delete $args{vals} || delete $args{val};
    my $order = delete $args{order};
	my $ignore_cases = delete $args{ignore_cases} || [];

    confess("'$table is required'") unless $table;
    confess "Unrecognised args" . Dumper \%args if %args;
	confess("'vals' sent with no 'keys'") if $vals && !$keys;

	my $ig_hash = {};
	if ($ignore_cases){
		if (ref($ignore_cases) eq 'ARRAY'){
			$ig_hash->{$_}++ foreach @$ignore_cases;
		}elsif (ref($ignore_cases) eq 'HASH'){
			$ig_hash->{$_} = $ignore_cases->{$_} foreach keys %$ignore_cases;
		}else{
			$ig_hash->{$ignore_cases}++;
		}
	}

    my $sql      = "select * from $table";
    my $params   = [];
    my $key_list = [];
    my $wheres   = {};
    if ($keys) {
        if ( ref($keys) eq 'HASH' ) {
            foreach my $k ( keys %$keys ) {
                my $kvals = [];
                $kvals                = $keys->{$k};
                $kvals                = [$kvals] unless ref($kvals) eq 'ARRAY';
                $wheres->{$k}->{vals} = $kvals;
            }
        } elsif ( ref($keys) eq 'ARRAY' ) {
            unless ( ref($vals) eq 'ARRAY' ) {
                $self->err("'keys' is list and 'vals' is not");
                return;
            }
            unless ( scalar(@$vals) == scalar(@$keys) ) {
                $self->err(
"keys list '@$keys' and vals list '@$vals' are not the same length"
                );
                return;
            }
            for ( my $i = 0 ; $i <= $#$keys ; $i++ ) {
                my $k     = $keys->[$i];
                my $kvals = $vals->[$i];
                $kvals = [$kvals] unless ref($kvals) eq 'ARRAY';
                $wheres->{$k}->{vals} = $kvals;
            }

        } else {
            #keys is a scalar
            my $kvals = $vals;
            $kvals = [$vals] unless ref($vals) eq 'ARRAY';
            $wheres->{$keys}->{vals} = $kvals;
        }
		foreach my $k (keys %$wheres){
			my $kvals = $wheres->{$k}->{vals};
			my $eq = ($k =~ /%/) ? '=' : 'LIKE';
			if ($ig_hash->{$k}){
				$wheres->{$k}->{sql} = join ' OR ', map "upper($k) $eq upper(?)",@$kvals;
			}else{
				$wheres->{$k}->{sql} = join ' OR ', map "$k $eq ?",@$kvals;
			}
		}
    }
	# print "wheres ".Dumper $wheres;
	# print "ig_hash ".Dumper $ig_hash;
    my $where_clause = join ' AND ', map "( $wheres->{$_}->{sql} )",
      keys %$wheres;
    $where_clause = ' WHERE ' . $where_clause if $where_clause;
    $sql .= $where_clause;
    my $orderby_clause = '';
    if ( ref($order) eq 'ARRAY' ) {
        $orderby_clause = join ',', @$order;
    } elsif ( ref( $order eq 'HASH' ) ) {
        confess("Can't handle an order hash");
    } else {
        $orderby_clause = $order;
    }
	$orderby_clause = ' order by ' . $orderby_clause if $orderby_clause and $orderby_clause !~ /^\s*order by/i;
    $sql .= $orderby_clause;
    push @$params, @{ $wheres->{$_}->{vals} } foreach keys %$wheres;
    return { sql => $sql, params => $params };

}
sub row_manip {
    my $self = shift;
    my %args = @_;

    my $action = $args{action};
    my $table = $args{table};
    # my $fields = $args{fields} || $self->fields(table=>$table,dbh=>$dbh,dbi_info=>1);

	# Lets allow passing in an hash of keys and lookup up the list with the $table 
    my $keys = $args{keys};
	if (ref($keys) eq 'HASH'){
		$keys = $keys->{$table}
	}
	$keys ||= [];

    my $dbh = $args{dbh} || $self->dbh ;
	my $vals = $args{vals};
	confess ("No dbh available") unless $dbh;
	foreach (qw(action table vals)){
    	confess "parameter '$_' is required" unless $args{$_};
	}
	if ($action eq 'delete' || $action eq 'update'){
		confess "'keys' is required for delete or update" unless $keys;
	}
    confess "parameter 'action' must be 'insert' 'update' or 'delete' not '$action'"
		unless grep $action eq $_,qw(update insert delete);

    my $fields = $args{fields} || $self->fields(table=>$table,dbh=>$dbh,dbi_info=>1);
	if ($action eq 'insert' && @$keys){
		my $needed_keys = [];
		foreach my $k (@$keys){
			push @$needed_keys,$k unless defined $vals->{$k};
		}
		if (@$needed_keys){
			my $new_vals = $self->next_ids(table=>$table,keys=>$needed_keys);
			my $cnt = 0;
			foreach my $ne (@$needed_keys){
				$vals->{$ne} = $new_vals->[$cnt];
				$cnt++;
			}
		}
	}
    my $valid = $self->validate(vals=>$vals,fields=>$fields);
    # print "valid ".Dumper $valid;
	if ($action eq 'delete'){
		#deletes don;t worry about validation errors for fields that are not keys.
		foreach my $err_field (keys %{$valid->{err}}){
			return {validate=>$valid} if grep $_ eq $err_field, @$keys
		}
	}else{
		return {validate=>$valid} if $valid->{err};
	}
    my ($sql,$params);
    if ($action eq 'insert'){
        my $insert = $self->insert(table=>$table,vals=>$valid->{vals},fields=>$fields);
        # print "insert ".Dumper $insert;
        $sql = $insert->{sql};
        $params = $insert->{params};
    }elsif ($action eq 'update'){
		confess "'keys' is required" unless $keys;
        my $update = $self->update (vals=>$valid->{vals},fields=>$fields,table=>$table,keys=>$keys);
        # print "update ". Dumper $update;
        $sql = $update->{sql};
        $params = $update->{params};
	}elsif ($action eq 'delete'){
		my $delete = $self->delete (vals=>$valid->{vals},fields=>$fields,table=>$table,keys=>$keys);
		# print "delete ".Dumper $delete;
		$sql = $delete->{sql};
        $params = $delete->{params};
    }else{
        confess "parameter 'action' must be 'insert' 'update' or 'delete' not '$action'";
    }
	##Wierd seg fault issue with the previos version of DBD::InterBase
    if (my $rv= $dbh->do($sql,undef,@$params) ){
		# my $pms = join ',',@$params;
        # print "did $sql rv=$rv params=$pms\n";
		$self->params($params);
		$self->sql($sql);
		# Need vals also, so things that are auto filled can be got at later.
		$self->vals($vals);
		return undef;
    }else{
        # print "fail ".$dbh->errstr;
        return {sql=>$sql,params=>$params,err=>$dbh->errstr,dbh=>$dbh};
    }
}

=head2 field_force 

Attempts to force some vals into things that will succeed in inserts.
ie truncate long strings, and set non nullable things to '' or 0.

modifies the passed in vals.

=cut

sub field_force {
	my $self = shift;
	my %args = @_;
	my $fields = $args{fields};
	my $vals = $args{vals};
	# print Dumper \%args;
	my @nums = (4);
	my @strs = (12);
	foreach my $fn (keys %$fields){
		my $f = $fields->{$fn};
		# nullable
# This is tooo scary!  its only used in TPerl::Event and then only to shrink stuff.
# 		if ( !$f->{DBI}->{NULLABLE}  && !defined $vals->{$fn} ){
# 			# print "Here field=$fn val=$vals->{$fn} type=$f->{DBI}->{TYPE}\n";
# 			$vals->{$fn} ='0' if grep $_ == $f->{DBI}->{TYPE},@nums;
# 			$vals->{$fn} = '' if grep $_ == $f->{DBI}->{TYPE},@strs;
# 			# print "Here field=$fn val=$vals->{$fn}\n";
# 		}
		# too long
		if (defined $vals->{$fn} && grep $_ == $f->{DBI}->{TYPE},@strs){
			$vals->{$fn} = substr ($vals->{$fn},0,$f->{DBI}->{PRECISION});
		}
	}
	return $vals;
}

=head2 edit

This is the hard work from aspadmin.pl

 my $ob = new TPerl::TableManip;
 my $res = $ez->edit(_obj=>$ob);
 if ($res->{err}){
 	die $res->{err};
 }else{
 	print $res->{html}
 }

=cut

sub edit {
	my $self = shift;
	my %args = @_;
	
	my $manip = $args{_obj}; # Thing based on the TPerl::Tablemanip.
	my $table = $args{table};
	my $tablekeys = $args{_tablekeys};
	my $fields = $args{_fields};
	my $lf = $args{_lf} || new TPerl::LookFeel;
	my $title = $args{_title};
	my $new_button_tables = $args{_new_buttons} || [];
	my $new_button_text = $args{_new_buttons_text};
	my $states = $args{_state} || [];
	my $new = $args{new};
	my $edit = $args{edit};
	my $delete = $args{delete};
	my $list_limit = $args{_list_limit} || $args{limit} || 30;
	my $list_sql = $args{_list_sql};
	my $list_params = $args{_list_params} || [];
	my $list_rows = $args{_list_rows};
	my $list_edit=1;
	my $list_del=1;
	my $list_form = 1;
	$list_form = $args{_list_form} if defined $args{_list_form};
	$list_edit = $args{_list_edit} if defined $args{_list_edit};
	$list_del = $args{_list_del} if defined $args{_list_del};
	my $action = $args{_action} || "$ENV{SCRIPT_NAME}$ENV{PATH_INFO}" ;
	# When you are editing stuff, sometimes you need to 
	# to (say) htaccess stuff if the db stuff works.  This happens just
	# before the redirect after the row_manip.  
	my $pre_redirect = $args{_pre_redirect};
	my $extra_validate_fields = $args{_on_invalid} || {};

	$new_button_text ||= {};
	unless (ref $new_button_text eq 'HASH'){
		my $th = {$table=>$new_button_text};
		$new_button_text = $th;
	}
	$new_button_text->{$table} ||= "New $table";

	# cleans the states
	my $shsh = {};
	$shsh->{$_}++ foreach @$states;
	delete $shsh->{$_} foreach qw(table new edit delete);
	$states = [keys %$shsh];
	
	return {err=>"No obj sent"} unless $manip;
	my $tables = $manip->table_create_list;
	confess "table not set" unless $table;
	return {err=>"Table '$table' not listed"} unless grep $table eq $_,@$tables;
	my $q = new TPerl::CGI ('');
	$tablekeys->{$table} ||=[];
	my $ret = {};
	if ($table && $edit==2){
		my $keys = $tablekeys->{$table};
		if (my $err = $self->row_manip (action=>'update',table=>$table,vals=>\%args,fields=>$fields,keys=>$keys)){
			my $stuff;
			my $title;
			if (my $v = $err->{validate}){
				# Sometimes there is a PWD field (say) that is in the data, but not the database.  put these back
				$fields->{$_} ||= $extra_validate_fields->{$_} foreach keys %$extra_validate_fields;
				my $hiddens = {}; $hiddens->{$_} = $args{$_} foreach @$states;
				$stuff = $self->form(action=>$action,fields=>$fields,table=>$table,edit=>2,row=>\%args,valid=>$v,state_vars=>$hiddens);
			}else{
				$stuff = $q->dberr(dbh=>$self->dbh,sql=>$err->{sql});
			}
			$ret->{html}=$stuff;
			$ret->{title}=$title;
		}else{
			my $hiddens = {table=>$table}; $hiddens->{$_} = $args{$_} foreach @$states;
			if ($pre_redirect){
				eval {&$pre_redirect ();};
				$q->mydie($@) if $@;
			}
			print $q->redirect("$action?".join "&",map ("$_=$hiddens->{$_}",keys %$hiddens));
		}
	}elsif ($table && $edit==1){
		# shpw the edit form
		 my $title = "Edit this stuff";
		 my $sql = "select * from $table where ";
		 my @where = ();my @params = ();
		 my $keys = $tablekeys->{$table};
		 if (@$keys){
		 	foreach my $k (@$keys){
				push @where, " $k=? ";
				push @params, $args{$k};
			}
			$sql .= join 'AND',@where;
			my $hiddens = {}; $hiddens->{$_} = $args{$_} foreach @$states;
			if (my $res = $self->dbh->selectall_arrayref($sql,{Slice=>{}},@params)){
				$ret->{html}= $self->form(action=>$action,fields=>$fields,table=>$table,edit=>2,row=>$res->[0],state_vars=>$hiddens);
			}else{
				die "db error getting row";
			}
		 }else{
		 	$ret->{err}="No tablekeys sent";
		 }
	}elsif ($table && $delete==1){
		my $keys = $tablekeys->{$table};
		my $hiddens = {table=>$table}; $hiddens->{$_} = $args{$_} foreach @$states;
		if (my $err = $self->row_manip(keys=>$keys,vals=>\%args,table=>$table,action=>'delete',fields=>$fields)){
			$ret->{html}= $q->dberr(dbh=>$self->dbh,%$err);
		}else{
			if ($pre_redirect){
				eval {&$pre_redirect ();};
				$q->mydie($@) if $@;
			}
			print $q->redirect("$action?".join "&",map ("$_=$hiddens->{$_}",keys %$hiddens));
		}
		
	}elsif ($table && $new==2){
		# send the form data to the database.
		my $err = $self->row_manip(table=>$table,fields=>$fields,action=>'insert',vals=>\%args);
		if ($err){
			my $stuff;
			my $title;
			my $hiddens = {}; $hiddens->{$_} = $args{$_} foreach @$states;
			if (my $v=$err->{validate}){
				# Sometimes there is a PWD field (say) that is in the data, but not the database.  put these back
				$fields->{$_} ||= $extra_validate_fields->{$_} foreach keys %$extra_validate_fields;
				$title = 'Please fix these problems';
				$stuff = $self->form(action=>$action,fields=>$fields,table=>$table,new=>2,row=>\%args,
					valid=>$v,state_vars=>$hiddens);
			}else{
				$stuff = $q->dberr(dbh=>$self->dbh,sql=>$err->{sql});
			}
			$ret->{title}=$title;
			$ret->{html}=$stuff;
		}else{
			if ($pre_redirect){
				eval {&$pre_redirect ();};
				$q->mydie($@) if $@;
			}
			my $hiddens = {table=>$table}; $hiddens->{$_} = $args{$_} foreach @$states;
			print $q->redirect("$action?".join "&",map ("$_=$hiddens->{$_}",keys %$hiddens));
		}
	}elsif ($table && $new==1){
		# ask for the insert data
		my $row = $args{_defaults} || {};
		my $keys = $tablekeys->{$table};
		if (@$keys){
			my $key_vals = $self->next_ids(table=>$table,keys=>$keys);
			$q->mydie($q->dberr(dbh=>$self->dbh,err=>"Could not get next_ids for $table")) unless $key_vals;
			foreach (0..$#$keys){
				next if defined $row->{$keys->[$_]};
				$row->{$keys->[$_]} = $key_vals->[$_];
			}
			# die Dumper ({key_vals=>$key_vals,keys=>$keys,row=>$row});
		}
		my $hiddens = {}; $hiddens->{$_} = $args{$_} foreach @$states;
		$ret->{html} = $self->form(action=>$action,fields=>$fields,table=>$table,new=>2,row=>$row,state_vars=>$hiddens);
		# $ret->{html} .= $q->dumper (\%ENV);
	}elsif ($table){
		$fields ||= $self->fields(table=>$table);

		my $page = $args{page} if $args{page};
		$page = $args{next} if $args{submit} =~ /next/i;
		$page = $args{previous} if $args{submit} =~ /prev/i;
		$page = $args{page} if $args{submit} =~ /go/i;
		$page = $page->[0] if ref $page eq 'ARRAY';

		#### Add the edit and delete columns
		my $keys = $tablekeys->{$table};
		if (@$keys){
			my $hiddens = {table=>$table}; $hiddens->{$_} = $args{$_} foreach @$states;
			$hiddens->{page} = $page if $page;
			my $qs = join ('&',map"$_=$hiddens->{$_}",keys %$hiddens);
			## Two ways of doing these edit things
			if ($list_edit){
				$fields->{edit}->{sprintf}->{fmt} = qq{<A HREF="$action?edit=1&$qs&}.
					join ('&',map"$_=%s",@$keys).qq{"><img src="/pix/edit.gif" alt="Edit" border="0"></A>};
				$fields->{edit}->{sprintf}->{names} = $keys;
				$fields->{edit}->{pretty} = 'Edit';
				$fields->{edit}->{order} = -2;
			}
			if ($list_del){
				$fields->{delete}->{code} = {
					names=>$keys,
					ref=>sub {
						my $q = new CGI('');
						my %args = ();
						@args{@$keys} = @_;
						my $href = "$action?delete=1&$qs&".
							join '&',map "$_=$args{$_}",keys %args;
						return $q->img({-src=>'/pix/clear.gif',-alt=>'Delete',-onclick=>qq{if (confirm('Deletion cannot be undone')){document.location.href='$href'}}});
					}
				};
				$fields->{delete}->{pretty} = 'Del';
				$fields->{delete}->{order} = -1;
			}
		}

		
		my $sql;
		unless ($list_rows){
			$sql = "select * from $table";
			$sql = "$sql order by $_ DESC" if $_ = join ',',@{$tablekeys->{$table}};
			$sql = $list_sql if $list_sql;
		}

		
		my $form_hidden = {table=>$table};
		$form_hidden->{$_} = $args{$_} foreach @$states;

		my $lister =  $self->lister(
			sql=>$sql,
			fields=>$fields,
			form_hidden=>$form_hidden,
			look=>$lf,
			limit=>$list_limit,
			form=>$list_form,
			page=>$page,
			params=>$list_params,
			rows=>$list_rows,
		);
		my $box;
        my $new_button = join "\n",
                $q->start_form (-action=>$action,-method=>'POST'),
				# "in edit list_limit=$list_limit",
				map (qq{<input type="hidden" name="$_" value="$form_hidden->{$_}">},keys %$form_hidden),
                qq{<input type="hidden" name="new" value="1">},
                $q->submit(-name=>$new_button_text->{$table}),
                $q->end_form if grep $table eq $_,@$new_button_tables;


        if ($lister->{count}){
                $box = join "\n",@{$lister->{html}};
                $box .= join "\n",@{$lister->{form}} if $lister->{form};
				$box .= $new_button;
				# $box .= $q->dumper ($fields);
        }elsif ($lister->{err}){
                $box = $q->dumper ($lister);
        }else{
                $box = join "\n",$lf->sbox($title),'No data',$lf->ebox;
				$box .= $new_button;
				# $box .= $q->dumper(\%args);
				# $box .= $q->dumper($form_hidden);
        }
		$ret->{html} = $box;
		$ret->{title} = "Admin for $table";
	}else{
		$ret->{html} = '';
		$ret->{title} = 'Admin Page no table';
	}
	return $ret;
}

sub get_rows {
    my $self = shift;
    my %args = @_;

	# a wrapper round DBI->selectall_arrayref(..{Slice=>{}) but it formats the
	# error messages etc.
	#
	# Sometimes you are searching on a primary key for exactly one record.  Use
	# the exactly_one=>1 in this case, and it will return a reference to the
	# row itself rather than to the list.  If there are more or less than one
	# row, return nothing and set the err.
	#
	# Sometimes when you want exactly one item, but getting none is not fatal,
	# or perhaps you want to rephrase the error message.  In this case use
	# allow_none=>1 and you get an empty array.  You get an empty array as
	# opposed to an empty hash so you can differentiate bw it and the hash you
	# were expecting.
	

    my $exactly_one = delete $args{exactly_one};
    my $allow_none  = delete $args{allow_none};

	my $sel = $self->select(%args) || return undef;

	# confess "Unrecognised args" . Dumper \%args if %args;
    confess("'allow_none' is meaningless without 'exactly_one'")
      if $allow_none and !$exactly_one;

    my $dbh       = $self->dbh || return;
    my $sql = $sel->{sql};
	my $params = $sel->{params};

    my $rows = $dbh->selectall_arrayref( $sql, { Slice => {} }, @$params );
    unless ($rows) {
        $self->err( { dbh => $dbh, sql => $sql, errstr => $dbh->errstr } );
        return;
    }
    if ($exactly_one) {
        return $rows->[0] if @$rows == 1;
        return [] if @$rows == 0 and $allow_none;
        $self->err(
            sprintf(
"Found '%s' rows when we were called expecting exactly one with '$sql' parmas '@$params'",
                scalar(@$rows) )
        );
        return;
    }
    return $rows;
}


sub row_freeze {
    # converts a hash to an array of strings.  Useful for dumping to a file
    # designed to dump db hierarchies.  uses a header and indenting so you can
    # get
    # row
    # key=val
    # key=val
    # 	row
    # 	key=val
    # 	key=val
    # 	row
    # 	key=val etc
    #
    my $self   = shift;
    my %args   = @_;
    my $row    = delete $args{row} || confess("No 'row' supplied");
    my $head   = delete $args{head} || 'row';
    my $list   = delete $args{list} || [];
    my $indent = delete $args{indent} || ' ';
    my $level  = delete $args{level} || 1;
    confess "Unrecognised args" . Dumper \%args if %args;
    confess "row must be a hash" unless ref($row) eq 'HASH';
    confess("TODO:Need to escape multiline values")
      if grep /[\n\r]/, values %$row;

    my $ind = $indent x ( $level - 1 );
    push @$list, $ind . $head;
    push @$list, map "$ind$_=$row->{$_}", sort keys %$row;
    return $list;
}


sub row_thaw {
    # the reverse of the above. shifts things off the list and returns the hash.
    # We need to escape new lines in the hash...
    # you need to call this like
    # my ($level,$row) = $esob->row_thaw(list=>$list) or die $esob->err;
    # as the following will not work...
    # my ($level,$row) = $esob->row_thaw(list=>$list) || die $esob->err;

    my $self   = shift;
    my %args   = @_;
    my $list   = delete $args{list} || confess("No 'list' supplied");
    my $head   = delete $args{head} || 'row';
    my $indent = delete $args{indent} || ' ';
    confess "Unrecognised args" . Dumper \%args if %args;

    my $hash     = {};
    my $head_rex = qr/^($indent*)$head:\w+$/;
    my $level    = 0;

    if ( $list->[0] =~ $head_rex ) {
        shift @$list;
        $level = length($1) + 1;
    } else {
        $self->err(
            "First element '$list->[0]' does not look like a header for '$head'"
        );
        return;
    }
    while ( my $line = shift @$list ) {
        if ( $line =~ $head_rex ) {
            unshift @$list, $line;
            return $level, $hash;
        } elsif ( my ( $key, $val ) = split '=', $line, 2 ) {
            $key =~ s/^\s*(.*?)/$1/;
            $hash->{$key} = $val;
        } else {
            $self->err("Parser error getting keys and values from '$line'");
            return;
        }
    }
    return $level, $hash;
}

sub file2create_sql {
	my $self = shift;
	my %args = @_;
	my $file = $args{file};
	my $table = $args{table};
	foreach (qw (file table)){
		confess ("'$_' is a required arg") unless $args{$_};
	}
	my $tsv = try_new TPerl::TSV(file=>$file,dbhead=>1,nocase=>1);
	my $h = $tsv->header();
	unless ($h){
		$self->err("Could not create sql from '$file':".$tsv->err);
		return undef;
	}
	my $types = {};
	my $need_to_check = {};
	my $lengths = {};
	$need_to_check->{$_}++ foreach @$h;
	while (my $r = $tsv->row){
		foreach my $c (@$h){
			$lengths->{$c} = length($r->{$c}) if length($r->{$c}) >$lengths->{$c};
		}
		foreach my $c (keys %$need_to_check){
			if ($r->{$c} eq ''){
			}else{
				if (DBI::looks_like_number($r->{$c})){
					if ($r->{$c} =~ /\D/){
						$types->{$c} = 'REAL' if $types->{$c} eq '' or $types->{$c} eq 'INTEGER'
					}else{
						$types->{$c} ||= 'INTEGER'
					}
				}else{
					$types->{$c} = 'VARCHAR';
					delete $need_to_check->{$c};
				}
			}
		}
	}
	foreach my $hd (@$h){
		$types->{$hd} ||='INTEGER';
		$types->{$hd} = "VARCHAR($lengths->{$hd})" if $types->{$hd} eq 'VARCHAR';
	}
	return "create table $table (" . join (",\n",map ("$_ $types->{$_}",@$h)) . ")";
}


1;

