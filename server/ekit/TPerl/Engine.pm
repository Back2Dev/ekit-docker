package TPerl::Engine;
#$Id: Engine.pm,v 1.25 2011-09-07 10:02:43 triton Exp $

use strict;
use FileHandle;
use DirHandle;
use Fcntl qw(:flock);
use Carp qw(confess);
use File::Slurp;
use Data::Dumper;

use TPerl::TritonConfig;
use TPerl::Survey;

sub new {
	my $proto=shift;
	my $class = ref $proto || $proto;
	my $self = {};
	my %args = @_;
	bless $self,$class;
	foreach (qw(dbh SID troot)){
		$self->$_($args{$_}) if $args{$_};
	}
	return $self;
}

sub err { my $self = shift; return $self->{_err}=$_[0] if @_;return $self->{_err}}
sub dbh { my $self = shift; return $self->{_dbh}=$_[0] if @_;return $self->{_dbh}}
sub troot { my $self = shift; return $self->{_troot}=$_[0] if @_;return $self->{_troot}}
sub SID { my $self = shift; return $self->{_SID}=$_[0] if @_;return $self->{_SID}}
sub gz { my $self = shift; return $self->{_gz}=$_[0] if @_;return $self->{_gz}}
sub chmod { my $self = shift; return $self->{_chmod}=$_[0] if @_;return $self->{_chmod}}
sub use_tnum { my $self = shift; return $self->{_use_tnum}=$_[0] if @_;return $self->{_use_tnum}}
sub read_only { my $self = shift; return $self->{_read_only}=$_[0] if @_;return $self->{_read_only}}
sub copyright { return 'Copyright 1996... Triton Information Technology, all rights reserved'}

sub nextseq {
	my $self = shift;
    # &subtrace;
    my $inidir = getInidir || '/triton';
    my $filename = "$inidir/seqno.txt";     # Input file
    my $ofilename = "$inidir/seqno.txt";    # Output file
	my $seqno;
	# give the proper filename a chance to be created.
    unless (-e $filename){
        my $fh = new FileHandle ">$filename";
        close $fh;
    }
    $filename = "seqno.txt" if (! -f $filename);    # read from local file if /cfg/seqno.txt not there
    # a race condition occurs if several processes call this function before the first one has had a chance
    # to rewrite the seqno file (hoever unlikeley this may seem)...
    # lets do some file locking and stop this
    # &debug("Opening sequence no file: $filename");
    if (open (SEQ_FILE, "+<$filename"))
        {
        if (flock (SEQ_FILE,LOCK_EX))
            {
            $seqno = <SEQ_FILE>;
            $seqno ||=99;
            $seqno++;
            seek (SEQ_FILE,0,0);
            print SEQ_FILE "$seqno\n";
            flock (SEQ_FILE,LOCK_UN);
            close SEQ_FILE
            }
        }
    else
        {
        $self->err ("Please Try again later.\n(Cannot open file $filename for writing)");
		return undef;
        }
	return $seqno;
    # &endsub;
}

sub next_dfilename {
	my $self = shift;
	my $seqno = $self->nextseq;
	my ($wkstid,$rolling) = GetWKSTID;
	$seqno = $wkstid.sprintf("%06d",$seqno) if ($wkstid ne '');
	my $dfile = "D$seqno.pl";
	$dfile .= 'z' if $self->gz;
	return $dfile;
}
sub u_read {
	my $self = shift;
	my $fn = shift;
	unless (-e $fn){
		$self->err("ufile '$fn' does not exist");
		return undef;
	}
	my %ufields = ();
	eval read_file $fn;
	if ($@){
		$self->err("Eval error in '$fn'");
		return undef;
	}
	return \%ufields;
}
sub u_filename {
	my $self = shift;
	my $pwd = shift;
	confess ("First param must be a 'pwd'") unless defined($pwd);
	my $SID = $self->SID() || confess ("Can't find a SID");
	my $troot = $self->troot || confess ("Can't find a troot");
	return join '/',$troot,$SID,'web',"u$pwd.pl";
}

sub u2resp {
	my $self = shift;
	my $u_filename = shift;
	my $resp = shift;
	confess "second param should be a hash ref" unless ref ($resp) eq 'HASH';
	my $u = $self->u_read($u_filename) || return undef;
	$resp->{$_} = $u->{$_} foreach keys %$u;
	$resp->{token} ||= $u->{passwword};
	$resp->{id} ||= $u->{uid};
	return 1;
}

sub u_save {
	## This is similar to save_ufile but used when fixing ufiles, and putting them in
	## other dirs etc..
	my $self = shift;
	my $fn = shift;
	my $ufields = shift;


	unless (open (X,">$fn")){
		$self->err("Cannot create temp file: $fn");
		return undef;
	}
    print X "#!/usr/bin/perl\n#\n# Data for user: $ufields->{password}\n%ufields = (\n";
    foreach my $key (sort keys (%$ufields))
        {
    # Escape out unwanted characters in input string
        my $this = $$ufields{$key};
        $this =~ s/\r\n/\n/g;
        $this =~ s/\n/\\n/g;
        $this =~ s/([\\'])/\\\1/g;
        # $this = $pwd if ($key eq 'password');
		my $lkey=lc($key);
        print X "\t'$lkey' => '$this',\n";
        }
    print X "\t);\n# Please leave this soldier alone:\n1;\n";
    close X;
	return $fn;
}
sub u_edit_to_temp{
	my $self = shift;
	my %args = @_;
	my $f=$args{file};
	my $change = $args{change};
	my $u = $self->u_read($f)  || return undef;
	foreach my $c (keys  %$change){
		$u->{$c} =  $change->{$c};
	}
	my $tmp =  new File::Temp (UNLINK=>0);
	my $new = $tmp->filename;
	$tmp->close;
	$self->u_save($new,$u)  || return undef;
	return $new;
}

sub qt_edit_to_temp {
	my $self = shift;
	my %args = @_;
	my $f=$args{file};
	confess ("'file' not sent") unless exists $args{file};
	my $change = $args{change};
	confess ("'change' is a required arg") unless exists $args{change};
	confess ("'chnage' must be a hashref") unless ref $change eq 'HASH';
	my $u = $self->qt_read($f)  || return undef;
	foreach my $c (keys  %$change){
		$u->{$c} =  $change->{$c};
	}
	my $tmp =  new File::Temp (UNLINK=>0);
	my $new = $tmp->filename;
	$tmp->close;
	$self->qt_save($new,$u)  || return undef;
	return $new;
}

sub qt_read {
    my $self = shift;
    my $filename = shift;

    unless (-e $filename){
        $self->err("File '$filename' does not exist");
        return undef;
    }
    my %resp = ();
    eval read_file ($filename);
    if ($@){
        $self->err("eval error in $filename:$@");
        return undef;
    }
    return \%resp;
}

sub qt_save
    {
	my $self = shift;
	my $filename = shift;
	my $resp=shift;
	my $tfilename = shift;

	confess ("First param must be full filename") unless $filename;
	confess ("Second param must be ref to a hash") unless $resp;

	# ???? what is %dun?
	# It's a hash that is used to track which CGI input fields have been dealt with, anything else is classed as an external
	my $copyright=$self->copyright;
    # &subtrace('qt_save');
    if ($self->read_only)
        {
        debug("Read only mode: data not saved");
        }
    else
        {
        if($self->gz)
            {
            # &debug ("Saving response data to file $filename, ${tfile}");
            my $frozen = freeze(\%$resp);
            my $skwoshd = compress($frozen) ;
            store (\$skwoshd,"$filename")  or die "Can't store data in $filename!\n";
            if ($self->use_tnum() && ($tfilename ne ''))
                {
                store (\$skwoshd,"$tfilename")  or die "Can't store data in $tfilename!\n";
                }
            }
        else
            {
            # &debug ("Saving response data to file $filename $tfile");
            if (!open (DATA_FILE, ">$filename"))
                {
                # &add2body("Error $! - Can't open data file: $filename\n");
				$self->err = ("Can't open data file $filename:$!");
				return undef;
                }
            else
                {
                print DATA_FILE '#!/usr/bin/perl'."\n";
				if ($ENV{SCRIPT_NAME})		# Done by a CGI script ?
					{
					$resp->{modified} = time();
					$resp->{modified_s} = localtime();
					}
				else
					{
					$resp->{modified}++;						# Bump it by a second
					$resp->{modified_s} = localtime($resp->{modified});
					$resp->{modified_byscript} = time();		# Record the actual time here
					$resp->{modified_byscript_s} = localtime();
					}
        #
        # Save the response data in its own associative array
        #
                my $when = localtime();
                print DATA_FILE "# $copyright\n# Response data... $when\n";
                my $nkeys = scalar keys %$resp;
                my $checksum_keys = unpack("%32C*",join('',keys %$resp)) % 65535;
                my $checksum_data = unpack("%32C*",join('',values %$resp)) % 65535;
                print DATA_FILE "##DFILE_CHK: nkeys=$nkeys checksum_keys=$checksum_keys checksum_data=$checksum_data seq=$resp->{seqno} ts=$resp->{modified}\n\t%resp = (\n";
                my $i = 0;
                foreach my $key (sort (keys %$resp))
                    {
        # Escape out unwanted characters in input string
                    my $this = $resp->{$key};
                    $this =~ s/\r\n/\n/g;
                    $this =~ s/\n/\\n/g;
                    $this =~ s/([\\'])/\\$1/g;
                    print DATA_FILE "\t\t'$key','$this',\n";
                    $i++;
                    }
                #$dun{'seqno'} = 1;
                print DATA_FILE "\n\t\t);\n";
        #
        # Close the file off
        #
                print DATA_FILE "#\n# I Like the number wun\n1;\n";
                close DATA_FILE;
				my $chmod = $self->chmod;
                &chmod ($chmod,"$filename") if ($chmod);
            }
        #
        # Now do the Tfile as well:
        #
            if ($self->use_tnum() && ($tfilename ne ''))
                {
                if (!open (T_FILE, ">$tfilename"))
                    {
                    &add2body("Error $! - Can't open data file: $tfilename\n");
                    }
                else
                    {
                    print T_FILE '#!/usr/bin/perl'."\n";
					if ($ENV{SCRIPT_NAME})		# Done by a CGI script ?
						{
						$resp->{modified} = time();
						$resp->{modified_s} = localtime();
						}
					else
						{
						$resp->{modified}++;						# Bump it by a second
						$resp->{modified_s} = localtime($resp->{modified});
						$resp->{modified_byscript} = time();		# Record the actual time here
						$resp->{modified_byscript_s} = localtime();
						}

            #
            # Save the response data in its own associative array
            #
                    my $when = localtime();
                    print T_FILE "# $copyright\n# Response data... $when\n#\n\t%resp = (\n";
                    my $i = 0;
                    foreach my $key (sort (keys %$resp))
                        {
            # Escape out unwanted characters in input string
                        my $this = $resp->{$key};
                        $this =~ s/\r\n/\n/g;
                        $this =~ s/\n/\\n/g;
                        $this =~ s/([\\'])/\\$1/g;
                        print T_FILE "\t\t'$key','$this',\n";
                        $i++;
                        }
                    #$dun{'seqno'} = 1;
                    print T_FILE "\n\t\t);\n";
            #
            # Close the file off
            #
                    print T_FILE "#\n# I Like the number wun\n1;\n";
                    close T_FILE;
                    }
                }
            }
        }
		return 1;
    # &endsub;
    }

##This is copied from 360-lib.pl, with a few minor changes to not use global vars.
sub save_ufile
    {
	my $self = shift;
    my $survey_id = shift;
    my $pwd = shift;
	my $ufields = shift;

	confess ("First param must be survey_id") unless $survey_id;
	confess ("Second param must be pwd") unless $pwd;
	confess ("Third param must be ref to a ufields") unless $ufields;

    # die "$survey_id: Missing ufile PWD" if ($pwd eq '');
	
	my $qt_root = getConfig ('TritonRoot');
    my $data_dir = "${qt_root}/${survey_id}/web";
    # &force_dir($data_dir);
    my $fn = "$data_dir/u$pwd.pl";
    #&debug("Saving file: $fn");
	unless (open (X,">$fn")){
		$self->err("Cannot create temp file: $fn");
		return undef;
	}
    # open (X,">$fn") || &my_die("Cannot create temp file: $fn\n");
    print X "#!/usr/local/bin/perl\n#\n# Data for user: $pwd\n%ufields = (\n";
    foreach my $key (sort keys (%$ufields))
        {
    # Escape out unwanted characters in input string
        my $this = $$ufields{$key};
        $this =~ s/\r\n/\n/g;
        $this =~ s/\n/\\n/g;
        $this =~ s/([\\'])/\\\1/g;
        $this = $pwd if ($key eq 'password');
        print DATA_FILE "\t\t'$key','$this',\n";

        print X "\t'$key' => '$this',\n";
        }
    print X "\t);\n# Please leave this soldier alone:\n1;\n";
    close X;
	return $fn;
    }
	
sub qt_new
    ## Copied from qt_libdb.pl.  one change is that we return the resp hash ref
	## where it used to return the seqno. look inside the resp for the seqno if you need it.
    {
	my $self = shift;
    my $sid = shift;
    # &subtrace($sid);
    # $seqno = 100;
    my $seqno = $self->nextseq();
	return undef unless $seqno;
	my ($wkstid,$rolling) = GetWKSTID;
	my $resp = {};
	$resp->{survey_id} = $sid;
    $resp->{'wkstid'} = $wkstid;          # Get the workstation id
    $resp->{'ver'} = 1;                   # Assume it's version 1 at this point !
    $resp->{tnum} = 1;                    # First t-file too !
    $seqno = $wkstid.sprintf("%06d",$seqno) if ($wkstid ne '');
	### qt_save does this stuff.
#     $tfile = '';
#     $dfile = "D$seqno.pl";
#     $dfile .= "z" if ($gz);
#     $tfile = "T$seqno.$resp{tnum}.pl" if ($use_tnum);
#     $tfile .= "z" if ($use_tnum && $gz);

	#### Sequences are ignored.
#     if ($#sequences != -1)
#         {
#         $resp{'random_seq'} = int(rand($#sequences )+0.5);
#         $resp{'random_ix'} = 0;         # First q has been done already
#         &debug("Selecting random sequence ($resp{'random_seq'})");
#         }
    # &debug("Data file set to $dfile, $tfile");
    # &endsub;
    # return $seqno;
	$resp->{seqno} = $seqno;
	return $resp;
    }

# my $invno = $engine->nextnumber($SID,'invoiceno',400);
# Returns the next number
sub nextnumber
	{
	my $self = shift;
	my $sid = shift;
	my $type = shift;
	my $defno = shift || 500;
	
	confess ("First param must be SID") unless $sid;
	confess ("2nd param must be a type (eg 'invoiceno')") unless $type;

	my $ino = 999;
	my $troot = getConfig('TritonRoot');
	my $filename = "$troot/$sid/web/$type.txt";
	if (open (INVOICE_FILE, "<$filename"))
		{
		while (<INVOICE_FILE>)
			{
			$ino = $_;
			#			print "$ino ++\n";
			$ino++;
			last;
			}
		close(INVOICE_FILE);
		}
	else
		{
	#         print "Starting new invoiceno\n";
		$ino = $defno;
		}
	#
	# Now write the new number back to the file
	#
	if (open (INVOICE_FILE, ">$filename"))
		{
		print INVOICE_FILE "$ino\n";
		close(INVOICE_FILE);
		}
	else
		{
		confess "Cannot open file $filename for writing\n";
		}
	$ino;
	}


sub SID_list {
	## This is sort of a engine task in its most basic form
	# it could be an asp task also.
	my $self = shift;
	my %args = @_;

	#need an arg that does a recalculate???
	#
	
	# use Data::Dumper;confess ref($self) if $self eq 'TPerl::Engine';

	return $self->{SID_list} if (ref($self)) && (exists $self->{SID_list});
	my $list = [];
	my $troot = getConfig('TritonRoot');
	my $dh = new DirHandle ($troot);
	unless ($dh){
		$self->err("Could not open DirHandle for '$troot':$!");
		return undef;
	}
	while (my $d = $dh->read){
		next if grep $_ eq $d,qw(. .. cfg db database mailbox log templates CVS pwikit);
		push @$list,$d if -d ("$troot/$d");
	}
	@$list = sort @$list;
	unshift @$list,'' if $args{add_blank};
	$self->{SID_list} = $list if ref($self);
	return $list;
}

sub SID_labels {
	my $self = shift;
	my %args = @_;
	
	# later the list could be a smaller/custom list passed in
	my $list = $self->SID_list()||return undef;

	return $self->{SID_labels} if exists $self->{SID_labels};

	my $labels = {};
	foreach my $SID (@$list){
		my $sfile = survey_file TPerl::Survey($SID);
		if (-e $sfile){
			my $s = eval read_file $sfile;
			# print "$SID\n";
			$labels->{$SID} = "$SID:".$s->options->{survey_name};
		}else{
			$labels->{$SID} = $SID;
		}
	}
	$self->{SID_labels} = $labels;
	return $labels;
}

sub pw_generate    {
    my $self=shift;

    # Since '1' is like 'l' and '0' is like 'O', don't generate passwords with them.
    # Also I,J,L,O,Q,V
    # This will just confuse people using ugly fonts.                                                                                                                               #
    my @passset = ('A'..'H','K','M','N','P','R'..'U','X'..'Z');
    #, 'A'..'N', 'P'..'Z', '2'..'9') ;
    my $rnd_passwd = "";
    my $lastwun = '';
    my $i=0;
    while ($i < 8)
        {
        my $randum_num = int(rand($#passset + 1));
        my $this = @passset[$randum_num];
        # print "th=$this lw=$lastwun i=$i\n";
        if ($this ne $lastwun)
                {
                $rnd_passwd .= $this;
                $lastwun = $this;
                $i++;
                }
        }
	print "Generated pwd=$rnd_passwd\n";
    return $rnd_passwd;
}
sub db_getnextpwd {
    my $self=shift;
    my $sid = shift;
    unless ($sid){
        $self->err("SID must be first param to db_getnextpwd");
        return undef;
    }
    my $unique = 0;
    my $loopcnt = 0;
    my $newpwd = '';
    my $dbh = $self->dbh;
    # print Dumper [$dbh->tables];
	# MYSQL on Windows creates the tables with lower case names, hence the case-insensitive search
    #unless (grep /^\W*$sid\W*$/i,$dbh->tables){             
    #    $self->err("Table $sid not in database");
    #    return undef;
    #}
	my $checksql = "show create table $sid";
    my $th = $dbh->prepare($checksql) || die "Cannot prepare SQL statement: $DBI::errstr\n";
#
    if (!$th->execute())
        {
# Fail quietly, because it's what we expect, but die on other errors...
        die "SQL execute errror with sql=[$checksql]: $DBI::errstr\n" if ($DBI::errstr !~ /doesn't exist/i);
        $th = undef;
        }
	if (!$th) {
        $self->err("Table $sid not in database");
		return undef;
	}

							 
    while (!$unique) {
        $newpwd = $self->pw_generate();                   # What the user must type in
        my $sql = "SELECT COUNT(*) FROM $sid WHERE PWD=?";
        my $rows = $dbh->selectall_arrayref($sql,{},$newpwd);
#        print $loopcnt . Dumper $rows;
        $unique = 1 if ($rows->[0]->[0] eq "0");
        $loopcnt++;
        if ($loopcnt > 100) {
            $self->{err} = ('Failed to find new password after 100 attempts');
            return undef;
        }
    }
    return $newpwd;
}
sub db_save_pwd_full {
    my $self = shift;
    my $dbh = $self->dbh;
    my $SID = shift;
    my $uid = shift;
    my $pwd = shift;
    my $fullname = shift;
    my $delta = shift;
    my $bat = shift;
    my $ev = new TPerl::Event(dbh=>$dbh);
    my $ADD_RECIPIENT = $ev->number('ADD_RECIPIENT');
    $bat = 0 if ($bat eq '');
    my $em = shift;
    my $tim = time();
    my $expires = $tim + $delta;
    my $sql = "INSERT INTO $SID (UID,PWD,STAT,FULLNAME,TS,EXPIRES,REMINDERS,BATCHNO,EMAIL) ";
    $sql .= ' VALUES (?,?,?,?,?,?,?,?,?)';
    my @params = ($uid,$pwd,0,$fullname,$tim,$expires,0,$bat,$em);
    if ($dbh->do($sql,{},@params)){
        $ev->I(SID=>$SID,who=>$ENV{REMOTE_USER},pwd=>$pwd,msg=>"Added $uid $fullname $em $pwd from batch $bat",code=>18);
        return 1;
    }else{
        $self->err({sql=>$sql,dbh=>$dbh,params=>\@params});
        return undef;
    }
}

# You need database row for a password.  No record is an error at time of writing.
# could be fixed.
sub db_get_pwd_full {
	my $self = shift;
	my $dbh = $self->dbh;
	my %args = @_;
	foreach (qw(SID pwd)){
		confess ("'$_' is a required arg") unless $args{$_};
	}
	my $SID = delete $args{SID};
	my $pwd = delete $args{pwd};
	if (my @bad = keys %args){
		confess ("Unrecognised args:'@bad'");
	}
	my $sql = "select * from $SID where PWD=?";
	my $params = [$pwd];
	my $row = $dbh->selectrow_hashref($sql,{},@$params);
	if ($row){
		if (keys %$row){
			return $row
		}else{
			$self->err("No record with pwd '$pwd' in '$SID'");
			return undef;
		}
	}else{
		$self->err( {sql=>$sql,params=>$params,dbh=>$dbh});
		return undef;
	}
}


1;
