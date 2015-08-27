
=head1 NAME

App::Basis::ConvertText2

=head1 SYNOPSIS

To be used in conjuction with the supplied ct2 script, which is part of this distribution.
Not really to be used on its own.

=head1 DESCRIPTION

This is a perl module and a script that makes use of %TITLE%

This is a wrapper for [pandoc] implementing extra fenced code-blocks to allow the
creation of charts and graphs etc.
Documents may be created a variety of formats. If you want to create nice PDFs
then it can use [PrinceXML] to generate great looking PDFs or you can use [wkhtmltopdf] to create PDFs that are almost as good, the default is to use pandoc which, for me, does not work as well.

HTML templates can also be used to control the layout of your documents.

The fenced code block handlers are implemented as plugins and it is a simple process to add new ones.

There are plugins to handle

    * ditaa
    * mscgen
    * graphviz
    * uml
    * gnuplot
    * gle
    * sparklines
    * charts
    * barcodes and qrcodes
    * and many others

See
https://github.com/27escape/App-Basis-ConvertText2/blob/master/README.md
for more information.

=head1 Todo

Consider adding plugins for

    * https://metacpan.org/pod/Chart::Strip
    * https://metacpan.org/pod/Chart::Clicker

Possibly create something for D3.js, though this would need to use PhantomJS too
https://github.com/ariya/phantomjs/blob/master/examples/rasterize.js
http://stackoverflow.com/questions/18240391/exporting-d3-js-graphs-to-static-svg-files-programmatically

=head1 Public methods

=over 4

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2 ;

use 5.10.0 ;
use strict ;
use warnings ;
use feature 'state' ;
use Moo ;
use Data::Printer ;
use Try::Tiny ;
use Path::Tiny ;
use Digest::MD5 qw(md5_hex) ;
use Encode qw(encode_utf8) ;
use GD ;
use MIME::Base64 ;
use Furl ;
# use Text::Markdown qw(markdown) ;
# use Text::MultiMarkdown qw(markdown) ;
# use CommonMark ;
use Text::Markdown qw(markdown) ;
use Module::Pluggable
    require          => 1,
    on_require_error => sub {
    my ( $plugin, $err ) = @_ ;
    warn "$plugin, $err" ;
    } ;
use App::Basis ;
use App::Basis::ConvertText2::Support ;
use utf8::all ;

# ----------------------------------------------------------------------------
# this contents string is to be replaced with the body of the markdown file
# when it has been converted
use constant CONTENTS => '_CONTENTS_' ;
use constant PANDOC   => 'pandoc' ;
use constant PRINCE   => 'prince' ;
use constant WKHTML   => 'wkhtmltopdf' ;

# ----------------------------------------------------------------------------

# http://www.fileformat.info/info/unicode/category/So/list.htm
# not great matches in all cases but best that can be done when there is no support
# for emoji's
my %smilies = (
    '<3'      => ":fa:heart",      # heart
    ':heart:' => ":fa:heart",      # heart
    ':)'      => ":fa:smile-o",    # smile
    ':smile:' => ":fa:smile-o",    # smile
                                   # ':D'           => "\x{1f601}",    # grin
                                   # ':grin:'       => "\x{1f601}",    # grin
                                   # '8-)'          => "\x{1f60e}",    # cool
                                   # ':cool:'       => "\x{1f60e}",    # cool
         # ':P'           => "\x{1f61b}",    # pull tounge
         # ':tongue:'     => "\x{1f61b}",    # pull tounge
         # ":'("          => "\x{1f62d}",    # cry
         # ":cry:"        => "\x{1f62d}",    # cry
    ':('      => ":fa:frown-o",    # sad
    ':sad:'   => ":fa:frown-o",    # sad
                                   # ";)"      => "\x{1f609}",    # wink
                                   # ":wink:"  => "\x{1f609}",      # wink
    ":sleep:" => ":fa:bed",        # sleep
    ":zzz:"   => ":ma:snooze",     # snooze
    ":snooze:" => ":ma:snooze",     # snooze
                                   # ":halo:"       => "\x{1f607}",    # halo
                                   # ":devil:"      => "\x{1f608}",    # devil
                                   # ":horns:"      => "\x{1f608}",    # devil
                                   # ":fear:"  => "\x{1f631}",      # fear
    "(c)"     => "\x{a9}",         # copyright
    ":c:"     => "\x{a9}",         # copyright
    ":copyright:"  => "\x{a9}",                       # copyright
    "(r)"          => "\x{ae}",                       # registered
    ":r:"          => "\x{ae}",                       # registered
    ":registered:" => "\x{ae}",                       # registered
    "(tm)"         => "\x{99}",                       # trademark
    ":tm:"         => "\x{99}",                       # trademark
    ":trademark:"  => "\x{99}",                       # trademark
    ":email:"      => ":fa:envelope-o",               # email
    ":yes:"        => "\x{2714}",                     # tick / check
    ":no:"         => "\x{2718}",                     # cross
    ":beer:"       => ":fa:beer:[fliph]",             # beer
    ":wine:"       => ":fa:glass",                    # wine
    ":glass:"      => ":fa:glass",                    # wine
    ":cake:"       => ":fa:birthday-cake",            # cake
    ":star:"       => ":fa:star-o",                   # star
    ":ok:"         => ":fa:thumbs-o-up:[fliph]",      # ok = thumbsup
    ":thumbsup:"   => ":fa:thumbs-o-up:[fliph]",      # thumbsup
    ":thumbsdown:" => ":fa:thumbs-o-down:[fliph]",    # thumbsdown
    ":bad:"        => ":fa:thumbs-o-down:[fliph]",    # bad = thumbsdown
         # ":ghost:"      => "\x{1f47b}",            # ghost
         # ":skull:"      => "\x{1f480}",            # skull 1f480
    ":time:"      => ":fa:clock-o",        # time, watch face
    ":clock:"     => ":fa:clock-o",        # time, watch face
    ":hourglass:" => ":fa:hourglass-o",    # hourglass
) ;

my $smiles = join( '|', map { quotemeta($_) } keys %smilies ) ;

# ----------------------------------------------------------------------------
# we want some CSS
my $default_css = <<END_CSS;
    /* -------------- ConvertText2.pm css -------------- */

    img {max-width: 100%;}
    /* setup for print */
    \@media print {
        /* this is the normal page style */
        \@page {
            size: %PAGE_SIZE%  %ORIENTATION% ;
            margin: 60pt 30pt 40pt 30pt ;
        }
    }

    /* setup for web */
    \@media screen {
        #toc a {
            text-decoration: none ;
            font-weight: normal;
        }

    }            

    table { page-break-inside: auto ;}
    table { page-break-inside: avoid ;}
    tr    { page-break-inside:avoid; page-break-after:auto }
    thead { display:table-header-group }
    tfoot { display:table-footer-group }

    /* toc */
    .toc {
        padding: 0.4em;
        page-break-after: always;
    }
    .toc p {
        font-size: 24;
    }
    .toc h3 { text-align: center }
    .toc ul {
        columns: 1;
    }
    .toc ul, .toc li {
        list-style: none;
        margin: 0;
        padding: 0;
        padding-left: 10px ;
    }
    .toc a::after {
        content: leader('.') target-counter(attr(href), page);
        font-style: normal;
    }
    .toc a {
        text-decoration: none ;
        font-weight: normal;
        color: black;
    }

    /* nice markup for source code */
    table.sourceCode, tr.sourceCode, td.lineNumbers, td.sourceCode {
        margin: 0; padding: 0; vertical-align: baseline; border: none;
    }
    table.sourceCode { width: 100%; line-height: 100%; }
    td.lineNumbers { text-align: right; padding-right: 4px; padding-left: 4px; color: #aaaaaa; border-right: 1px solid #aaaaaa; }
    td.sourceCode { padding-left: 5px; }
    code > span.kw { color: #007020; font-weight: bold; }
    code > span.dt { color: #902000; }
    code > span.dv { color: #40a070; }
    code > span.bn { color: #40a070; }
    code > span.fl { color: #40a070; }
    code > span.ch { color: #4070a0; }
    code > span.st { color: #4070a0; }
    code > span.co { color: #60a0b0; font-style: italic; }
    code > span.ot { color: #007020; }
    code > span.al { color: #ff0000; font-weight: bold; }
    code > span.fu { color: #06287e; }
    code > span.er { color: #ff0000; font-weight: bold; }

    \@page landscape {
        prince-rotate-body: 270deg;
    }
    .landscape {
        page: landscape;
    }

    body {
        font-family: sans-serif;
    }
    code {
        font-family: monospace;
    }

    /* we do not want these, headings start from h2 onwards */
    h1 {
        display: none;
    }

    li {
        padding-left: 0px;
        margin-left: -2em ;
    }

    /* enable tooltips on 'title' attributes when using PrinceXML */
    *[title] { prince-tooltip: attr(title) }

    .rotate-90 {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=1);
      -webkit-transform: rotate(90deg);
      -ms-transform: rotate(90deg);
      transform: rotate(90deg);
    }
    .rotate-180 {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=2);
      -webkit-transform: rotate(180deg);
      -ms-transform: rotate(180deg);
      transform: rotate(180deg);
    }
    .rotate-270 {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=3);
      -webkit-transform: rotate(270deg);
      -ms-transform: rotate(270deg);
      transform: rotate(270deg);
    }
    .flip-horizontal {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=0, mirror=1);
      -webkit-transform: scale(-1, 1);
      -ms-transform: scale(-1, 1);
      transform: scale(-1, 1);
    }
    .flip-vertical {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=2, mirror=1);
      -webkit-transform: scale(1, -1);
      -ms-transform: scale(1, -1);
      transform: scale(1, -1);
    }

    .border-grey {
        border-style: solid;
        border-width: 1px;
        border-color: grey300;
        box-shadow:inset 0px 0px 85px rgba(0,0,0,.5);
        -webkit-box-shadow:inset 0px 0px 85px rgba(0,0,0,.5);
        -moz-box-shadow:inset 0px 0px 85px rgba(0,0,0,.5);        
        box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.5);        
    }

    .border-inset-grey {
        border: 1px solid #666666;
        -webkit-box-shadow: inset 3px 3px 3px #AAAAAA;
        border-radius: 3px;
    }

    .border-shadow-grey {
        -moz-box-shadow: 3px 3px 4px #444;
        -webkit-box-shadow: 3px 3px 4px #444;
        box-shadow: 3px 3px 4px #444;
        -ms-filter: "progid:DXImageTransform.Microsoft.Shadow(Strength=4, Direction=135, Color='#444444')";
        filter: progid:DXImageTransform.Microsoft.Shadow(Strength=4, Direction=135, Color='#444444');    
    }

END_CSS

# ----------------------------------------------------------------------------
my $TITLE = "%TITLE%" ;

# ----------------------------------------------------------------------------

has 'name'    => ( is => 'ro', ) ;
has 'basedir' => ( is => 'ro', ) ;

has 'use_cache' => ( is => 'rw', default => sub { 0 ; } ) ;

has 'cache_dir' => (
    is      => 'ro',
    default => sub {
        my $self = shift ;
        # return "/tmp/" . get_program() . "/cache/" ;
        return "$ENV{HOME}/.cache/" ;
    },
    writer => "_set_cache_dir"
) ;

has 'template' => (
    is      => 'rw',
    default => sub {
        "<!DOCTYPE html'>
<html>
    <head>
        <title>$TITLE</title>
        %JAVASCRIPT%
        <style type='text/css'>
            \@page { size: A4 }
            %CSS%
        </style>
    </head>
    <body>
        <h1>%TITLE%</h1>

        %_CONTENTS_%
    </body>
</html>\n" ;
    },
) ;

has 'replace' => (
    is      => 'ro',
    default => sub { {} },
) ;

has 'verbose' => (
    is      => 'ro',
    default => sub {0},
) ;

has '_output' => (
    is       => 'ro',
    default  => sub {""},
    init_arg => 0
) ;

has '_input' => (
    is       => 'ro',
    writer   => '_set_input',
    default  => sub {""},
    init_arg => 0
) ;

has '_md5id' => (
    is       => 'ro',
    writer   => '_set_md5id',
    default  => sub {""},
    init_arg => 0
) ;

# ----------------------------------------------------------------------------

=item new

Create a new instance of a of a data formating object

B<Parameters>  passed in a HASH
    name        - name of this formatting action - required
    basedir     - root directory of document being processed
    cache_dir   - place to store cache files - optional
    use_cache   - decide if you want to use a cache or not
    template    - HTML template to use, must contain %_CONTENTS_%
    replace     - hashref of extra keywords to use as replaceable variables
    verbose     - be verbose

=cut

sub BUILD
{
    my $self = shift ;

    die "No name provided" if ( !$self->name() ) ;

    if ( $self->use_cache() ) {

        # need to add the name to the cache dirname to make it distinct
        $self->_set_cache_dir(
            fix_filename( $self->cache_dir() . "/" . $self->name() ) ) ;

        if ( !-d $self->cache_dir() ) {

            # create the cache dir if needed
            try {
                path( $self->cache_dir() )->mkpath ;
            }
            catch {} ;
            die "Could not create cache dir " . $self->cache_dir()
                if ( !-d $self->cache_dir() ) ;
        }
    }

    # work out what plugins do what
    foreach my $plug ( $self->plugins() ) {
        my $obj = $plug->new() ;
        if ( !$obj ) {
            warn "Plugin $plug does not instantiate" ;
            next ;
        }

        # the process method does the work for all the tag handlers
        if ( !$obj->can('process') ) {
            warn "Plugin $plug does not provide a process method" ;
            next ;
        }
        foreach my $h ( @{ $obj->handles } ) {
            $h = lc($h) ;
            if ( $h eq 'buffer' ) {
                die
                    "Plugin $plug cannot provide a handler for $h, as this is already provided for internally"
                    ;
            }
            if ( has_block($h) ) {
                die
                    "Plugin $plug cannot provide a handler for $h, as this has already been provided by another plugin"
                    ;
            }

            # all handlers are lower case
            add_block( $h, $obj ) ;
        }
    }

    # buffer is a special internal handler
    add_block( 'buffer', 1 ) ;
}

# ----------------------------------------------------------------------------

sub _append_output
{
    my $self = shift ;
    my $str  = shift ;

    $self->{output} .= $str if ($str) ;
}

# ----------------------------------------------------------------------------
# store a file to the cache
# if the contents are empty then any existing cache file will be removed
sub _store_cache
{
    my $self = shift ;
    my ( $filename, $contents, $utf8 ) = @_ ;

    # don't do any cleanup if we are not using a cache
    return if ( !$self->use_cache() ) ;

    # for some reason sometimes the full cache dir is not created or
    # something deletes part of it, cannot figure it out
    path( $self->cache_dir() )->mkpath if ( !-d $self->cache_dir() ) ;

    # make sure we are working in the right dir
    my $f = $self->cache_dir() . "/" . path($filename)->basename ;

    if ( !$contents && -f $f ) {
        unlink($f) ;
    } else {
        if ($utf8) {
            path($f)->spew_utf8($contents) ;
        } else {
            path($f)->spew_raw($contents) ;
        }
    }
}

# ----------------------------------------------------------------------------
# get a file from the cache
sub _get_cache
{
    my $self = shift ;
    my ( $filename, $utf8 ) = @_ ;

    # don't do any cleanup if we are not using a cache
    return if ( !$self->use_cache() ) ;

    # make sure we are working in the right dir
    my $f = $self->cache_dir() . "/" . path($filename)->basename ;

    my $result ;
    if ( -f $f ) {
        if ($utf8) {
            $result = path($f)->slurp_utf8 ;
        } else {
            $result = path($f)->slurp_raw ;
        }
    }

    return $result ;
}

# ----------------------------------------------------------------------------

=item clean_cache

Remove all files from the cache

=cut

sub clean_cache
{
    my $self = shift ;

    # don't do any cleanup if we are not using a cache
    return if ( !$self->use_cache() ) ;

    # try { path( $self->cache_dir() )->remove_tree } catch {} ;

    # # and make it fresh again
    # path( $self->cache_dir() )->mkpath() ;
    system( "rm -rf '" . $self->cache_dir() . "'/* 2>/dev/null" ) ;
}

# ----------------------------------------------------------------------------
# _extract_args
# get key=value data from a passed string
sub _extract_args
{
    my $buf = shift ;
    my ( %attr, $eaten ) ;
    return \%attr if ( !$buf ) ;

    while ( $buf =~ s|^\s?(([a-zA-Z][a-zA-Z0-9\.\-_]*)\s*)|| ) {
        $eaten .= $1 ;
        my $attr = lc $2 ;
        my $val ;

        # The attribute might take an optional value (first we
        # check for an unquoted value)
        if ( $buf =~ s|(^=\s*([^\"\'>\s][^>\s]*)\s*)|| ) {
            $eaten .= $1 ;
            $val = $2 ;

            # or quoted by " or '
        } elsif ( $buf =~ s|(^=\s*([\"\'])(.*?)\2\s*)||s ) {
            $eaten .= $1 ;
            $val = $3 ;

            # truncated just after the '=' or inside the attribute
        } elsif ( $buf =~ m|^(=\s*)$|
            or $buf =~ m|^(=\s*[\"\'].*)|s ) {
            $buf = "$eaten$1" ;
            last ;
        } else {
            # assume attribute with implicit value
            $val = $attr ;
        }
        $attr{$attr} = $val ;
    }

    return \%attr ;
}

# ----------------------------------------------------------------------------
# add into the replacements list
sub _add_replace
{
    my $self = shift ;
    my ( $key, $val ) = @_ ;

    $self->{replace}->{ uc($key) } = $val ;
}

# ----------------------------------------------------------------------------
sub _do_replacements
{
    my $self = shift ;
    my ($content) = @_ ;

    if ($content) {
        foreach my $k ( keys %{ $self->replace() } ) {
            next if ( !$self->{replace}->{$k} ) ;

            # in the text the variables to be replaced are surrounded by %
            # zero width look behind to make sure the variable name has
            # not been escaped _%VARIABLE% should be left alone
            $content =~ s/(?<!_)%$k%/$self->{replace}->{$k}/gsm ;
        }
    }

    return $content ;
}

# ----------------------------------------------------------------------------
sub _call_function
{
    my $self = shift ;
    my ( $block, $params, $content, $linepos ) = @_ ;
    my $out ;

    if ( !has_block($block) ) {
        debug( "ERROR:", "no valid handler for $block" ) ;
    } else {
        try {

         # buffer is a special construct to allow us to hold output of content
         # for later, allows multiple use of content or adding things to
         # markdown tables that otherwise we could not do

            # over-ride content with buffered content
            my $from = $params->{from} || $params->{from_buffer} ;
            if ($from) {
                $content = $self->{replace}->{ uc($from) } ;
            }

            # get the content from the args, useful for short blocks
            if ( $params->{content} ) {
                $content = $params->{content} ;
            }
            if ( $params->{file} ) {
                $content = _include_file("file='$params->{file}'") ;
            }

            my $to = $params->{to} || $params->{to_buffer} ;

            if ( $block eq 'buffer' ) {
                if ($to) {
                    $self->_add_replace( $to, $content ) ;
                }
            } else {
                # do any replacements we know about in the content block
                $content = $self->_do_replacements($content) ;

                # run the plugin with the data we have
                $out = run_block( $block, $content, $params,
                    $self->cache_dir() ) ;

                if ( !$out ) {

       # if we could not generate any output, lets put the block back together
                    $out .= "~~~~{.$block "
                        . join( " ",
                        map {"$_='$params->{$_}'"} keys %{$params} )
                        . " }\n"
                        . "~~~~\n" ;
                } elsif ($to) {

                    # do we want to buffer the output?
                    $self->_add_replace( $to, $out ) ;

                    # option not to show the output
                    $out = "" if ( $params->{no_output} ) ;
                }
            }
            # $self->_append_output("$out\n") if ( defined $out ) ;
        }
        catch {
            debug( "ERROR",
                "failed processing $block near line $linepos, $_" ) ;
            warn "Issue processing $block around line $linepos" ;
            $out
                = "~~~~{.$block "
                . join( " ", map {"$_='$params->{$_}'"} keys %{$params} )
                . " }\n"
                . "~~~~\n" ;
            # $self->_append_output($out) ;
        } ;
    }
    return $out ;
}

# ----------------------------------------------------------------------------
# handle any {{.tag args='11'}} type things in given text

sub _rewrite_short_block
{
    my $self = shift ;
    my ( $block, $attributes ) = @_ ;
    my $out ;
    my $params = _extract_args($attributes) ;

    if ( has_block($block) ) {
        return $self->_call_function( $block, $params, $params->{content},
            0 ) ;
    } else {
        # build the short block back together, if we do not have a match
        $out = "{{.block $attributes}}" ;
    }
    return $out ;
}

# ----------------------------------------------------------------------------
### _parse_lines
# parse the passed data
sub _parse_lines
{
    my $self      = shift ;
    my $lines     = shift ;
    my $count     = 0 ;
    my $curr_line = "" ;

    return if ( !$lines ) ;

    my ( $class, $block, $content, $attributes ) ;
    my ( $buildline, $simple ) ;
    try {
        foreach my $line ( @{$lines} ) {
            $curr_line = $line ;
            $count++ ;

            # header lines may have been removed
            if ( !defined $line ) {
           # we may want a blank line to space out things like indented blocks
                $self->_append_output("\n") ;
                next ;
            }

         # a short block is {{.tag arguments}}
         # or {{.tag}}
         # can have multiple ones on a single line like {{.tag1}} {{.tag_two}}
         # short tags cannot have the form
         # {{.class .tag args=123}}
         # replace all tags on this line
            $line
                =~ s/\{\{\.(\w+)(\b.*?)\}\}/$self->_rewrite_short_block( $1, $2)/egs
                ;

            if ( defined $simple ) {
                if ( $line =~ /^~{4,}\s?$/ ) {
                    $self->_append_output("~~~~\n$simple\n~~~~\n") ;
                    $simple = undef ;
                } else {
                    $simple .= "$line\n" ;
                }

                next ;
            }

# we may need to add successive lines together to get a completed fenced code block
            if ( !$block && $buildline ) {
                $buildline .= " $line" ;
                if ( $line =~ /\}\s*$/ ) {
                    $line = $buildline ;

                    # make sure to clear the builder
                    $buildline = undef ;
                } else {
                    # continue to build the line
                    next ;
                }
            }

            # a simple block does not have an identifying {.tag}
            if ( $line =~ /^~{4,}\s?$/ && !$block ) {
                $simple = "" ;
                next ;
            }

            if ( $line =~ /^~{4,}/ ) {

                # does the fenced line wrap before its ended
                if ( !$block && $line !~ /\}\s*$/ ) {

                    # we need to start adding lines till its completed
                    $buildline = $line ;
                    next ;
                }

                if ( $line =~ /\{(.*?)\.(\w+)\s*(.*?)\}\s*$/ ) {
                    $class      = $1 ;
                    $block      = lc($2) ;
                    $attributes = $3 ;
                } elsif ( $line =~ /\{\.(\w+)\s?\}\s*$/ ) {
                    $block      = lc($1) ;
                    $attributes = {} ;
                } else {
                    my $params = _extract_args($attributes) ;

                    # must have reached the end of a block
                    if ( has_block($block) ) {
                        chomp $content if ($content) ;
                        my $out = $self->_call_function( $block, $params,
                            $content, $count ) ;
                        # not all blocks output things, eg buffer operations
                        if ($out) {
       # add extra line to make sure things are spaced away from other content
                            $self->_append_output("$out\n\n") ;
                        }
                    } else {
                        if ( !$block ) {

                            # put it back
                            $content ||= "" ;
                            $self->_append_output(
                                "~~~~\n$content\n~~~~\n\n") ;

                        } else {
                            $content    ||= "" ;
                            $attributes ||= "" ;
                            $block      ||= "" ;

                            # put it back
                            $self->_append_output(
                                "~~~~{ $class .$block $attributes}\n$content\n~~~~\n\n"
                            ) ;
                        }
                    }
                    $content    = "" ;
                    $attributes = "" ;
                    $block      = "" ;
                }
            } else {
                if ($block) {
                    $content .= "$line\n" ;
                } else {
                    $self->_append_output("$line\n") ;
                }
            }
        }
    }
    catch {
        die "Issue at line $count $_ ($curr_line)" ;
    } ;
}

# ----------------------------------------------------------------------------
# fetch any img references and copy into the cache, if the image is already
# in the cache then nothing will happen, will rewrite other img uri's
sub _rewrite_imgsrc
{
    my $self = shift ;
    my ( $pre, $img, $post, $want_size ) = @_ ;
    my $ext ;
    if ( $img =~ /\.(\w+)$/ ) {
        $ext = $1 ;
    }

    if ($ext) {    # potentially image is already an embedded image
        if ( $img !~ /base64,/ && $img !~ /\.svg$/i ) {
            # if ( $img !~ /base64,/ ) {

            # if its an image we have generated then it may already be here
            # check to see if we have this in the cache
            my $cachefile = cachefile( $self->cache_dir, $img ) ;
            $cachefile =~ s/\n//g ;
            if ( !-f $cachefile ) {
                my $id = md5_hex($img) ;
                $id .= ".$ext" ;

                # this is what it will be named in the cache
                $cachefile = cachefile( $self->cache_dir, $id ) ;

                # not in the cache , fetch it and store it local to the cache
                # if we are a local file
                if ( $img !~ m|^\w+://| || $img =~ m|^file://| ) {
                    $img =~ s|^file://|| ;
                    $img = fix_filename($img) ;

                    if ( $img !~ m|/| ) {

                        # if file is relative, then we need to add the basedir
                        $img = $self->basedir . "/$img" ;
                    }

                    # copy it to the cache location
                    try {
                        path($img)->copy($cachefile) ;
                    }
                    catch {
                        debug( "ERROR",
                            "failed to copy $img to $cachefile" ) ;
                    } ;

                    $img = $cachefile if ( -f $cachefile ) ;
                } else {
                    if ( $img =~ m|^(\w+)://(.*)| ) {

                        my $furl = Furl->new(
                            agent   => get_program(),
                            timeout => 0.2,
                        ) ;

                        my $res = $furl->get($img) ;
                        if ( $res->is_success ) {
                            path($cachefile)->spew_raw( $res->content ) ;
                            $img = $cachefile ;
                        } else {
                            debug( "ERROR", "unknown could not fetch $img" ) ;
                        }
                    } else {
                        debug( "ERROR", "unknown protocol for $img" ) ;
                    }
                }
            } else {
                $img = $cachefile ;
            }

            # make sure we add the image size if its not already there
            if (   $want_size
                && $pre !~ /width=|height=/i
                && $post !~ /width=|height=/i ) {
                my $image = GD::Image->new($img) ;
                if ($image) {
                    $post =~ s/\/>$// ;
                    $post
                        .= " height='"
                        . $image->height()
                        . "' width='"
                        . $image->width()
                        . "' />" ;
                }
            }

 # do we need to embed the images, if we do this then libreoffice may be pants
 # however 'prince' is happy

# we encode the image as base64 so that the HTML document can be moved with all images
# intact
            my $base64 = MIME::Base64::encode( path($img)->slurp_raw ) ;
            $img = "data:image/$ext;base64,$base64" ;
        }

    }
    return $pre . $img . $post ;
}



# ----------------------------------------------------------------------------
# fetch any img references and copy into the cache, if the image is already
# in the cache then nothing will happen, will rewrite other img uri's
sub _rewrite_imgsrc_local
{
    my $self = shift ;
    my ( $pre, $img, $post ) = @_ ;
    my $ext = "default" ;
    if ( $img =~ /\.(\w+)$/ ) {
        $ext = $1 ;
    }

    # potentially image is already an embedded image or SVG
    if ( $img !~ /base64,/ && $img !~ /\.svg$/i ) {
        # if we are a local file
        if ( $img !~ m|^\w+://| || $img =~ m|^file://| ) {
            $img =~ s|^file://|| ;
            $img = fix_filename($img) ;

            if ( $img !~ m|/| ) {
                # if file is relative, then we need to add the basedir
                $img = $self->basedir . "/$img" ;
            }
            # make sure its local then
            $img = "file://$img" ;
        }
    }
    return $pre . $img . $post ;
}

# ----------------------------------------------------------------------------
# grab all the h2/h3 elements and make them toc items

sub _build_toc
{
    my $html = shift ;

# find any header elements that do not have toc_skip in them
# removing toc_skip for now as it does not seem to work properly
# $html =~ m|<h([23456])(?!.*?(toc_skip|skiptoc).*?).*?><a name=['"](.*?)['"]>(.*?)</a></h\1>|gsmi ;

    # we grab 3 items per header
    my @items = ( $html
            =~ m|<h([23456]).*?><a name=['"](.*?)['"]>(.*?)</a></h\1>|gsmi ) ;

    my $toc = "<p>Contents</p>\n<ul>\n" ;
    for ( my $i = 0; $i < scalar(@items); $i += 3 ) {
        my $ref = $items[ $i + 1 ] ;

        my $h = $items[ $i + 2 ] ;

        # remove any href inside the header title
        $h =~ s/<\/?a.*?>//g ;

        if ( $h =~ /^(\d+\..*?) / ) {
            # indent depending on number of header
            my @a = split( /\./, $1 ) ;
            $h = ( "&nbsp;&nbsp;&nbsp;" x scalar(@a) ) . $h ;
        }

        # make sure reference is in lower case
        $toc .= "  <li><a href='#$ref'>$h</a></li>\n" ;
    }

    $toc .= "</ul>\n" ;

    return $toc ;
}

# ----------------------------------------------------------------------------
# rewrite the headers so that they are nice for the TOC
sub _rewrite_hdrs
{
    state $counters = { 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0 } ;
    state $last_lvl = 0 ;

    my ( $head, $txt, $tail ) = @_ ;
    my $pre ;

    my ($lvl) = ( $head =~ /<h(\d)/i ) ;
    my $ref = $txt ;

    if ( $lvl < $last_lvl ) {
        debug( "ERROR", "something odd happening in _rewrite_hdrs" ) ;
    } elsif ( $lvl > $last_lvl ) {

  # if we are stepping back up a level then we need to reset the counter below
  # if ( $lvl == 4 ) {
  #     $counters->{5} = 0;
  # }
  # elsif ( $lvl == 3 ) {
  #     $counters->{4} = 0;
  # }
  # elsif ( $lvl == 2 ) {
  #     map { $counters->{$_} = 0 ;} (3..6) ;
  # }

        if ( $lvl == 2 ) {
            map { $counters->{$_} = 0 ; } ( 3 .. 6 ) ;
        } else {
            $counters->{ $lvl + 1 } = 0 ;
        }
    }
    $counters->{$lvl}++ ;

    if    ( $lvl == 2 ) { $pre = "$counters->{2}" ; }
    elsif ( $lvl == 3 ) { $pre = "$counters->{2}.$counters->{3}" ; }
    elsif ( $lvl == 4 ) {
        $pre = "$counters->{2}.$counters->{3}.$counters->{4}" ;
    } elsif ( $lvl == 5 ) {
        $pre = "$counters->{2}.$counters->{3}.$counters->{4}.$counters->{5}" ;
    } elsif ( $lvl == 6 ) {
        $pre
            = "$counters->{2}.$counters->{3}.$counters->{4}.$counters->{5}.$counters->{6}"
            ;
    }

    $ref =~ s/\s/_/gsm ;

    # remove things we don't like from the reference
    $ref =~ s/[\s'"\(\)\[\]<>]//g ;

    my $out = "$head<a name='$pre" . "_" . lc($ref) . "'>$pre $txt</a>$tail" ;
    return $out ;
}

# ----------------------------------------------------------------------------
# use pandoc to parse markdown into nice HTML
# pandoc has extra features over and above markdown, eg syntax highlighting
# and tables
# pandoc must be in user path

sub _pandoc_html
{
    my ( $input, $commonmark ) = @_ ;

    my $paninput  = Path::Tiny->tempfile("pandoc.in.XXXX") ;
    my $panoutput = Path::Tiny->tempfile("pandoc.out.XXXX") ;
    path($paninput)->spew_utf8($input) ;
    # my $debug_file = "/tmp/pandoc.$$.md" ;
    # path( $debug_file)->spew_utf8($input) ;

    my $command
        = PANDOC
        . " --ascii --email-obfuscation=none -S -R --normalize -t html5 "
        . " --highlight-style='kate' "
        . " '$paninput' -o '$panoutput'" ;

    my $resp = execute_cmd(
        command => $command,
        timeout => 30,
    ) ;

    my $html ;

    if ( !$commonmark ) {
        debug( "Pandoc: " . $resp->{stderr} ) if ( $resp->{stderr} ) ;
        if ( !$resp->{exit_code} ) {
            $html = path($panoutput)->slurp_utf8() ;

            # path( "/tmp/pandoc.html")->spew_utf8($html) ;

            # this will have html headers and footers, we need to dump these
            $html =~ s/<!DOCTYPE.*?<body>//gsm ;
            $html =~ s/^<\/body>\n<\/html>//gsm ;
            # remove any footnotes hr
            $html
                =~ s/(<section class="footnotes">)\n<hr \/>/<h2>Footnotes<\/h2>\n$1/gsm
                ;
        } else {
            my $err = $resp->{stderr} || "" ;
            chomp $err ;
            # debug( "INFO", "cmd [$command]") ;
            debug( "ERROR",
                "Could not parse with pandoc, using Markdown, $err" ) ;
            warn "Could not parse with pandoc, using Markdown "
                . $resp->{stderr} ;
        }
    }
    if ( $commonmark || !$html ) {
        # markdown would prefer this for fenced code blocks
        $input =~ s/^~~~~.*$/\`\`\`\`/gm ;

        $html = markdown( $input, { markdown => 1 } ) ;
        # do markdown in HTML elements too
        # $html = CommonMark->markdown_to_html($input) ;
    }

    # strip out any HTML comments that may have come in from template
    $html =~ s/<!--.*?-->//gsm ;

    return $html ;
}

# ----------------------------------------------------------------------------
# use pandoc to convert HTML into another format
# pandoc must be in user path

sub _pandoc_format
{
    my ( $input, $output ) = @_ ;
    my $status = 1 ;

    my $resp = execute_cmd(

        command => PANDOC . " '$input' -o '$output'",
        timeout => 30,
    ) ;

    debug( "Pandoc: " . $resp->{stderr} ) if ( $resp->{stderr} ) ;
    if ( !$resp->{exit_code} ) {
        $status = 0 ;
    } else {
        debug( "ERROR", "Could not parse with pandoc" ) ;
        $status = 1 ;
    }

    return $status ;
}

# ----------------------------------------------------------------------------
# convert_file
# convert the file to a different format from HTML
#  parameters
#     file    - file to re-convert
#     format  - format to convert to
#     pdfconvertor  - use prince/wkhtmltopdf rather than pandoc to convert to PDF

sub _convert_file
{
    my $self = shift ;
    my ( $file, $format, $pdfconvertor ) = @_ ;

    # we work on the is that pandoc should be in your PATH
    my $fmt_str = $format ;
    my ( $outfile, $exit ) ;

    $outfile = $file ;
    $outfile =~ s/\.(\w+)$/.pdf/ ;

# we can use prince to do PDF conversion, its faster and better, but not free for commercial use
# you would have to ignore the P symbol on the resultant document
    if ( $format =~ /pdf/i && $pdfconvertor ) {
        my $cmd ;

        if ( $pdfconvertor =~ /^prince/i ) {
            $cmd = PRINCE
                . " --javascript --input=html5 "
                ;    # so we can do some clever things if needed
            $cmd .= "--pdf-title='$self->{replace}->{TITLE}' "
                if ( $self->{replace}->{TITLE} ) ;
            my $subj = $self->{replace}->{SUBJECT}
                || $self->{replace}->{SUBTITLE} ;
            $cmd .= "--pdf-subject='$subj' "
                if ($subj) ;
            $cmd .= "--pdf-creator='" . get_program() . "' " ;
            $cmd .= "--pdf-author='$self->{replace}->{AUTHOR}' "
                if ( $self->{replace}->{AUTHOR} ) ;
            $cmd .= "--pdf-keywords='$self->{replace}->{KEYWORDS}' "
                if ( $self->{replace}->{KEYWORDS} ) ;
# seems to create smaller files if we embed fonts!
# $cmd .= " --no-embed-fonts --no-subset-fonts --media=print $file -o $outfile" ;
# $cmd .= "  --no-artificial-fonts --no-embed-fonts " ;
            $cmd .= " --media=print '$file' -o '$outfile'" ;
        } elsif ( $pdfconvertor =~ /^wkhtmltopdf/i ) {
            $cmd = WKHTML . " -q --print-media-type " ;
            $cmd .= "--title '$self->{replace}->{TITLE}' "
                if ( $self->{replace}->{TITLE} ) ;

            # do we want to specify the size
            $cmd .= "--page-size $self->{replace}->{PAGE_SIZE} "
                if ( $self->{replace}->{PAGE_SIZE} ) ;
            $cmd .= "'$file' '$outfile'" ;
        } else {
            warn "Unknown PDF converter ($pdfconvertor), using pandoc" ;

           # otherwise lets use pandoc to create the file in the other formats
            $exit = _pandoc_format( $file, $outfile ) ;
        }
        if ($cmd) {
            my ( $out, $err ) ;
            try {
                # say "$cmd" ;
                ( $exit, $out, $err ) = run_cmd($cmd) ;
            }
            catch {
                $err  = "run_cmd($cmd) died - $_" ;
                $exit = 1 ;
            } ;

            debug( "ERROR", $err )
                if ($err) ;    # only debug if return code is not 0
        }
    } else {
        # otherwise lets use pandoc to create the file in the other formats
        $exit = _pandoc_format( $file, $outfile ) ;
    }

    # if we failed to convert, then clear the filename
    return $exit == 0 ? $outfile : undef ;
}

# ----------------------------------------------------------------------------
# convert Admonition paragraphs to tagged blocks
sub _rewrite_admonitions
{
    my ( $tag, $content ) = @_ ;
    $content =~ s/^\s+|\s+$//gsm ;

    my $out = "\n~~~~{." . lc($tag) . " icon=1}\n$content\n~~~~\n\n" ;

    return $out ;
}

# ----------------------------------------------------------------------------
# convert things to fontawesome icons, can do most things except stacking fonts
sub _fontawesome
{
    my ( $demo, $icon, $class ) = @_ ;
    my $out ;

    $icon =~ s/^fa-// if ($icon) ;
    if ( !$demo ) {
        my $style = "" ;
        my @colors ;
        if ($class) {
            $class =~ s/^\[|\]$//g ;
            $class =~ s/\b(fw|lg|border)\b/fa-$1/ ;
            $class =~ s/\b([2345]x)\b/fa-$1/ ;
            $class =~ s/\b(90|180|270)\b/fa-rotate-$1/ ;
            $class =~ s/\bflipv\b/fa-flip-vertical/ ;
            $class =~ s/\bfliph\b/fa-flip-horizontal/ ;

            if ( $class =~ s/#((\w+)?\.?(\w+)?)// ) {
                my ( $fg, $bg ) = ( $2, $3 ) ;
                $style .= "color:" . to_hex_color($fg) . ";" if ($fg) ;
                $style .= "background-color:" . to_hex_color($bg) . ";"
                    if ($bg) ;
            }
        # things changed and anything left in class must be a real class thing
            $class =~ s/^\s+|\s+$//g ;
        } else {
            $class = "" ;
        }
        $out = "<i class='fa fa-$icon $class'"
            . ( $style ? " style='$style'" : "" ) ;
        $out .= "></i>" ;
    } else {
        if ( $icon eq '\\' ) {
            ( $icon, $class ) = @_[ 2 .. 3 ] ;
            $icon =~ s/^fa-// if ($icon) ;
        }
        $class =~ s/^\[|\]$//g if ($class) ;
        $out = ":fa:$icon" ;
        $out .= ":[$class]" if ($class) ;
    }

    return $out ;
}

# ----------------------------------------------------------------------------
# convert things to google material icons
sub _fontmaterial
{
    my ( $demo, $icon, $class ) = @_ ;
    my $out ;

    $icon =~ s/^mi-// if ($icon) ;
    if ( !$demo ) {
        my $style = "" ;
        my @colors ;
        if ($class) {
            $class =~ s/^\[|\]$//g ;
            # $class =~ s/\b(fw|lg|border)\b/mi-$1/ ;
            if( $class =~ /\blg\b/) {
                $style .= "font-size:1.75em;" ;
                $class =~ s/\blg\b// ;
            } elsif( $class =~ /\b([2345])x\b/) {
                $style .= "font-size:$1" . "em;" ;
                $class =~ s/\b[2345]x\b// ;
            }
            $class =~ s/\b(90|180|270)\b/rotate-$1/ ;
            $class =~ s/\bflipv\b/flip-vertical/ ;
            $class =~ s/\bfliph\b/flip-horizontal/ ;

            if ( $class =~ s/#((\w+)?\.?(\w+)?)// ) {
                my ( $fg, $bg ) = ( $2, $3 ) ;
                $style .= "color:" . to_hex_color($fg) . ";" if ($fg) ;
                $style .= "background-color:" . to_hex_color($bg) . ";"
                    if ($bg) ;
            }
        # things changed and anything left in class must be a real class thing
            $class =~ s/^\s+|\s+$//g ;
        } else {
            $class = "" ;
        }
        # names are actually underscore spaced
        $icon =~ s/[-| ]/_/g;
        $out = "<i class='material-icons $class'"
            . ( $style ? " style='$style'" : "" ) ;
        $out .= ">$icon</i>" ;
    } else {
        if ( $icon eq '\\' ) {
            ( $icon, $class ) = @_[ 2 .. 3 ] ;
            $icon =~ s/^mi-// if ($icon) ;
        }
        $class =~ s/^\[|\]$//g if ($class) ;
        $out = ":mi:$icon" ;
        $out .= ":[$class]" if ($class) ;
    }

    return $out ;
}

# ----------------------------------------------------------------------------
# handle all font replacers
sub _font_replace {
    my ( $demo, $type, $icon, $class ) = @_ ;

    if( $type eq 'mi') {
        return _fontmaterial(  $demo, $icon, $class ) ;
    } elsif( $type eq 'fa') {
        return _fontawesome(  $demo, $icon, $class ) ;
    }

    # its not a font we support yet, so rebuild the line
    my $out = "" ;
    $out .= $demo if( $demo) ;
    $out .= ":$type:$icon" ;
    $out .= ":[$class]" if( $class) ;

    return $out;
}

# ----------------------------------------------------------------------------
# do some private stuff
{
    my $_yaml_counter = 0 ;

    sub _reset_yaml_counter
    {
        $_yaml_counter = 0 ;
    }

   # remove the first yaml from the first 20 lines, pass anything else through
    sub _remove_yaml
    {
        my ( $line, $count ) = @_ ;

        $count ||= 20 ;
        if ( ++$_yaml_counter < $count ) {
            $line =~ s/^\w+:.*// ;
        }

        return $line ;
    }
}

# ----------------------------------------------------------------------------
# grab external files
# param is filename followed by any arguments

# parameters

#  file - name of file to import
#  markdown - show input is markdown and may need some tidy ups
#  headings - in markdown add this many '#' heading to the start of headers
#  class - optional class to wrap around import
#  style - optional style to wrap around import

sub _include_file
{
    my ($attributes) = @_ ;
    my $out = "" ;

    my $params = _extract_args($attributes) ;

    $params->{file} = fix_filename( $params->{file} ) ;
    if ( -f $params->{file} ) {
        $out = path( $params->{file} )->slurp_utf8() ;
    }
    if ( $params->{markdown} ) {
        # if we are importing markdown we may want to fix things up a bit

        # first off remove any yaml head matter from first 20 lines
        $out =~ s/^(.*)?$/_remove_yaml($1,20)/egm ;

        # then any version table
        $out =~ s/^~~~~\{.version.*?^~~~~//gsm ;

        # expand any headings if required
        if ( $params->{headings} ) {
            my $str = "#" x int( $params->{headings} ) ;
            $out =~ s/^#/#$str/gsm ;
        }
    }

    # add a div for class and style if required
    if( $params->{class} || $params->{style}) {
        my $div = "<div " ;
        $div .= "class='$params->{class}'" if( $params->{class}) ;
        $div .= "style='$params->{style}'" if( $params->{style}) ;
        $out = "$div>$out$</div>"
    }

    return $out ;
}

# ----------------------------------------------------------------------------
sub _replace_material
{
    my ( $operator, $value ) = @_ ;
    my $quote ="";
    if( $value =~ /^(["'"])/) {
        $quote = $1 ;
        $value =~ s/^["'"]//;
    }

    return "color" . $operator . $quote . to_hex_color($value) ;
}

# ----------------------------------------------------------------------------

=item parse

parse the markup into HTML and return it, HTML is also stored internally

B<Parameter>
    markdown text

=cut

sub parse
{
    my $self = shift ;
    my ($data) = @_ ;

    die "Nothing to parse" if ( !$data ) ;

    # big cheat to get this link in ahead of the main CSS
    add_javascript( '<link rel="stylesheet" type="text/css" '
            . ' href="https://maxcdn.bootstrapcdn.com/font-awesome/4.4.0/css/font-awesome.min.css">'
    ) ;

    add_javascript( '<link href="https://fonts.googleapis.com/icon?family=Material+Icons"
      rel="stylesheet">') ;

    # add in our basic CSS
    add_css($default_css) ;

    my $id = md5_hex( encode_utf8($data) ) ;

    # my $id = md5_hex( $data );
    $self->_set_md5id($id) ;
    $self->_set_input($data) ;

    my $cachefile = cachefile( $self->cache_dir, "$id.html" ) ;
    if ( -f $cachefile ) {
        my $cache = path($cachefile)->slurp_utf8 ;
        $self->{output} = $cache ;    # put cached item into output
    } else {
        $self->{output} = "" ;        # blank the output

        # replace Admonition paragraphs with a proper block
        $data
            =~ s/^(NOTE|INFO|TIP|IMPORTANT|CAUTION|WARNING|DANGER|TODO|ASIDE):(.*?)\n\n/_rewrite_admonitions( $1, $2)/egsm
            ;

        $data =~ s/\{\{.(include|import)\s+(.*?)\}\}/_include_file($2)/iesgm ;
        $data
            =~ s/^~~~~\{.(include|import)\s+(.*?)\}.*?~~~~/_include_file($2)/iesgm
            ;

        my @lines = split( /\n/, $data ) ;

        # process top 20 lines for keywords
        # maybe replace this with some YAML processor?
        for ( my $i = 0; $i < 20; $i++ ) {
            ## if there is no keyword separator then we must have done the keywords
            last if ( $lines[$i] !~ /:/ ) ;

            # allow keywords to be :keyword or keyword:
            my ( $k, $v ) = ( $lines[$i] =~ /^:?(\w+):?\s+(.*?)\s?$/ ) ;
            next if ( !$k ) ;

            # date/DATE is a special one as it may be that they want to use
            # the current date so we will ignore it
            if ( !( $k eq 'date' && $v eq '%DATE%' ) ) {
                $self->_add_replace( $k, $v ) ;
            }
            $lines[$i] = undef ;    # essentially remove the line
        }

        # parse the data find all fenced blocks we can handle
        $self->_parse_lines( \@lines ) ;

        # store the markdown before parsing
        # $self->_store_cache( $self->cache_dir() . "/$id.md",
        #     encode_utf8( $self->{output} ), 1 ) ;
        $self->_store_cache( $self->cache_dir() . "/$id.md",
            $self->{output}, 1 ) ;

        # we have a special replace for '---' alone on a line which is used to
        # signifiy a page break

        $self->{output}
            =~ s|^-{3,}\s?$|<div style='page-break-before: always;'></div>\n\n|gsm
            ;

        # add in some smilies
        $self->{output} =~ s/(?<!\w)($smiles)(?!\w)/$smilies{$1}/g ;

        # do the font replacements, awesome or material
        # :fa:icon,  :mi:icon,  
        $self->{output}
            =~ s/(\\)?:(\w{2}):([\w|-]+):?(\[(.*?)\])?/_font_replace( $1, $2, $3, $4)/egsi ;

        # we have created something so we can cache it, if use_cache is off
        # then this will not happen lower down
        # now we convert the parsed output into HTML
        my $pan = _pandoc_html( $self->{output} ) ;

        # add the converted markdown into the template
        my $html = $self->template ;
        # lets do the includes in the templates to, gives us some flexibility
        $html =~ s/\{\{.include file=(.*?)\}\}/_include_file($1)/esgm ;
        $html
            =~ s/^~~~~\{.include file=(.*?)\}.*?~~~~/_include_file($1)/esgm ;

        my $program = get_program() ;
        $html
            =~ s/(<head.*?>)/$1\n<meta name="generator" content="$program" \/>/i
            ;

        my $rep = "%" . CONTENTS . "%" ;
        $html =~ s/$rep/$pan/gsm ;

        # if the user has not used title: grab from the page so far
        if ( !$self->{replace}->{TITLE} ) {
            my (@h1) = ( $html =~ m|<h1.*?>(.*?)</h1>|gsmi ) ;

            # find the first header that does not contain %TITLE%
            # I failed to get the zero width look-behind working
            # my ($h) = ( $html =~ m|<h1.*?>.*?(?<!%TITLE%)(.*?)</h1>|gsmi );
            foreach my $h (@h1) {
                if ( $h !~ /%TITLE/ ) {
                    $self->{replace}->{TITLE} = $h ;
                    last ;
                }
            }
        }

        # do we need to add a table of contents
        if ( $html =~ /%TOC%/ ) {
            $html
                =~ s|(<h([23456]).*?>)(.*?)(</h\2>)|_rewrite_hdrs( $1, $3, $4)|egsi
                ;
            $self->{replace}->{TOC}
                = "<div class='toc'>" . _build_toc($html) . "</div>" ;
        }

        $self->{replace}->{CSS}        = get_css() ;
        $self->{replace}->{JAVASCRIPT} = get_javascript() ;

        # replace things we have saved
        $html = $self->_do_replacements($html) ;

      # this allows us to put short blocks as output of other blocks or inline
      # with things that might otherwise not allow them
      # we use the single line parse version too
      # short tags cannot have the form
      # {{.class .tag args=123}}

        $html
            =~ s/\{\{\.(\w+)(\b.*?)\}\}/$self->_rewrite_short_block( $1, $2)/egs
            ;
# and without arguments
# $html =~ s/\{\{\.(\w+)\s?\}\}/$self->_rewrite_short_block( '', $1, {})/egs ;

        # and remove any uppercased %word% things that are not processed
        $html =~ s/(?<!_)%[A-Z-_]+\%//gsm ;
        $html =~ s/_(%.*?%)/$1/gsm ;

# fetch any images and store to the cache, make sure they have sizes too
# $html
#     =~ s/(<img.*?src=['"])(.*?)(['"].*?>)/$self->_rewrite_imgsrc_local( $1, $2, $3)/egs
#     ;

# # write any css url images and store to the cache
# $html
#     =~ s/(url\s*\(['"]?)(.*?)(['"]?\))/$self->_rewrite_imgsrc_local( $1, $2, $3)/egs
#     ;

        $html
            =~ s/(<img.*?src=['"])(.*?)(['"].*?>)/$self->_rewrite_imgsrc( $1, $2, $3, 1)/egs
            ;

        # write any css url images and store to the cache
        $html
            =~ s/(url\s*\(['"]?)(.*?)(['"]?\))/$self->_rewrite_imgsrc( $1, $2, $3, 0)/egs
            ;



# replace any escaped \{ braces when needing to explain short code blocks in examples
        $html =~ s/\\\{/{/gsm ;

# we should have everything here, so lets do any final replacements for material colors
        $html =~ s/color(=|:)\s?(["']?\w+[50]0\b)/_replace_material( $1,$2)/egsm ;


        $self->{output} = $html ;
        $self->_store_cache( $cachefile, $html, 1 ) ;
    }
    return $self->{output} ;
}

# ----------------------------------------------------------------------------

=item save_to_file

save the created html to a named file

B<Parameters>
    filename    filename to store/convert stored HTML into
    pdfconvertor   indicate that we should use prince or wkhtmltopdf to create PDF

=cut

sub save_to_file
{
    state $counter = 0 ;
    my $self = shift ;
    my ( $filename, $pdfconvertor ) = @_ ;
    my ($format) = ( $filename =~ /\.(\w+)$/ ) ;  # get last thing after a '.'
    if ( !$format ) {
        warn "Could not determine output file format, using PDF" ;
        $format = '.pdf' ;
    }

    my $f = $self->_md5id() . ".html" ;

    # have we got the parsed data
    my $cf = cachefile( $self->cache_dir, $f ) ;
    if ( !$self->{output} ) {
        die "parse has not been run yet" ;
    }

    if ( !-f $cf ) {
        if ( !$self->use_cache() ) {

            # create a file name to store the output to
            $cf = "/tmp/" . get_program() . "$$." . $counter++ ;
        }

        # either update the cache, or create temp file
        # path($cf)->spew_utf8( encode_utf8( $self->{output} ) ) ;
        path($cf)->spew_utf8( $self->{output} ) ;
    }

    my $outfile = $cf ;
    $outfile =~ s/\.html$/.$format/i ;

    # if the marked-up file is more recent than the converted one
    # then we need to convert it again
    if ( $format !~ /html?/i ) {

        # as we can generate PDF using a number of convertors we should
        # always regenerate PDF output incase the convertor used is different
        if (   !-f $outfile
            || $format =~ /pdf/i
            || ( ( stat($cf) )[9] > ( stat($outfile) )[9] ) ) {
            $outfile = $self->_convert_file( $cf, $format, $pdfconvertor ) ;

            # if we failed to convert, then clear the filename
            if ( !$outfile || !-f $outfile ) {
                $outfile = undef ;
                debug( "ERROR",
                    "failed to create output file from cached file $cf" ) ;
            }
        }
    }

    my $status = 0 ;

    # now lets copy it to its final resting place
    if ($outfile) {
        try {
            $status = path($outfile)->copy($filename) ;
        }
        catch {
            say STDERR "$_ " ;
            debug( "ERROR", "failed to copy $outfile to $filename" ) ;
        } ;
    }
    return $status ;
}

=back

=cut

# ----------------------------------------------------------------------------

1 ;

__END__
