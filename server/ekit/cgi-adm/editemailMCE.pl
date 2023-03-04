#!/usr/bin/perl
#$Id: editemailMCE.pl,v 1.3 2007-06-12 23:47:17 triton Exp $
use strict;
use CGI::Carp qw (fatalsToBrowser);
use TPerl::CGI;
use TPerl::Engine;
use TPerl::Sender;
use File::Slurp;
use TPerl::TritonConfig;
use File::Basename;
use TPerl::Parser;
use TPerl::LookFeel;
use HTML::TokeParser;
use HTML::Entities;

my $q     = new TPerl::CGI;
my %args  = $q->args;
my $en    = new TPerl::Engine;
my $troot = getConfig('TritonRoot');
my $lf    = new TPerl::LookFeel;

my $SID   = $args{SID};
my $plain = delete $args{plain};
my $html  = delete $args{html};

my $template = $args{template};
$template = $args{other_template} if $args{template_type} eq 'other';
$template =~ s/\s//g;
my $language = $args{language};

my @errors = ();

my $tsender = new TPerl::Sender( SID => $SID );

if ( $args{file} and $template eq '' ) {
    # make it easier to link in with upload_csv_file....
    if ( my $ret = $tsender->deparse_file( $args{file} ) ) {
        $template = $ret->{name};
        $language = $ret->{lang};
    } else {
        push @errors, "Could not parse file=$args{file}";
        push @errors, $tsender->err;
    }
}

# These are the header that get there own boxes.  Others get put into a
# textarea
my $header_boxes = [qw(subject from_email from_name)];

if ( $template ne '' ) {
    $tsender->name($template);
    $tsender->lang($language);
    if ( $args{save} || $args{saveandconvert} ) {
        my $hostroot = getConfig('HostRoot')
          || $q->mydie("Could not get HostRoot from getConfig");

        # cvs import before we saved, incase something else changed these files.
        $tsender->cvs_import( hostroot => $hostroot )
          || $q->mydie( $tsender->err );
	my $syle = read_file("$troot/$SID/html/style.css") if -e "$troot/$SID/html/style.css";
        $tsender->html(
            join "\n",
            $q->start_html(
                -style => {
                    -verbatim =>$syle,
                },
                -class => 'body',
            ),
            $html,
            $q->end_html
        );
        if ( $args{saveandconvert} ) {
            $plain = '';
            my $p     = new HTML::TokeParser( \$html );
            my $in    = {};
            my $href  = undef;
            my $newtr = undef;
            while ( my $t = $p->get_token ) {
                if ( $t->[0] eq 'S' ) {
                    $in->{ $t->[1] }++ unless $t->[2]->{'/'};
                    $newtr++ if $t->[1] eq 'tr';
                    if ( grep $t->[1] eq $_, qw(br tr) ) {
                        $plain .= "\n";
                    }
                    elsif ( $t->[1] eq 'td' ) {
                        if ($newtr) {
                            undef $newtr;
                        }
                        else {
                            $plain .= ' ';
                        }
                    }
                    elsif ( $t->[1] eq 'p' ) {
                        $plain .= "\n\n";
                    }
                    elsif ( $t->[1] eq 'a' ) {
                        $href = { S => $t };
                    }
                }
                elsif ( $t->[0] eq 'T' ) {
                    $t->[1] =~ s/\[%banner%]//g;
                    $t->[1] = decode_entities( $t->[1] );
                    $t->[1] =~ s/^\s*(.*?)\s*$/$1/s;

                    # print 'in'.Dumper $in;
                    if ( $in->{a} ) {
                        $href->{T} .= $t->[1];
                    }
                    else {
                        $plain .= $t->[1];
                    }
                }
                elsif ( $t->[0] eq 'E' ) {
                    if ( $in->{a} ) {
                        if ( $href->{T} =~ /$href->{S}->[2]->{href}/ ) {
                            $plain .= "$href->{T}\n";
                        }
                        else {
                            $plain .= "$href->{T}\n$href->{S}->[2]->{href}";
                        }
                    }
                    $in->{ $t->[1] }--;
                }
            }

        }
        $tsender->plain($plain);
        unless ( $tsender->template_save ) {
            push @errors, "Problem with saving:" . $tsender->err;
        }

        # Do header save.
        my $heads = {};

        foreach my $line ( split "\n", $args{other_headers} ) {
            next if $line =~ /^\s*$/;
            if ( my ( $k, $v ) = $line =~ /^\s*(\S*?)\s*=\s*(.*?)\s*$/ ) {
                $heads->{$k} = $v;
            }
            else {
                push @errors, "Ignoring header line '$line'";
            }
        }
        foreach my $b (@$header_boxes) {
            $heads->{$b} = $args{$b} if $args{$b} ne '';
        }
        $tsender->headers($heads);

        unless ( $tsender->header_save ) {
            push @errors, "Problem with saving headers:" . $tsender->err;
        }

        # cvs import after we've saved.
        $tsender->cvs_import( hostroot => $hostroot )
          || $q->mydie( $tsender->err );
    }
}

my $headers = {};

if ( $tsender->name() ) {
    if ( $tsender->template_load() ) {
        $html = $tsender->html;
        unless ( $html =~ s#^.*<body[^<]*>(.*)</body>.*$#$1#si ) {
            $html = '';
            push @errors, "No 'body' tags in html version";
        }
        $plain = $tsender->plain;
    }
    else {
        push @errors, $tsender->err;
    }
    if ( $headers = ( $tsender->header_load ) ) {
    }
    else {
        $headers = {};
        push @errors, $tsender->err;
    }
}

my $oth_head_list;
foreach my $h ( sort keys %$headers ) {
    next if grep lc($h) eq lc($_), @$header_boxes;
    push @$oth_head_list, $h;
}

print join "\n", $q->header, $q->start_html(
    -title  => 'EditEmail with TinyMCE',
    -script => [
        { -src => '/tinymce/jscripts/tiny_mce/tiny_mce.js' },
        {

            # Make sure the init does not have a comma on the last line, or it
            # breaks in IE and opera.
            #
            # Need the 'theme_advanced_path_location' for the resize button to
            # appear.
            -code => qq{
				tinyMCE.init({
					mode : "exact",
					elements : "html",
					theme	:	"advanced",
					content_css : "/$SID/style.css",
					apply_source_formatting : true,
					theme_advanced_disable : "anchor",
					theme_advanced_toolbar_location : "top",
					theme_advanced_toolbar_align : "left",
					theme_advanced_buttons1_add : "fontsizeselect",
					theme_advanced_resize_horizontal : false,
					theme_advanced_statusbar_location : "bottom",
					theme_advanced_path : false ,
					theme_advanced_resizing : true
				});
		}
        },
    ],
    -style => { src => "/$SID/style.css" },
  ),
  join( '<br>', map $q->err($_), @errors ),

  # $q->dumper( \%args ),
  # $q->dumper(\%ENV),
  $q->start_form, $q->popup_menu( -name => 'SID', -values => $en->SID_list ),
  $q->tradio_group(
    -name     => 'template_type',
    -values   => [ 'existing', 'other' ],
    -override => 1,
    -labels   => {
        existing => 'Template '
          . $q->popup_menu(
            -name     => 'template',
            -values   => $tsender->template_list,
            -default  => $template,
            -override => 1,
          ),
        other => 'Save As </label>' . $q->textfield(
            -name     => 'other_template',
            -override => 1,

        )
    }
  ),
  $q->popup_menu(
    -name     => 'language',
    -override => 1,
    -default  => $language,
    -values   => [qw(en fr sp)],
    -labels   => { en => 'English', sp => 'Spanish', fr => 'French' }
  ),
  '<br>', $q->submit( -value => 'Load' ), '<br>',
  $lf->stbox( [], head => 'Headers', colspan => 2 ),
  map ( $lf->trowl(
        [
            ucfirst($_),
            $q->textfield(
                -name    => $_,
                -value   => $headers->{$_},
                -size    => 80,
                override => 1
            )
        ]
    ),
    @$header_boxes ),
  $lf->trowl(
    [
        'Others',
        $q->textarea(
            -name    => 'other_headers',
            -default => join( '',
                map sprintf( "%s=%s\n", lc($_), $headers->{$_} ),
                @$oth_head_list ),
            -columns  => 80,
            -rows     => 2 + @$oth_head_list,
            -override => 1,
        )
    ]
  ),
  $lf->etbox(),
  $q->textarea(
    -name    => 'html',
    -default => $html,
    -id      => 'html',
    -style   => "width: 100%",
    rows     => 30,
    columns  => 100,
    override => 1
  ),
  $q->textarea(
    -name    => 'plain',
    -default => $plain,
    -style   => "width: 100%",
    rows     => 30,
    columns  => 100,
    override => 1
  ),
  '<br>', $q->submit( -value => 'Save both HTML and TEXT', -name => 'save' ),
  $q->submit(
    -value => 'Copy HTML to TEXT and Save both',
    -name  => 'saveandconvert'
  ),
  $q->end_form, $q->end_html;
