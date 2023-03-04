package TPerl::CGI;
#$Id: CGI.pm,v 1.29 2007-08-23 00:41:53 triton Exp $
use strict;
use CGI;
use File::Basename;
use TPerl::LookFeel;
use vars qw(@ISA);
@ISA = qw (CGI);
use Data::Dump qw(dump);
use HTML::Entities;
use  Carp qw(confess);


$CGI::XHTML = 0;
# Rather than just nuking the DTD (which breaks some things), we should use a sanctioned DTD, viz:
# The HTML 4.01 Strict DTD includes all elements and attributes that have not been deprecated or do not appear in frameset documents.
#  	For documents that use this DTD, use this document type declaration:
# 	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
# The HTML 4.01 Transitional DTD includes everything in the strict DTD plus deprecated elements and attributes
# 	(most of which concern visual presentation). For documents that use this DTD, use this document type declaration:
# 	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
# The HTML 4.01 Frameset DTD includes everything in the transitional DTD plus frames as well.
# 	For documents that use this DTD, use this document type declaration:
# 	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">

# Frameset seems a reasonable choice here (as we still use them):
$CGI::DEFAULT_DTD = "-//W3C//DTD HTML 4.01 Frameset//EN";

# Lets do our own popup menu, so that we can do like mike does with a label etc.
# and you can click on the label.
sub tradio_group {
    my $self       = shift;
    my %args       = @_;
    my $name       = $args{-name};
    my $values     = $args{ -values };
    my $labels     = $args{-labels};
    my $default    = $args{-default};
    my $override   = $args{-override};
    my $rows       = $args{rows};
    my $columns    = $args{columns};
    my $rowheaders = $args{rowheaders};
    my $colheaders = $args{colheaders};
    my $onclick    = $args{-onClick};

    my @elements = ();
    my $count    = 1;
    my $radio_checked;

    my %checked = $self->previous_or_default( $name, $default, $override );
    # print $self->dumper($self);
    $checked{ $values->[0] }++ unless %checked;
    # print $self->dumper(\%checked);

    foreach my $val (@$values) {
        my $lab = $val;
        $lab = $labels->{$val}
          if defined($labels) && defined( $labels->{$val} );

# This is a hack to let people close there own labels, if say you want to put a text box into
# the label, and you want people to be able to type into it in early versions of IE....
# it then does not leave spare closing </labels> around...
        my $clabel = '</label>';
        $clabel = '' if $lab =~ /<\/label>/i;
        my $checked = ( $checked{$val} && !$radio_checked++ );
        $checked = 'CHECKED' if $checked;
        my $onclick_str = qq{onclick="$onclick"}
          if $onclick
          ; # in the future lets have a hash with different onclicks for each option....
        push @elements,
qq{<input type="radio" name="$name" $checked id="$name$count" value="$val" $onclick_str><label for="$name$count">$lab$clabel};
        $count++;
    }
    return wantarray ? @elements : join( "\t\n", @elements )
      unless defined($rows) || defined($columns);
    return _tableize( $rows, $columns, $rowheaders, $colheaders, @elements );
}

sub dumper {
    my $self  = shift;
    my $thing = shift;
    my $title = shift;
    return join "\n", $title, '<PRE>', dump($thing), '</PRE>';
}

sub args {
    my $self  = shift;
    my @names = $self->param();
    my %args  = ();
    foreach my $p (@names) {
        if ( my $upload = $self->upload($p) ) {
            $args{$p} = $upload;
        } else {
            my $ref = $self->param_fetch($p);
            if ( $#$ref == 0 ) {
                $args{$p} = $ref->[0] if $#$ref == 0;
            } else {
                $args{$p} = $ref;
            }
        }
    }
    return %args;
}

sub env {
    return join '', map "\n<BR>$_=$ENV{$_}", sort keys %ENV;
}

sub dir_redirect {
    my $self = shift;
    # Allow this to be run from command line.
    my $loc = shift || $ENV{SCRIPT_NAME} || $0;
    $loc = dirname($loc) . '/';
    return $self->redirect($loc);
}

sub tld {
    my $self = shift;
    my $loc  = '/cgi-adm';
    $loc = '/' . ( split /\//, $ENV{SCRIPT_NAME} )[1]
      if exists $ENV{SCRIPT_NAME};
    return $loc;
}

sub style {
    my $self   = shift;
    my $SID    = shift;
    my $server = '';
 # $server = "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}/" if $ENV{SERVER_NAME};
    return { src => "/$SID/style.css" }
      if $SID && -e "$ENV{DOCUMENT_ROOT}/$SID/style.css";
    return { src => $server . $self->tld . '/style.css' };
}

sub adm_style {
    my $self = shift;
    my $SID  = shift;
    ### but the cgi-adm is an alias not a fs link
    foreach my $lnk ( "/$SID/admstyle.css", $self->tld . '/admstyle.css' ) {
        return { src => $lnk } if -e "$ENV{DOCUMENT_ROOT}$lnk";
    }
    return $self->style($SID);
}

sub dberr {
    my $self = shift;
    my %args = @_;
    # return $self->dumper(\%args);
    my $sql = $args{sql};
    my $dbh = $args{dbh};
    my $err = $args{err};
    $err ||= $dbh->errstr() if $dbh;
    # return $self->dumper ({err=>$err});
    my $params = $args{params};

    my $lf = new TPerl::LookFeel;
    return join "\n", $lf->sbox('Database Error'), "<BR>sql<PRE>$sql</PRE>",
      "<BR>The Error<PRE>$err</PRE>", $self->dumper( $params, 'the params' ),
      $lf->ebox;
}

sub err {
    my $self = shift;
    my $err  = shift;
    # die $self->dumper ($err);
    my %args  = @_;
    my $title = $args{title} || 'Error';
    my $lf    = $args{lf} || new TPerl::LookFeel;
    if ( my $type = ref($err) ) {
        if ( ( $type eq 'HASH' ) and ( $err->{sql} ) ) {
            return $self->dberr( %args, %$err );
        } else {
            return $self->err( $self->dumper($err), %args );
        }
    } else {
        return join "\n", $lf->sbox($title), "<p>$err</p>", $lf->ebox;
    }
}

sub mydie {
    my $self  = shift;
    my $err   = shift;
    my %args  = @_;
    my $title = $args{title} || 'Error';
    unless ( $self->{".header_printed"} ) {
        print $self->header,
          $self->start_html(
            -style => { src => 'style.css' },
            -title => $title
          );
    }
    print $self->err( $err, %args );
    exit;
}

sub msg {
    my $self  = shift;
    my $msg   = shift;
    my %args  = @_;
    my $title = $args{title} || 'Message';
    my $lf    = $args{lf} || new TPerl::LookFeel;
    return join "\n", $lf->sbox($title), "<p>$msg</p>", $lf->ebox;
}

sub noSID {
    my $self   = shift;
    my %args   = @_;
    my $lf     = $args{lf} || new TPerl::LookFeel;
    my $style  = $args{style} || $self->style;
    my $msg    = $args{msg} || 'You must supply an SID';
    my $title  = $args{title} || $msg;
    my $btitle = $args{btitle} || 'Sorry';

    return join "\n", $self->header,
      $self->start_html( -style => $style, -title => $title ),
      $lf->sbox($btitle), $msg, $lf->ebox, $self->end_html;

}

sub frameset {
    my $self = shift;
    my %args = @_;

    my $title    = $args{title};
    my $noheader = $args{noheader};

    my $top_height = $args{top_height} || 135;
    my $left_width = $args{left_width} || 200;

    my $top_name   = $args{top_name}   || 'top';
    my $left_name  = $args{left_name}  || 'left';
    my $right_name = $args{right_name} || 'right';

    my ( $top_src, $left_src, $right_src );
    $top_src = $args{top_src};
    $top_src ||= $ENV{SCRIPT_NAME} . '/top' if $ENV{SCRIPT_NAME};
    $top_src ||= 'top.html';
    $left_src = $args{left_src};
    $left_src ||= $ENV{SCRIPT_NAME} . '/left' if $ENV{SCRIPT_NAME};
    $left_src ||= 'left.html';
    $right_src = $args{right_src};
    $right_src ||= $ENV{SCRIPT_NAME} . '/right' if $ENV{SCRIPT_NAME};
    $right_src ||= 'right.html';

    my $top_qs   = $args{top_qs}   || $args{qs};
    my $left_qs  = $args{left_qs}  || $args{qs};
    my $right_qs = $args{right_qs} || $args{qs};

    my @bits = ();
    push @bits, $self->header unless $noheader;
    push @bits, qq{
<HTML>
<HEAD>
<TITLE>$title</TITLE>
</HEAD>
<FRAMESET ROWS="$top_height,*" NORESIZE BORDER="0">
	<FRAME NAME="$top_name" SRC="$top_src$top_qs" >
	<FRAMESET COLS="$left_width,*"  BORDER="2">
		<FRAME NAME="$left_name" SRC="$left_src$left_qs" BORDER="0" >
		<FRAME NAME="$right_name" SRC="$right_src$right_qs" BORDER="0">
	</FRAMESET>
</FRAMESET>
<NOFRAMES>
		Your browser does not support frames. Please click <A HREF="$left_src$left_qs" >here </A> to continue
</NOFRAMES>
</HTML>
};

    return join "\n", @bits;
}

sub sdiff2html {
    my $self = shift;
    my %args = @_;

    my $sdiff = $args{sdiff};
    my $titles = $args{titles} || [];

    my $html = [];
    push @$html, '<table border="1">';
    push @$html,
      qq{<tr><th>type</th><th>$titles->[0]</th><th>$titles->[1]</th></tr>}
      if @$titles;
    foreach my $line (@$sdiff) {
        my $e1 = encode_entities( $line->[1] );
        my $e2 = encode_entities( $line->[2] );
        if ( $line->[0] eq 'u' ) {
            push @$html,
qq{<tr><td>$line->[0]</td><td class="present" colspan="2">$e1</td></tr>};
        } elsif ( $line->[0] eq 'c' ) {
            push @$html,
qq{<tr><td>$line->[0]</td><td class="missing">$e1</td><td class="missing">$e2</td></tr>};
        } elsif ( $line->[0] eq '+' ) {
            push @$html,
qq{<tr><td>$line->[0]</td><td class="missing">$e1</td><td class="missing">$e2</td></tr>};
        } elsif ( $line->[0] eq '-' ) {
            push @$html,
qq{<tr><td>$line->[0]</td><td class="missing">$e1</td><td class="missing">$e2</td></tr>};
        } else {
            die "Go and read man Algorithm::Diff";
        }
    }
    push @$html, '</table>';
    return join "\n", @$html;

}

sub sortable2list {
	my $self = shift;
	my $arg = shift;

	confess( "Unrecognised args:" . dump( \@_)) if @_;

	# scriptaculous serialises stuff so the arg for view_id 2 looks like
	# list_2[]=2_item_22&list_2[]=2_item_23&list_2[]=2_item_24&list_2[]=2_item_25&list_2[]=2_item_29
	my @kv=split '&',$arg;
	map s/^.*=item_//,@kv;
	return \@kv;
}
1;
