#Copyright Triton Technology 2002
#$Id: Inviter.pm,v 1.12 2004-12-15 12:06:04 triton Exp $
package TPerl::Survey::Inviter::File;
use strict;
use File::Basename;
use File::Slurp;
use TPerl::CmdLine;

our $AUTOLOAD;
use Carp;
sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;
	return $self;
}
sub AUTOLOAD {
	my $self = shift;
	my $name = $AUTOLOAD;
	$name =~ s/.*://;
	my $type = ref $self;

	my @methods = qw(upload tabs file order param multi stat);
	if (grep $name eq $_,@methods){
		return $self->{"_$name"} = shift if @_;return  $self->{"_$name"};
	}else{
		croak "Can't access '$name' method in class $type"
	}
}
sub active_files {
	my $self = shift;
	my %args = @_;

	my $atleast  = $args{atleast};
	
	my %files = ();
	my $dir = dirname ($self->file);
	# print "dir=$dir\n";
	if ($self->multi){
		my $found = 0;
		foreach my $f (read_dir($dir)){
			$f = "$dir/$f";
			my $match = $self->file;
			if (my ($end) = $f=~ /^$match(\d+)$/){
				$files{$end} = {file=>$f};
			}
		}
		for (1..$atleast){
			$files{$_} = {file=>$self->file.$_};
		}
	}else{
		if ($atleast){
			$files{1} = {file=>$self->file};
		}else{
			$files{1} = {file=>$self->file} if -e $self->file;
		}
	}
	foreach my $num (keys %files){
		$files{$num}->{exists} = -e $files{$num}->{file};
		my $cmd = "wc -l $files{$num}->{file}";
		my $exec = TPerl::CmdLine->execute(cmd=>$cmd);
		if ($exec->success){
			my $out = $exec->stdout;
			my ($c) = $exec->stdout =~ /(\d+)/;
			$files{$num}->{lines} =$c;
		}
		$files{$num}->{basename}=basename($files{$num}->{file});
		my @stat = stat($files{$num}->{file});
		$files{$num}->{stat}= \@stat;
	}
	return \%files;
}

package TPerl::Survey::Inviter;

=head1 SYNOPSIS

These are server side inviter functions.  Basically for finding files  
and versions on the filesystem, and returning nice lists.

 use TPerl::Survey;
 use TPerl::Survey::Inviter;
 my $s = new TPerl::Survey ('GOOSE123');
 my $i = new TPerl::Survey::Inviter ($s);
 my $batches = $i->broadcast->active_files;

 # $batches may then look something like
 { 
  "1"  => {
            basename => "broadcast1",
            "exists" => 1,
            file     => "/home/vhosts/mike/triton/
				REA201/config/broadcast1",
            info     => { bad => 3, good => 997 },
            lines    => 1001,
            "stat"   => [
                          770,
                          212_787,
                          33_188,
                          1,
                          500,
                          500,
                          0,
                          54_602,
                          "1027660898",
                          "1023385819",
                          "1026767322",
                          4096,
                          120,
                        ],
          },
  "10" => {
            basename => "broadcast10",
            "exists" => 1,
	....}

which is useful for building webforms and such.

Along with broadcast there are also methods for prototype pilot config.
The invites and reminders are similar, but return a list.

 my ($plain,$html) = $i->invites;
 my $pl_files = $plain->active_files;

=cut

use strict;
use Carp qw (confess);
use MIME::Entity;
use TPerl::Error;
use Data::Dumper;
use FileHandle;
sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;

	my $survey = shift;
	confess "This is useless without a TPerl::Survey. make sure its the first param" unless
		ref ($survey) eq 'TPerl::Survey';
	$self->{_survey} = $survey;
	return $self;
}

sub survey {
	my $self = shift;
	return $self->{_survey};
}

sub build_invite_templates{
	my $self = shift;
	my %args = @_;
	my $err = $args{err} || new TPerl::Error();
	my ($plain,$html) = $self->invites;

	my $active = undef;
	$active->{plain} = $plain->active_files;
	$active->{html} = $html->active_files;

	my %nums = ();
	
	$nums{$_}++ foreach keys %{$active->{plain}};
	$nums{$_}++ foreach keys %{$active->{html}};

	foreach my $num (keys %nums){
		my $ent = build MIME::Entity ( Type=>'multipart/alternative',
									   From=>'"<%sponsor%>" <<%from_email%>>',
									   To=>'<%email%>',
									   'Reply-to'=>'<%from_email%>',
									   'X-Mailer'=>'Triton Mail Client',);
		if (-e $active->{plain}->{$num}){
			$ent->attach(Type=>'text/plain',Path=>$active->{plain}->{$num}) ;
		}else{
			$err->W("No plain for inivte $num ($active->{plain}->{$num})");
		}
		if (-e $active->{html}->{$num}){
			$ent->attach(Type=>'text/html',Path=>$active->{html}->{$num});
		}else{
			$err->W("No html for inivte $num ($active->{html}->{$num})");
		}
		my $file = join ('/',$self->survey->TR,$self->survey->SID,'config',"invitation$num");
		$nums{$num} = $file;
		if (my $fh = new FileHandle "> $file"){
			print "writing to $file\n";
			$ent->print($fh);
		}else{
			$err->E("Could not open $file:$!");
		}
	}
	return \%nums;
}

sub reminders {
	my $self = shift;
	my $s = $self->survey;
	my $plain = new TPerl::Survey::Inviter::File;
	my $html = new TPerl::Survey::Inviter::File;
	$plain->order(7);
	$html->order(8);
	$plain->multi(1);
	$html->multi(1);
	$plain->file ( join('/',$s->TR,$s->SID,'config','reminder-plain'));
	$html->file ( join('/',$s->TR,$s->SID,'config','reminder-html'));
	return $plain,$html;
}
sub invites {
	my $self = shift;
	my $s = $self->survey;
	my $plain = new TPerl::Survey::Inviter::File;
	my $html = new TPerl::Survey::Inviter::File;
	$plain->order(5);
	$html->order(6);
	$plain->multi(1);
	$html->multi(1);
	$plain->file ( join('/',$s->TR,$s->SID,'config','invitation-plain'));
	$html->file ( join('/',$s->TR,$s->SID,'config','invitation-html'));
	return $plain,$html;
}
sub config {
	my $self = shift;
	my $s = $self->survey;
	my $file = new TPerl::Survey::Inviter::File;
	$file->file (join('/',$s->TR,$s->SID,'config','params.ini'));
	$file->order(1);
	return $file;
}
sub broadcast {
	my $self = shift;
	my $s = $self->survey;
	my $file = new TPerl::Survey::Inviter::File;
	$file->file (join('/',$s->TR,$s->SID,'config','broadcast'));
	$file->order(3);
	$file->upload(1);
	$file->tabs('|');
	$file->multi(1);
	return $file;
}

sub pilot {
	my $self = shift;
	my $s = $self->survey;
	my $file = new TPerl::Survey::Inviter::File;
	$file->file (join('/',$s->TR,$s->SID,'config','pilot'));
	$file->order(2);
	$file->tabs('|');
	return $file;
}
sub prototype {
	my $self = shift;
	my $s = $self->survey;
	my $file = new TPerl::Survey::Inviter::File;
	$file->file (join('/',$s->TR,$s->SID,'config','prototype'));
	$file->order(2);
	$file->tabs('|');
	return $file;
}
sub examine_batch_file {
	my $self = shift;
	my $file = shift || confess 'First Param must be a file name';
	my %args = @_;
	my $email_col = $args{email_col} || 'email';
	if (my $fh = new FileHandle $file){
		my ($good,$count) = (0,0);
		$_ = <$fh>;
		chomp;
		$_ = lc($_);
		my @head = split /\t/,$_;
		s/^\s*(.*?)\s*$/$1/ foreach @head;
		if (grep $_ eq $email_col,@head){
				while (my $line = <$fh>){
						chomp $line;
						my %line = ();
						my @line = split /\t/,$line;
						s/^\s*(.*?)\s*$/$1/ foreach @line;
						@line{@head} = @line;
						# print "email = |$line{$email_col}|";
						$good++ if Email::Valid->address ($line{$email_col});
						$count++;
				}
				my $bad = $count-$good || '0';
				return {good=>$good,bad=>$bad}
		}else{
				return {err=>"Did not find an email column called '$email_col'"};
		}
	}else{
			return {err=>"Could not open '$file':$!"} ;
	}
}

1;
