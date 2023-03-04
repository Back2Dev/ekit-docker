#!/usr/bin/perl
#$Id: previewemail3.pl,v 1.8 2012-08-05 11:11:30 triton Exp $
use strict;
use CGI::Carp qw(fatalsToBrowser);
use warnings;
use TPerl::CGI;
use TPerl::Sender;
use TPerl::Upload;
use TPerl::TritonConfig;
use TPerl::Sender;
use TPerl::Engine;
use TPerl::LookFeel;
use HTML::Entities;
use File::Basename;

use Config::IniFiles;

my $q    = new TPerl::CGI;
my %args = $q->args;
my $SID  = $args{SID} || $q->mydie("No SID");

my $troot = getConfig("TritonRoot");
my $up = new TPerl::Upload( SID => $SID, troot => $troot );

my $pini;
if (-e $up->uploadcsv_filename){
	$pini = $up->parse_uploadini() || $q->mydie( $up->err );
}

# If the file actually exists, then we get upset with any errors.
# otherwise we go on and deal with the errors in the 'default'
if ( -e $up->uploadini_filename ) {
    $q->mydie( $pini->{errs} ) if @{ $pini->{errs} };
}

my $error_gumph = '';
my $lf          = new TPerl::LookFeel;

my $uploadini_chooser;
my $fn2format = {};

if ( $pini->{flags}->{template_is_format} ) {
    my $errs;
    my $tchoose = {};
    foreach my $f ( keys %{ $pini->{format_defns} } ) {
        my $inifn = $pini->{format_defns}->{$f}->{file};
        my $data  = $up->uploadcsv2data(
            file  => $inifn,
            extra => { password => 'password' }
        ) || $q->mydie( $up->err );
        $data->{email} = 'a@g.com'
          unless Email::Valid->address( $data->{email} );
        $data->{to} = $data->{email};
        my $thash = $pini->{email_files}->{$f};
        foreach my $type ( keys %$thash ) {
            my $fn = $thash->{$type}->{html}
              || $thash->{$type}->{plain}
              || $q->mydie(
                "Could not get plain or html for '$f' email of type '$type'");
            $fn2format->{ $thash->{$type}->{html} } = $f
              if $thash->{$type}->{html};
            $fn2format->{ $thash->{$type}->{plain} } = $f
              if $thash->{$type}->{plain};
            my $tsend = new TPerl::Sender( SID => $SID );
            my $tsargs = $tsend->deparse_file($fn) || $q->mydie( $tsend->err );
            $tsargs->{data} = $data;
            if ( $tsend->send_process(%$tsargs) ) {
                my $lan = "lang:$tsargs->{lang}" if $tsargs->{lang};
                $tchoose->{
                    join( '===', $f, $type, $tsargs->{name}, $tsargs->{lang} ) }
                  = "$pini->{format_vals}->{$f}-$type files:$tsargs->{name} $lan";
            }
            else {
                my $es = $tsend->err;
                $es = [$es] if ref($es) ne 'ARRAY';
                $errs->{$f}->{$type} = { es => $es, fn => $fn, %$tsargs };
            }
        }
    }
    if ($errs) {
        my $tab = '<table border="1">';
        foreach my $f ( keys %$errs ) {
            $tab .=
qq{<tr><td colspan="2" align="center" class="heading">Template '$f'</td></tr>};
            my $thash = $errs->{$f};
            foreach my $t ( keys %$thash ) {
                my $es   = $thash->{$t}->{es};
                my $lang = '';
                $lang = "lang=$thash->{$t}->{lang}" if $thash->{$t}->{lang};
                $tab .= sprintf(
                    '<tr><td>%s</td><td>%s</td></tr>',
                    "Type '$t' files:$thash->{$t}->{name}.* $lang",
                    '<ul>' . join( "\n", map "<li>$_", @$es ) . '</ul>'
                );
            }
        }
        $tab         .= '</table>';
        $error_gumph .= join "\n",
          $lf->sbox("Errors occured with some email templates."), 
		  $tab,
          $lf->ebox;
    }
    else {
        $error_gumph =
          "Checked all emails defined in upload.ini.  Everything is fine"
          if -e $up->uploadini_filename;
    }
    {
        my $lis = [ sort keys %$tchoose ];
        if (@$lis) {
            unshift @$lis, '';
            $tchoose->{''} = 'Please Select';
            $uploadini_chooser = "<br>OR "
              . $q->popup_menu(
                -values => $lis,
                -labels => $tchoose,
                name    => 'choose'
              ) . '<BR>';
        }
    }
} else {
	# $q->mydie( "I dunno what I'll do here, probably check every format with every template?");
}

# Process the args
#
my $template = $args{template} || '';
my $lang     = $args{lang};
my $format   = '';

# The template_choose can overwrite the 'basic' form.
if ( my $choose = $args{choose} ) {
    my $type = 'not used';
    ( $format, $type, $template, $lang ) = split '===', $choose;
}

my $tsend = new TPerl::Sender( SID => $args{SID}, lang => $lang );
if ($args{file} and $template eq '' ) {
    # make it easier to link in with upload_csv_file....
    if ( my $ret = $tsend->deparse_file( $args{file} ) ) {
        $template = $ret->{name};
        $lang = $ret->{lang};
    } else {
        $error_gumph .=  "Could not parse file=$args{file}";
        $error_gumph .=  $tsend->err;
    }
}



my $display = '';

if ( $template ne '' ) {
    $tsend->name($template);
    $tsend->template_load() || $q->mydie( $tsend->err );
    my $headers = $tsend->header_load() || $q->mydie( $tsend->err );

    my $html  = $tsend->html;
    my $plain = $tsend->plain;
    my $pwd   = $args{pwd};

    # we can also guess the format, if format_is_template is on, and if we are
    # editing something in a upload.ini
    $format = $fn2format->{ $tsend->filenames('html') };
    $format ||= $fn2format->{ $tsend->filenames('plain') };

    if ( $pwd || $format ) {
        my $data;
        if ($pwd) {
            my $en = new TPerl::Engine( SID => $SID, troot => $troot );
            $data = $en->u_read( $en->u_filename($pwd) )
              || $q->mydie( $en->err );
        }
        elsif ($format) {

 # ie only try and load the ini file, if the template and lang have not changed.
            my $inifn = $pini->{format_defns}->{$format}->{file};
            $data = $up->uploadcsv2data(
                file  => $inifn,
                extra => { password => 'PWD' }
            ) || $q->mydie( $up->err );

            # $q->mydie($data);
        }
        $data->{to} ||= $data->{email};
        $data->{to} = 'a@g.com' unless Email::Valid->address( $data->{to} );
        my $p = $tsend->send_process( data => $data )
          || $q->mydie( $tsend->err );
        $html    = $p->{html};
        $plain   = $p->{plain};
        $headers = {};
        my $cm = $p->{common_args};

        foreach my $h ( keys %$cm ) {
            next if grep $h eq $_, qw(smtp headers);
            $headers->{$h} = $cm->{$h} if defined( $cm->{$h} );
        }
    }
    $plain =~ s/\x0d\x0a/\x0a/g;
    $plain =~ s/\x0a/ <br>/g;
    my $head = join "\n", '<blockquote>', $lf->sbox('Headers'),
      $lf->stbox( [] );
    foreach my $h ( keys %$headers ) {
        $head .= $lf->trow( [ $h, encode_entities( $headers->{$h} ) ] );
    }
    $head .= $lf->etbox() . $lf->ebox() . '</blockquote>';
    $display = join "\n", '<hr>', $head,
      '<table border="1" width="90%" cellpadding="10" align="center">',
      '<tr><td class="heading">',
      'The message below is a HTML formatted email message, which is close to
	  what the recipient will see in their email program when they read this
	  message. The message is sent as a multi-part message, meaning that a
	  PLAIN TEXT version is sent as well as the HTML version. The PLAIN TEXT
	  version appears after the HTML version.',, '</td></tr><tr><td>', 
	  $html,
      '</td></tr></table>', '<hr>','<table width="90%" border="1" align="center">',
	  '<tr><td class="heading">',
	  'The text below is the PLAIN TEXT version of the email. It is formatted
	  in a fixed width font, to make it representative of how it would be
	  viewed by a text-only email program. Any hyperlinks or email addresses in
	  the message do not appear as clickable links here, but it is usual for
	  the text based email program to interpret them correctly, and to make
	  them cickable.',
      '</td></tr><tr><td><font face="Courier new">', $plain, '</pre></td></tr></table>';
}

my $template_chooser = 'No templates exist';
{
    my $l = $tsend->template_list || $q->mydie( $tsend->err );
    if (@$l) {
        $template_chooser = join "\n",
          $q->popup_menu(
            -name   => 'template',
            -values => $tsend->template_list
          ),
          $q->popup_menu(
            -name   => 'lang',
            -values => [qw(en fr sp)],
            -labels => { en => 'English', sp => 'Spanish', fr => 'French' }
          ),
          "Password:" . $q->textfield( -name => 'pwd', -value => $args{pwd} );
    }
}

print join "\n", $q->header,
  $q->start_html(
#    -style => { src => "/$SID/style.css" },
    -title => "Email preview $SID"
  ),
  $q->start_form(), $q->hidden( -name => 'SID', -value => $SID ),
  $template_chooser, $uploadini_chooser, $q->submit('Load'), $q->end_form,

  # $q->dumper( \%args ),
  # #$q->dumper($pini),
  $error_gumph, $display, $q->end_html;
