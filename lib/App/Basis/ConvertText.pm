=head1 NAME

 App::Basis::ConvertText

=head1 SYNOPSIS

=head1 DESCRIPTION

A long time ago I had a SSI based website running on apache, then I found a way
(thanks to Writing Apache Modules with  Perl and C) to do this in perl and to create
my own XML type elements and for me a new way of creating webpages was born, with 
my own markup language, creating webpages became simple!

Now I find that I need a way to add special tags into text files for processing and
it makes sense not to re-invent the wheel but to bring it up to OOD date

One thing to remember, is that we may not be parsing a HTML or XML file, so we cannot
use normal XML processing tools, we need to process our special tags by hand

We are keeping things simple, there is to be no XML elements nested inside other
XML elements, this way our regexp and processing is straight forward

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.006

=head1 HISTORY

First created in June 1999, now updated to become App::Basis::ConvertText

#@todo change from <xml> style markup to fenced code blocks ~~~~ {.extension}
similar to App::Pandoc-preprocess (and others)

# create drawings for ditta
http://www.asciiflow.com/#Draw

#@todo change to use plugins, that define themselves and their extension

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText;

use 5.10.0;
use strict;
use warnings;
use feature 'state';
use Moo;
use Data::Printer;
use Try::Tiny;
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
use File::Slurp;
use File::Basename qw( dirname fileparse);
use Text::Markdown qw(markdown);
use File::Copy;

# use Text::CSV::Slurp;
use GD;
use MIME::Base64;
use Furl;

use App::Basis;
use App::Basis::ConvertFile;
use App::Basis::ConvertText::Mscgen;
use App::Basis::ConvertText::Ditaa;
use App::Basis::ConvertText::Uml;
use App::Basis::ConvertText::Links;
use App::Basis::ConvertText::Graphviz;
use App::Basis::ConvertText::Chart;

# use App::Basis::ConvertText::Ploticus;
use App::Basis::ConvertText::Sparkline;
use App::Basis::ConvertText::Venn;
use App::Basis::ConvertText::Table;
use App::Basis::ConvertText::QRcode;
use App::Basis::ConvertText::YamlAsJson;

# ----------------------------------------------------------------------------
my $TITLE = "__TITLE__";

# the tag needs to point to the name of a METHOD that will handle it, make sure
# that they do not point to a coderef
my %valid_tags = (
    chart  => '_process_chart',
    mscgen => '_process_mscgen',
    ditaa  => '_process_ditaa',
    ascii  => '_process_ditaa',
    uml    => '_process_uml',
    links  => '_process_links',

    # ploticus  => '_process_ploticus',
    graphviz   => '_process_graphviz',
    sparkline  => '_process_sparkline',
    venn       => '_process_venn',
    table      => '_process_table',
    qrcode     => '_process_qrcode',
    yamlasjson => '_process_yamlasjson',
    buffer     => 'BUILT INTO _call_function',
);

# ----------------------------------------------------------------------------

has 'name' => ( is => 'ro', );

has 'use_cache' => ( is => 'rw', default => sub { 0; } );

has 'cache_dir' => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return "/tmp/" . get_program() . "/cache/";
    },
    writer => "_set_cache_dir"
);

has 'html_header' => (
    is      => 'rw',
    default => sub {
        "<!DOCTYPE HTML PUBLIC '-//W3C//DTD HTML 4.01//EN' 'http://www.w3.org/TR/html4/strict.dtd'>
    <html>
    <head><title>$TITLE</title>

    <style type='text/css'>
        \@page { size: A4 }
    </style>

    </head>\n<body>
    ";
    },
);
has 'html_footer' => (
    is      => 'rw',
    default => sub { "\n</body>\n</html>\n"; },
);

has 'replace' => (
    is      => 'ro',
    default => sub { {} },
);

has 'verbose' => (
    is      => 'ro',
    default => sub {0},
);

has '_output' => (
    is       => 'ro',
    writer   => '_set_output',
    default  => sub {""},
    init_arg => 0
);

has '_input' => (
    is       => 'ro',
    writer   => '_set_input',
    default  => sub {""},
    init_arg => 0
);

has '_md5id' => (
    is       => 'ro',
    writer   => '_set_md5id',
    default  => sub {""},
    init_arg => 0
);

has 'embed' => (
    is      => 'ro',
    default => sub {0},
);

has 'keywords' => (
    is       => 'ro',
    default  => sub { {} },
    writer   => '_set_keywords',
    init_arg => 0
);

# ----------------------------------------------------------------------------

=item new

Create a new instance of a of a data formating object

B<Parameters>  passed in a HASH
    name        - name of this formatting action - required
    cache_dir   - place to store cache files - optional
    use_cache   - decide if you want to use a cache or not
=cut

sub BUILD {
    my $self = shift;

    die "No name provided" if ( !$self->name() );

    if ( $self->use_cache() ) {

        # need to add the name to the cache dirname to make it distinct
        $self->_set_cache_dir( $self->cache_dir() . "/" . $self->name() );
        my $cd = $self->cache_dir();
        $cd =~ s|//|/|g;

        # replace home
        $cd =~ s|^~|$ENV{HOME}|;
        $self->_set_cache_dir($cd);

        # create the cache dir if needed
        my ( $out, $err, $ret ) = run_cmd( "mkdir -p '" . $self->cache_dir() . "'" );
        die "Could not create cache dir " . $self->cache_dir() if ( !-d $self->cache_dir() );
    }
}

# ----------------------------------------------------------------------------

sub _append_output {
    my $self = shift;
    my $str  = shift;
    $str ||= "";

    $self->_set_output( $self->_output . $str );
}

# ----------------------------------------------------------------------------
# store a file to the cache
# if the contents are empty then any existing cache file will be removed
sub _store_cache {
    my $self = shift;
    my ( $filename, $contents ) = @_;

    # don't do any cleanup if we are not using a cache
    return if ( !$self->use_cache() );

    # make sure we are working in the right dir
    my $f = $self->cache_dir() . "/" . fileparse($filename);

    if ( !$contents && -f $f ) {
        unlink($f);
    }
    else {
        write_file( $f, $contents );
    }
}

# ----------------------------------------------------------------------------
# get a file from the cache
sub _get_cache {
    my $self = shift;
    my ($filename) = @_;

    # don't do any cleanup if we are not using a cache
    return if ( !$self->use_cache() );

    # make sure we are working in the right dir
    my $f = $self->cache_dir() . "/" . fileparse($filename);

    my $result;
    $result = read_file($f) if ( -f $f );

    return $result;
}

# ----------------------------------------------------------------------------
# check if a file is in the cache, if so return the full file name
sub _in_cache {
    my $self = shift;
    my ($filename) = @_;

    # make sure we are working in the right dir
    my $f = $self->cache_dir() . "/" . fileparse($filename);
    return -f $f ? $f : 0;
}

# ----------------------------------------------------------------------------
sub clean_cache {
    my $self = shift;

    # don't do any cleanup if we are not using a cache
    return if ( !$self->use_cache() );

    my ( $out, $err, $ret ) = run_cmd( "rm -rf '" . $self->cache_dir() . "'/*" );
}

# ----------------------------------------------------------------------------
# _extract_args
sub _extract_args {
    my $buf = shift;
    my ( %attr, $eaten );

    while ( $buf =~ s|^\s?(([a-zA-Z][a-zA-Z0-9\.\-_]*)\s*)|| ) {
        $eaten .= $1;
        my $attr = lc $2;
        my $val;

        # The attribute might take an optional value (first we
        # check for an unquoted value)
        if ( $buf =~ s|(^=\s*([^\"\'>\s][^>\s]*)\s*)|| ) {
            $eaten .= $1;
            $val = $2;

            # or quoted by " or '
        }
        elsif ( $buf =~ s|(^=\s*([\"\'])(.*?)\2\s*)||s ) {
            $eaten .= $1;
            $val = $3;

            # truncated just after the '=' or inside the attribute
        }
        elsif ($buf =~ m|^(=\s*)$|
            or $buf =~ m|^(=\s*[\"\'].*)|s )
        {
            $buf = "$eaten$1";
            last;
        }
        else {
            # assume attribute with implicit value
            $val = $attr;
        }
        $attr{$attr} = $val;
    }

    return \%attr;
}

# ----------------------------------------------------------------------------
# create a signature based on content and params to a element
sub _create_sig {
    my ( $content, $params ) = @_;
    my $param_str = join( ' ', map { "$_='$params->{$_}'"; } sort keys %$params );

    return md5_hex( $content . encode_utf8($param_str) );
}

# ----------------------------------------------------------------------------
sub _create_img_src {
    my ( $file, $alt ) = @_;

    return "" if ( !$file || !-f $file );

    my $out = "<img src='$file' ";
    $out .= "alt='$alt' " if ($alt);

    my $image = GD::Image->new($file);
    if ($image) {
        $out .= "height='" . $image->height() . "' width='" . $image->width() . "' ";
    }

    $out .= "/>";
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_mscgen {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $png = _create_sig( $content, $params ) . ".png";

    my $file = $self->_in_cache($png);
    if ( !$file ) {
        $file = $self->cache_dir() . "/" . $png;
        $params->{title} ||= "";
        mscgen( $content, $file, $params );
    }

    my $out;
    if ( -f $file ) {
        $out = _create_img_src( $file, $params->{title} );
    }
    else {
        $out = "Problem creating $tag item\n";
    }
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_ditaa {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $png = _create_sig( $content, $params ) . ".png";

    my $file = $self->_in_cache($png);
    if ( !$file ) {
        $file = $self->cache_dir() . "/" . $png;
        $params->{title} ||= "";
        ditaa( $content, $file, $params );
    }

    my $out;
    if ( -f $file ) {
        $out = _create_img_src( $file, $params->{title} );
    }
    else {
        $out = "Problem creating $tag item\n";
    }
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_uml {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $png = _create_sig( $content, $params ) . ".png";

    my $file = $self->_in_cache($png);
    if ( !$file ) {
        $file = $self->cache_dir() . "/" . $png;
        $params->{title} ||= "";
        uml( $content, $file, $params );
    }

    my $out;
    if ( -f $file ) {
        $out = _create_img_src( $file, $params->{title} );
    }
    else {
        $out = "Problem creating $tag item\n";
    }
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_links {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $out = links( $content, undef, $params );

    return $out;
}

# ----------------------------------------------------------------------------
sub _process_graphviz {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $png = _create_sig( $content, $params ) . ".png";

    my $file = $self->_in_cache($png);
    if ( !$file ) {
        $file = $self->cache_dir() . "/" . $png;
        $params->{title} ||= "";
        graphviz( $content, $file, $params );
    }

    my $out;
    if ( -f $file ) {

        # $out = "![$params->{title}]($file) ";
        $out = _create_img_src( $file, $params->{title} );
    }
    else {
        $out = "Problem creating $tag item\n";
    }
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_ploticus {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $png = _create_sig( $content, $params ) . ".png";

    my $file = $self->_in_cache($png);
    if ( !$file ) {
        $file = $self->cache_dir() . "/" . $png;
        $params->{title} ||= "";

        $content =~ s/^\n//gsm;
        $content =~ s/\n$//gsm;

        ploticus( $content, $file, $params );
    }

    my $out;
    if ( -f $file ) {

        # $out = "![$params->{title}]($file) ";
        $out = _create_img_src( $file, $params->{title} );
    }
    else {
        $out = "Problem creating $tag item\n";
    }
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_chart {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $png = _create_sig( $content, $params ) . ".png";

    my $file = $self->_in_cache($png);
    if ( !$file ) {
        $file = $self->cache_dir() . "/" . $png;
        $params->{title} ||= "";

        $content =~ s/^\n//gsm;
        $content =~ s/\n$//gsm;

        chart( $content, $file, $params );
    }

    my $out;
    if ( -f $file ) {

        # $out = "![$params->{title}]($file) ";
        $out = _create_img_src( $file, $params->{title} );
    }
    else {
        $out = "Problem creating $tag item\n";
    }
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_sparkline {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $png = _create_sig( $content, $params ) . ".png";

    my $file = $self->_in_cache($png);
    if ( !$file ) {
        $file = $self->cache_dir() . "/" . $png;
        $params->{title} ||= "";
        $content =~ s/\n//gsm;
        sparkline( $content, $file, $params );
    }

    my $out;
    if ( -f $file ) {

        # $out = "![$params->{title}]($file) ";
        $out = _create_img_src( $file, $params->{title} );
    }
    else {
        $out = "Problem creating $tag item\n";
    }
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_venn {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $sig = _create_sig( $content, $params );
    my $png = "$sig.png";

    my $file = $self->_in_cache($png);
    if ( !$file ) {
        $file = $self->cache_dir() . "/" . $png;
        $params->{title} ||= "";

        my $text = "
one two three eight nine
three four five eight nine
one five seven nine
";

        my $options = {
            legends => 'alpha beta gama',
            title   => "Venn diagram",
            scheme  => 'rgb',
        };

        my $explain = venn( $text, $file, $options );

        # my $explain = venn( $content, $file, $params );
        if ($explain) {
            $self->_store_cache( "$sig.md", $explain );
        }
    }

    my $out;
    if ( -f $file ) {

        # $out = "![$params->{title}]($file) ";
        $out = _create_img_src( $file, $params->{title} );

        # add the markdown for the explaination
        if ( $params->{explain} ) {
            $out .= $self->_get_cache("$sig.md") || "";
        }
    }
    else {
        $out = "Problem creating $tag item\n";
    }
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_table {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    $params->{title} ||= "";

    $content =~ s/^\n//gsm;
    $content =~ s/\n$//gsm;

    my $out = table( $content, $params );
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_qrcode {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    my $png = _create_sig( $content, $params ) . ".png";

    my $file = $self->_in_cache($png);
    if ( !$file ) {
        $file = $self->cache_dir() . "/" . $png;
        $content =~ s/\n//gsm;
        qrcode( $content, $file, $params );
    }

    my $out;
    if ( -f $file ) {

        # $out = "![$params->{title}]($file) ";
        $out = _create_img_src( $file, $params->{title} );
    }
    else {
        $out = "Problem creating $tag item\n";
    }
    return $out;
}

# ----------------------------------------------------------------------------
sub _process_yamlasjson {
    my $self = shift;
    my ( $tag, $params, $content ) = @_;

    $content =~ s/~~~~{\.yaml}//gsm;
    $content =~ s/~~~~//gsm;

    my $out = yamlasjson($content);
    return $out;
}

# ----------------------------------------------------------------------------
sub _buffer {
    state $buffer = {};

    my ( $action, $id, $content ) = @_;
    my $out;

    if ( $action eq 'fetch' ) {
        $out = $buffer->{$id};
    }
    else {
        $buffer->{$id} = $content;
    }

    return $out;
}

# ----------------------------------------------------------------------------
sub _call_function {
    my $self = shift;
    my ( $tagname, $params, $content ) = @_;

    my $handler = $valid_tags{$tagname};

    if ( !$handler ) {
        debug( "ERROR:", "no valid handler for $tagname" );
    }
    else {
        try {
            # handily we can just call the methods by their names
            my $out;

            # buffer is a special construct to allow us to hold output of content
            # for later, allows multiple use of content or adding things to
            # markdown tables that otherwise we could not do

            # over-ride content with buffered content
            if ( $params->{from_buffer} ) {
                $content = _buffer( 'fetch', $params->{from_buffer} );
            }

            if ( $tagname ne 'buffer' ) {
                $out = $self->$handler( $tagname, $params, $content );

                # do we want to buffer the output?
                if ( $params->{to_buffer} ) {

                    # store this item into the buffer for later retrival with <buffer from=
                    _buffer( 'store', $params->{to_buffer}, $out );

                    # option not to show the output
                    $out = undef if ( $params->{no_output} );
                }
            }
            else {
                if ( $params->{to} ) {

                    # we want to store the contents for later consumption
                    _buffer( 'store', $params->{to}, $content );
                }
                elsif ( $params->{from} ) {
                    $out = _buffer( 'fetch', $params->{from} );
                }
            }
            $self->_append_output($out) if ( defined $out );
        }
        catch {
            debug( "ERROR:", "failed processing $tagname, $_" );
            $content ||= "";
            my $args = join( " ", map {"$_='$params->{$_}'"} sort keys %$params );
            $self->_append_output("<!-- Cannot process $tagname, no handler method -->\n<$tagname $args>$content</$tagname>");
        };
    }
}

# ----------------------------------------------------------------------------
### _parse_token
# parse the passed string
sub _parse_token {
    my $self = shift;
    my $str  = shift;

    return if ( !$str );

    # try to match a XML type tag <fred>blah </fred>
    $str =~ m|^(.*?)\<(.*?)\>(.*)|sm;

    # did we get everything we expected?
    if ($3) {
        my $pre     = $1;
        my $tagdata = $2;
        my $post    = $3;
        my ( $tagname, $argdata, $params );
        my $badtag     = 0;
        my $single_tag = 0;    # like <br />

        # we can send anything before our element off to the output
        $self->_append_output($pre);

        # check on single elements <br />
        if ( $tagdata =~ m|/$| ) {
            $single_tag = 1;
            $tagdata =~ s|/$||;
        }

        # now work out the element name and any arguments
        $tagdata =~ m|^(\w+)\b(.*)|sm;
        if ($2) {

            # tags are lower case for ease
            $tagname = lc $1;
            $argdata = $2;
        }
        else {
            # this is for the case where we have an element without params
            # eg <h1>
            $tagname = $1;
        }

        # if we don't have this tag, we should not process it anymore
        if ( $tagname && $valid_tags{$tagname} ) {
            if ($argdata) {
                $params = _extract_args($argdata);
            }

            if ($single_tag) {    # single tag
                $self->_call_function( $tagname, $params );
            }
            elsif ( $post =~ m|<\/$tagname>|smi ) {    # check if we have a matching endtag
                $post =~ m|^(.*?)</$tagname>(.*)|smi;
                my $contents = $1;
                $post = $2;

                $self->_call_function( $tagname, $params, $contents );
            }
            else {
                $self->_append_output("**missing end tag for $tagname**");
                $badtag = 1;

                # make sure we don't carry on
                $post = undef;
            }
        }
        else {
            # this is not a tag we recognise
            $badtag = 1;
            if ( $tagname && !$single_tag ) {
                if ( $post =~ m|<\/$tagname>|smi ) {    # check if we have a matching endtag
                    $post =~ m|^(.*?</$tagname>)(.*)|smi;
                    my $contents = $1;
                    $post = $2;

                    # write the unknown tag and its contents/endtag to output
                    $self->_append_output("<$tagdata>$contents");
                    $badtag = 0;                        # we now consider it good/processed
                }
                else {
                    # $self->_append_output("**missing end tag for $tagname**");
                    $badtag = 1;

                    # make sure we don't carry on
                    # $post = undef;
                }
            }
        }
        if ($badtag) {

            # rebuild the xml, add to the output
            if ($single_tag) {
                $self->_append_output("<$tagdata />");
            }
            else {
                $self->_append_output("<$tagdata>");
            }
        }

        # recurse on the remainder
        $self->_parse_token($post);
    }
    else {
        $self->_append_output($str);
    }

}

# ----------------------------------------------------------------------------

# change |a|b|c| into a html table, this does not allow spanning cells or rows
# or rows that are on multiple lines, its just a simple thing
# you can add {some stuff for styling} too

# !header|header|
# |cell1|cell2|cell3|
# |cell1|cell2|cell3|

# or with no header
# |cell1|cell2|cell3|
# |cell1|cell2|cell3|
#
# must leave a blank line at the end of the table

# sub html_table {
#     my $tbl = shift;
#     my $out = "";
#     # strip any paragraph stuff that markdown inserts
#     $tbl =~ s/<\/?p>//gism;

#     # put in spaces for empty cells
#     $tbl =~ s/\|\|/\|\&nbsp;\|/gsm;
#     # for some dodgy reason I have to repeat this to get the last ||'s to work!
#     $tbl =~ s/\|\|/\|\&nbsp;\|/gsm;

#     my $row = 0;
#     foreach my $line ( split( /\n/, $tbl ) ) {
#         my $cell = 'td';
#         my $class = ( $row & 1 ? 'odd' : 'even' );

#         # the first line may be special
#         if ( !$row ) {
#             my $style = "width='50%'";
#             # the first line could be a header line, if it starts with a !
#             if ( $line =~ /^!/ ) {
#                 $cell  = 'th';
#                 $class = 'header';
#                 $line =~ s/^!/|/;
#             }
#             # the first line can also have some extra style etc info
#             if ( $line =~ /{(.*?)}$/ ) {
#                 $style = $1;
#                 $line =~ s/{.*?}$//;    # remove it
#             }

#             $out .= "\n<table class='md' $style>\n";
#         }
#         $row++;
#         $out .= "  <tr class='$class'>";

#         # remove leading and trailing cell borders
#         $line =~ s/^(\s*)\|/$1/;        # keep leading spaces
#         $line =~ s/\|\s*$//;            # ignore trailing spaces
#                                         # split the cells and find the headers
#         foreach my $content ( split( /\|/, $line ) ) {
#             $out .= "<$cell>$content</$cell>";
#         }
#         $out .= "</tr>\n";
#     }
#     $out .= "</table>\n";

#     $out .= "\n";
#     return $out;
# }

# ----------------------------------------------------------------------------
# fetch any img references and copy into the cache, if the image is already
# in the cache then nothing will happen, will rewrite other img uri's
sub rewrite_imgsrc {
    my $self = shift;
    my ( $pre, $img, $post, $want_size ) = @_;
    my $ext;
    if ( $img =~ /\.(\w+)$/ ) {
        $ext = $1;
    }

    # if its an image we have generated then it may already be here
    if ( !$self->_in_cache($img) ) {
        my $id = md5_hex($img);
        $id .= ".$ext";

        # check to see if we have this in the cache
        my $cachefile = $self->_in_cache($id);

        if ( -f $cachefile ) {
            $img = $cachefile;
        }
        else {
            # this is what it will be named in the cache
            $cachefile = $self->cache_dir() . "/$id";

            # not in the cache so we must fetch it and store it local to the cache
            # if we are a local file
            if ( $img !~ m|^\w+://| || $img =~ m|^file://| ) {
                $img =~ s/^file:\/\///;
                $img =~ s/^~/$ENV{HOME}/;
                my $status;

                # copy it to the cache location
                try {
                    $status = copy( $img, $cachefile );
                }
                catch {
                    debug( "ERROR", "failed to copy $img to $cachefile" );
                };

                $img = $cachefile if ( -f $cachefile );
            }
            else {
                if ( $img =~ m|^(\w+)://(.*)| ) {

                    my $furl = Furl->new(
                        agent   => get_program(),
                        timeout => 10,
                    );

                    my $res = $furl->get($img);
                    if ( $res->is_success ) {
                        write_file( $cachefile, $res->content );
                        $img = $cachefile;
                    }
                    else {
                        debug( "ERROR", "unknown could not fetch $img" );
                    }
                }
                else {
                    debug( "ERROR", "unknown protocol for $img" );
                }
            }
        }
    }

    # make sure we add the image size if its not already there
    if ( $want_size && $pre !~ /width=|height=/i && $post !~ /width=|height=/i ) {
        my $image = GD::Image->new($img);
        if ($image) {
            $post =~ s/\/>$//;
            $post .= " height='" . $image->height() . "' width='" . $image->width() . "' />";
        }
    }

    # do we need to embed the images, if we do this then libreoffice may be pants
    # however 'prince' is happy
    if ( $self->embed() ) {

        # we encode the image as base64 so that the HTML document can be moved with all images
        # intact
        my $base64 = MIME::Base64::encode( read_file($img) );
        $img = "data:image/$ext;base64,$base64";
    }
    return $pre . $img . $post;
}

# ----------------------------------------------------------------------------
# grab all the h2/h3 elements and make them toc items

sub _build_toc {
    my $html = shift;

    my @items = ( $html =~ m|<h[23].*?><a name=['"'](.*?)['"]>(.*?)</a></h[23]>|gsm );

    my $toc = "<p>Contents</p>\n<ul>\n";
    for ( my $i = 0; $i < scalar(@items); $i += 2 ) {
        my $ref = $items[$i];

        my $h = $items[ $i + 1 ];

        # remove any href inside the header title
        $h =~ s/<\/?a.*?>//g;

        if ( $h =~ /^\d\./ ) {
            $h = "&nbsp;&nbsp;&nbsp;$h";
        }

        # make sure reference is in lower case
        $toc .= "  <li><a href='#$ref'>$h</a></li>\n";
    }

    $toc .= "</ul>\n";

    return $toc;
}

# ----------------------------------------------------------------------------
# rewrite the headers so that they are nice for the TOC
sub rewrite_hdrs {
    state $counters = { 2 => 0, 3 => 0, 4 => 0 };
    state $last_lvl = 0;
    my ( $head, $txt, $tail ) = @_;
    my $pre;

    my ($lvl) = ( $head =~ /<h(\d)/i );
    my $ref = $txt;

    if ( $lvl < $last_lvl ) {
        debug( "ERROR", "something odd happening in rewrite_hdrs" );

        # if ( $lvl == 3 ) {
        #     $counters->{4} = 0;
        # }
        # elsif ( $lvl == 2 ) {
        #     $counters->{3} = 0;
        #     $counters->{4} = 0;
        # }
    }
    elsif ( $lvl > $last_lvl ) {

        # if we are stepping back up a level then we need to reset the counter below
        if ( $lvl == 3 ) {
            $counters->{4} = 0;
        }
        elsif ( $lvl == 2 ) {
            $counters->{3} = 0;
            $counters->{4} = 0;
        }

    }
    $counters->{$lvl}++;

    if    ( $lvl == 2 ) { $pre = "$counters->{2}"; }
    elsif ( $lvl == 3 ) { $pre = "$counters->{2}.$counters->{3}"; }
    elsif ( $lvl == 4 ) { $pre = "$counters->{2}.$counters->{3}.$counters->{4}"; }

    $ref =~ s/\s/_/gsm;

    # remove things we don't like from the reference
    $ref =~ s/[\s'"\(\)\[\]<>]//g;

    my $out = "$head<a name='$pre" . "_" . lc($ref) . "'>$pre $txt</a>$tail";
    return $out;
}

# ----------------------------------------------------------------------------
# use pandoc to parse markdown into nice HTML
# pandoc has extra features over and above markdown, eg syntax highlighting
# and tables

sub pandoc {
    my $input = shift;

    my $resp = execute_cmd(
        command     => "$ENV{HOME}/bin/pandoc --email-obfuscation=none -S -R --normalize -t html5 --highlight-style='kate' ",
        timeout     => 30,
        child_stdin => $input
    );

    my $html;

    debug( "Pandoc: " . $resp->{stderr} ) if ( $resp->{stderr} );
    if ( !$resp->{exit} ) {
        $html = $resp->{stdout};
    }
    else {
        debug( "ERROR", "Could not parse with pandoc" );
        $html = markdown($input);
    }

    return $html;
}

# ----------------------------------------------------------------------------
# parse the data
sub parse {
    my $self = shift;
    my $data = shift;

    die "Nothing to parse" if ( !$data );

    my $id = md5_hex( encode_utf8($data) );

    # my $id = md5_hex( $data );
    $self->_set_md5id($id);
    $self->_set_input($data);

    my $cachefile = $self->_in_cache("$id.html");
    if ($cachefile) {
        my $cache = read_file( $cachefile, binmode => ':utf8' );
        $self->_set_output($cache);    # put cached item into output
    }
    else {
        $cachefile = $self->cache_dir() . "/$id.html";
        $self->_set_output("");        # blank the output

        my %keywords;
        my @lines = split( /\n/, $data );

        # process top 20 lines for keywords
        for ( my $i = 0; $i < 20; $i++ ) {
            ## if there is no keyword separator then we mush have done the keywords
            last if ( $lines[$i] !~ /:/ );

            # allow keywords to be :keyword or keyword:
            my ( $k, $v ) = ( $lines[$i] =~ /^:?(\w+):?\s+(.*?)\s?$/ );
            next if ( !$k );
            $keywords{$k} = $v;

            $lines[$i] = '';    # essentially remove the line
        }

        # rebuild the page string
        $data = join( "\n", @lines );

        $self->_set_keywords( \%keywords );

        my $style;
        foreach my $k ( keys %keywords ) {

            # grab the style from the document
            my $word = "%" . uc($k) . "%";

            # tags/keywords are synonomus
            if ( lc($k) =~ /keywords|tags/ ) {
                $self->{replace}->{'%TAGS%'}     = $keywords{$k};
                $self->{replace}->{'%KEYWORDS%'} = $keywords{$k};
            }
            else {
                $self->{replace}->{$word} = $keywords{$k};
            }

            # $data =~ s/^:$k\s+$keywords{$k}*$//gmi;
        }

        # now we need to do any replacements that have been passed to us for the
        # body of the text
        foreach my $k ( keys %{ $self->replace() } ) {
            next if ( !$self->{replace}->{$k} );
            $data =~ s/$k/$self->{replace}->{$k}/gsm;
        }

        # make sure there is no leading space at the start of the story
        # $data =~ s/^\s+(#.*)/$1/sm;

        # lets strip out any HTML comments before we proceed
        # $data =~ s/<!--.*?-->//gsm;

        # parse the data find a XML tag and recurse for any others
        $self->_parse_token($data);

        # store the markdown before parsing
        $self->_store_cache( $self->cache_dir() . "/$id.md", encode_utf8( $self->_output() ) );

        # parse tiddlywiki type tables
        # $self->{_output} =~ s/\n\n(\s*[!\|].*?|)\n\n/html_table( $1)/egsm;

        # fixup any markdown simple tables | ------ | -> |---------|

        my @tmp = split( /\n/, $self->{_output} );
        my $done = 0;
        for ( my $i = 0; $i < scalar @tmp; $i++ ) {
            if ( $tmp[$i] =~ /^\|[\s\|\-\+]+$/ ) {
                $tmp[$i] =~ s/\s/-/g;
                $done++;
            }
        }
        $self->{_output} = join( "\n", @tmp ) if ($done);

        # we have created something so we can cache it, if use_cache is off
        # then this will not happen lower down
        # now we convert the parsed output into HTML
        my $html = $self->html_header . pandoc( $self->_output() ) . $self->html_footer;

        # build a table of contents, if the html wants it
        if ( $html =~ /%TOC%/ ) {
            $html =~ s|(<h[234].*?>)(.*?)(</h[234]>)|rewrite_hdrs( $1, $2, $3)|egsi;

            $self->{replace}->{'%TOC%'} = _build_toc($html);

            # if the user has not used :title, the we need to grab the title from the page so far
            if ( !$self->{replace}->{'%TITLE%'} ) {
                ( $self->{replace}->{'%TITLE%'} ) = ( $html =~ m|<h1.*?>(.*?)</h1>|smi );
            }
        }

        # do any final replacements due to changes elsewhere
        foreach my $k ( keys %{ $self->replace() } ) {
            next if ( !$self->{replace}->{$k} );
            $html =~ s/$k/$self->{replace}->{$k}/gsm;
        }

        # and remove any %word% things that are not processed
        $html =~ s/\%\w+\%//gsm;

        # fetch any images and store to the cache, make sure they have sizes too
        $html =~ s/(<img.*?src=['"])(.*?)(['"].*?>)/$self->rewrite_imgsrc( $1, $2, $3, 1)/egs;

        # write any css url images and store to the cache
        $html =~ s/(url\s*\(['"]?)(.*?)(['"]?\))/$self->rewrite_imgsrc( $1, $2, $3, 0)/egs;

        # strip out any HTML comments that may have come in from header/footer
        $html =~ s/<!--.*?-->//gsm;

        $self->_set_output($html);
        $self->_store_cache( $cachefile, $self->_output );
    }
    return $self->_output;
}

# ----------------------------------------------------------------------------

=item save_to_file

save the created html to a named file
=cut

sub save_to_file {
    state $counter = 0;
    my $self = shift;
    my ( $filename, $prince ) = @_;
    my ($format) = ( $filename =~ /\.(\w+)$/ );    # get last thing after a '.'
                                                   # $format |= '.pdf' ;

    my $f = $self->_md5id() . ".html";

    # have we got the parsed data
    my $cf = $self->_in_cache($f);
    if ( !$self->_output() ) {
        die "parse has not been run yet";
    }

    if ( !-f $cf ) {
        if ( !$self->use_cache() ) {

            # create a file name to store the output to
            $cf = "/tmp/" . get_program() . "$$." . $counter++;
        }

        # either update the cache, or create temp file
        #        write_file( $cf, {binmode => ':utf8'}, $self->_output() );
        write_file( $cf, { binmode => ':utf8' }, encode_utf8( $self->_output() ) );

        # write_file( $cf, $self->_output() );
    }

    my $outfile = $cf;
    $outfile =~ s/\.html$/.$format/i;

    # if the marked-up file is more recent than the converted one
    # then we need to convert it again
    if ( $format !~ /html/i ) {
        if ( !-f $outfile || ( ( stat($cf) )[9] > ( stat($outfile) )[9] ) ) {
            $outfile = convert_file( $cf, $format, $prince );

            # if we failed to convert, then clear the filename
            if ( !$outfile || !-f $outfile ) {
                $outfile = undef;
                debug( "ERROR", "failed to create output file from cached file $cf" );
            }
        }
    }

    my $status = 0;

    # now lets copy it to its final resting place
    if ($outfile) {
        try {
            # say "copying $outfile $filename" ;
            $status = copy( $outfile, $filename );
        }
        catch {
            say STDERR "$_ ";
            debug( "ERROR", "failed to copy $outfile to $filename" );
        };
    }
    return $status;
}

# ----------------------------------------------------------------------------

1;

__END__
