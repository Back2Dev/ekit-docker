package TPerl::CmdLine::Execute;
use Carp;
use vars qw( $AUTOLOAD);

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self = {};
	bless $self,$class;
	return $self;
}
sub output {
	#nice format that is easily scanable in a log file
	# stdout indented 2 space,
	# stderr intented by 1
	my $self = shift;
	my $out = $self->time ;
    $out .= ' in ' . $self->dir if $self->dir;
	$out.= "\n" . $self->cmd."\n";

	if (my $o=$self->stdout){
		chomp $o;
		$o="  $o";
		$o =~ s/(\n)/$1  /gm;
		$out.="$o\n";
	}
	if (my $e=$self->stderr){
		chomp $e;
		$e=" $e";
		$e =~ s/(\n)/$1 /gm;
		$out.="$e\n";
	}
	return $out;
}
sub AUTOLOAD {
	my $self = shift;
	my $name = $AUTOLOAD;
	$name =~ s/.*://;
	$name = 'success' if $name eq 'sucess';
	unless (grep $name eq $_,qw (dir stderr stdout cmd success time error)){
		print "Can't access '$name' method in class $type";
	}
	if (@_){
		return $self->{$name} = shift;
	}else{
		return $self->{$name};
	}
}
sub DESTROY {}

package TPerl::CmdLine;
use strict;
use File::Slurp;
use File::Temp qw(tempfile);
use FileHandle;
use Cwd;

=head1 SYNOPSIS

	use strict;
	use TPerl::CmdLine;
	my $cmdl = new TPerl::CmdLine;
	my $exec = $cmdl->execute(cmd=>'grep -r kayak /etc');
	printf "sucess %s\n", $exec->sucess;
	printf "stderr %s\n", $exec->stderr;
	printf "stdout %s\n", $exec->stdout;
	printf "cmd %s\n", $exec->cmd;
	printf "time %s\n", $exec->time;

=head1 DESCRIPTION

In the cook book recipe 16.7 it says the safest way to read STDERR and 
STDOUT is to shell redirect them to seperate files and read from these later

this is what we do here

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto ||$ proto;
	my $self = {};
	bless $self,$class;
	return $self;
}

sub execute {
	my $self = shift;
	my %args = @_;
	my $log = $args{log};
	my $dir = $args{dir};
	my $join_output = $args{join_output};

	my $olddir = cwd;

	my $fh;
	if ($log){
		$fh = new FileHandle (">> $log") or die "canna open '$log'";
	}
	my $ret = new TPerl::CmdLine::Execute;
	if ($dir){
		print $fh "Changing to $dir\n" if $log;
		$ret->dir($dir);
		unless (chdir $dir){
			$ret->success(0);
			$ret->stderr("cannot change dir to '$dir':$!");
			return $ret;
		}
	}
    if (my $cmd = $args{cmd}){
        my $success = 0;
        my ($efh,$efn) = tempfile ();
		my ($ofh,$ofn) = ($efh,$efn);
        ($ofh,$ofn) = tempfile () unless ($join_output);
		print $fh "start ".scalar(localtime)."\n" if $log;
        close $efh;close $ofh;
		print $fh "trying $cmd 1>$ofn 2>$efn\n" if $log;
		# print $fh "uid=".getpwuid()."\n" if $log;
		my $redircmd = "$cmd 1>$ofn 2>$efn";
		$redircmd = "$cmd >$ofn 2>&1" if $join_output;
        if (system ($redircmd) ==0 ){
            $success = 1;
        }else{
            $success = 0;
        }
		print $fh "done success=$success\n" if $log;
        my $err = read_file ($efn) unless $join_output;
        my $out = read_file ($ofn);
		print $fh "err=$err\n" if $log;
		print $fh "out=$out\n" if $log;
        # chomp $err; chomp $out;
        unlink($efn);
        unlink($ofn);
		$ret->stderr($err);
		$ret->stdout($out);
		$ret->cmd($cmd);
		$ret->success($success);
		$ret->time(scalar(localtime));
    }else{
		$ret->error('No cmd supplied')
    }
	chdir ($olddir) if $dir;
	return $ret;
}


# just a quicky for executeing and printing output.
sub output {
	my $self = shift;
	my $cmd = new TPerl::CmdLine;
	my $exec = $cmd->execute (@_);
	return $exec->output;
}
1;
