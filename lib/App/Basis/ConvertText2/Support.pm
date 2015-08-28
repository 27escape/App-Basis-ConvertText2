
=head1 NAME

App::Basis::ConvertText2::Support

=head1 SYNOPSIS

=head1 DESCRIPTION

Support functions for L<App::Basis::ConvertText2> and its plugins

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Support ;

use 5.10.0 ;
use strict ;
use warnings ;
use Path::Tiny ;
use Digest::MD5 qw(md5_hex) ;
use Encode qw(encode_utf8) ;
use GD ;
use Cwd ;
use App::Basis ;
use Exporter ;
use utf8 ;
use WebColors ;

use vars qw( @EXPORT @ISA) ;

@ISA = qw(Exporter) ;

# ----------------------------------------------------------------------------
# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw(
    cachefile
    create_sig
    create_img_src
    get_css
    add_css
    get_javascript
    add_javascript
    phantomjs
    add_block
    has_block
    run_block
    to_hex_color
    split_colors
    ) ;

# ----------------------------------------------------------------------------
# phantomjs script to get the contents of a webpage element after it has been rendered
# useful to get SVGs from google charts or D3.js charts
# found at
# https://blogs.law.harvard.edu/jreyes/2012/12/13/render-d3-js-driven-svg-server-side/
# usage
# phantomjs (this_script) webpage element_to_extract

my $PHANTOM_JS = <<PHANTOM_JS;
var system = require('system');
 
if (system.args.length != 3) {
    console.log("Usage: " + system.args[0] + " ");
    phantom.exit(1);
}
 
var address = system.args[1];
var elementID = system.args[2];
var page = require('webpage').create();
 
function serialize(elementID) {
    var serializer = new XMLSerializer();
    var element = document.getElementById(elementID);
    return serializer.serializeToString(element);
}
 
function extract(elementID) {
  return function(status) {
    if (status != 'success') {
      console.log("Failed to open the page.");
    } else {
      var output = page.evaluate(serialize, elementID);
      console.log(output);
    }
  phantom.exit();
  };
}
 
page.open(address, extract(elementID));

PHANTOM_JS


# ----------------------------------------------------------------------------
# check if a file is in the cache, if so return the full file name
sub cachefile
{
    my ( $cache, $filename ) = @_ ;

    # make sure we are working in the right dir
    return $cache . "/" . path($filename)->basename ;
}

# ----------------------------------------------------------------------------

=item create_sig

create a signature based on content and params to a element

B<Params>
    content   - element content 
    params    - hashref of element params 

B<Returns>
    signature string

=cut

sub create_sig
{
    my ( $content, $params ) = @_ ;
    my $param_str
        = join( ' ', map { "$_='$params->{$_}'" ; } sort keys %$params ) ;

    return md5_hex( $content . encode_utf8($param_str) ) ;
}

# ----------------------------------------------------------------------------

=item create_img_src

create a HTML img element using the passed in filename, also grab the
image from the file and add its width and height to the attributes

B<Params>
    file    - filepath to an img file
    alt     - alt text to add to img element 

B<Returns>
    fixed img element

=cut

sub create_img_src
{
    my ( $file, $alt ) = @_ ;

    return "" if ( !$file ) ;
    $file = fix_filename($file) ;
    # return "src $file is missing" if( !-f $file) ;
    return "" if ( !-f $file ) ;

    my $out = "<img src='$file' " ;
    $out .= "alt='$alt' " if ($alt) ;

    my $image = GD::Image->new($file) ;
    if ($image) {
        $out
            .= "height='"
            . $image->height()
            . "' width='"
            . $image->width()
            . "' " ;
    }

    $out .= "/>" ;
    return $out ;
}

# ----------------------------------------------------------------------------
# simple getters/setters for css/javscript data
# keep things private
{
    my $css ;
    my $js ;

=item get_css

get the css data from our store

B<Returns>
    any added css data

=cut

    sub get_css
    {
        return $css ;
    }

=item add_css

add some css data to our store

B<Params>
    in   - the css to append to our stored css

=cut

    sub add_css
    {
        my ($in) = @_ ;

        $css .= "$in\n" if ($in) ;
    }

=item get_javascript

get the get_javascript data from our store

B<Returns>
    any added get_javascript data

=cut

    sub get_javascript
    {
        return $js ;
    }

=item add_javascript

add some javscript data to our store

B<Params>
    in   - the javscript to append to our stored css

=cut

    sub add_javascript
    {
        my ($in) = @_ ;

        $js .= "$in\n" ;
    }

}

# ----------------------------------------------------------------------------

=item phantomjs

run phantomjs on a passed HTML fragment and extract data from an element

B<Parameters>
    name    - HTML fragment to run with phantom
    element - element to extract data from

B<Returns>
    HTML

=cut

sub phantomjs
{
    my ( $html, $element, $keep, $cachedir ) = @_ ;

    $cachedir ||= "/tmp" ;

    my $pwd = cwd() ;
    my $h   = path("$cachedir/$element.$$.html") ;
    my $p   = path("$cachedir/$element.$$.js") ;
    $h->spew_utf8($html) ;
    $p->spew_utf8($PHANTOM_JS) ;

    chdir($cachedir) ;
    my $command
        = "phantomjs '"
        . $p->realpath . "' " . "'"
        . $h->realpath
        . "' '$element'" ;

    my $resp = execute_cmd(
        command => $command,
        timeout => 20,
    ) ;
    my $out = "" ;
    if ( !$resp->{exit_code} ) {
        $out = $resp->{stdout} ;
    } else {
        $out = "Could not run phantomjs: $resp->{stderr}<br>" ;
    }

    # for debuging we may want these to hang around
    if ( !$keep ) {
        unlink( $h->realpath ) ;
        unlink( $p->realpath ) ;
    }

    chdir($pwd) ;
    utf8::decode($out) ;
    return $out ;
}

# ----------------------------------------------------------------------------
# the block handlers
# keep things private
{
    my %valid_tags ;

=item add_block

add a block in our store

B<Parameters>
    name    - name of the block to add
    coderef - most likely a code ref to run

=cut

    sub add_block
    {
        my ( $block, $obj ) = @_ ;

        # we save blocks as lower case
        $valid_tags{ lc($block) } = $obj ;
    }

=item has_block

do we have a block in our store

B<Parameters>
    name    - name of the block to add

B<Returns>
    1/true if the bloke exists
    0/false if not

=cut

    sub has_block
    {
        my ($block) = @_ ;

        # if an incorrectly cased block is passed then it will fail
        return ( $block && $valid_tags{$block} ) ? 1 : 0 ;
    }


=item run_block

run a block in our store, call its process method

B<Parameters>
    block     - the name of the block, will fail if this is not lower case
    content   - the block content
    params    - parameters the block was given
    cachedir  - where the process block can store things

B<Returns>
    output from the process function or empty string

=cut

    sub run_block
    {
        my ( $block, $content, $params, $cachedir ) = @_ ;

        return "" if ( !has_block($block) ) ;

        my $out = $valid_tags{$block}
            ->process( $block, $content, $params, $cachedir ) ;
        return $out ;
    }
}

# ----------------------------------------------------------------------------

=item to_hex_color

when using colors, mke sure colour triplets etc get a hash in front
, actual triplets (ABC) will get expanded to (AABBCC)

B<Parameters>
    color     - the color to check

B<Returns>
    the color with a hash if needed, eg #AABBCC

=cut

sub to_hex_color
{
    my $c = shift ;

    if ($c) {
        if ( $c =~ /^\w+[50]0$/ ) {
            my $c2 = colorname_to_hex($c) ;
            $c = "#$c2" if ($c2) ;
        } else {
            $c =~ s/^([0-9a-f])([0-9a-f])([0-9a-f])$/#$1$1$2$2$3$3/i ;
            $c =~ s/^([0-9a-f]{6})$/#$1/i ;
        }
    }
    return $c ;
}


# ----------------------------------------------------------------------------

=item split_colors

Split a #foreground.background color string into its components

B<Parameters>
    colorstring   - the color to split

B<Returns>
    array foreground color, background color

=cut

sub split_colors
{
    my ($colors) = @_ ;
    my ( $fg, $bg ) ;

    if ( $colors =~ s/#((\w+)?\.?(\w+)?)// ) {
        ( $fg, $bg ) = ( $2, $3 ) ;
        $fg = to_hex_color($fg) if ($fg) ;
        $bg = to_hex_color($bg) if ($bg) ;
    } else {
        $fg = $colors ;
    }

    return ( $fg, $bg ) ;
}

# ----------------------------------------------------------------------------

1 ;

__END__
