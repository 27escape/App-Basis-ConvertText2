
=head1 NAME

App::Basis::ConvertText2::Plugin::Uml

=head1 SYNOPSIS

    my $content = "' this is a comment on one line
    /' this is a
    multi-line
    comment'/
    Alice -> Bob: Authentication Request
    Bob --> Alice: Authentication Response

    Alice -> Bob: Another authentication Request
    Alice <-- Bob: another authentication Response
    " ;
    my $params = {} ;
    my $obj = App::Basis::ConvertText2::Plugin::Uml->new() ;
    my $out = $obj->process( 'uml', $content, $params) ;

=head1 DESCRIPTION

convert a uml text string into a PNG, requires uml program and plantuml
from https://github.com/27escape/bin/blob/master/uml and http://plantuml.sourceforge.net

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Uml ;

use 5.10.0 ;
use strict ;
use warnings ;
use Path::Tiny ;
use Moo ;
use App::Basis ;
use App::Basis::ConvertText2::Support ;
use namespace::autoclean ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{plantuml uml umltree ditaa project}] }
) ;

# uml is a script to run plantuml basically does java -jar plantuml.jar
# plantuml includes graphviz, so generally we could bring all of that stuff here
use constant UML => "uml" ;

# ----------------------------------------------------------------------------

my $default_css = <<END_CSS;
    /* Uml.pm css */

    figure {
      display: table;
    }
    /* standard 'title' captions on top */
    figcaption, figcaption.title {
        display: table-caption;
        caption-side: top;
        font-size: 70%;
        text-align: center;
    }
    /* 'footer' captions underneath */
    figcaption.footer {
        caption-side: bottom ;
/*        font-size: 70%;*/
    }

END_CSS

# ----------------------------------------------------------------------------

=item uml

create a simple uml image

 parameters
    data   - uml text
    filename - filename to save the created image as

 hashref params of
        size    - size of image, widthxheight - optional
        width   - optional width
        height  - optional
        class   - optional
        title   - optional set the alt text and above the image
        caption - optional set the caption below the image
        png     - optional, force output to be png rather than svg
        mono or bw  use black and white skin, UML only
        sketch  - handsketch the images rather than draw then, UML only
        line    - type of line between nodes poly(line), ortho|square|straight, normal
        align   - option, set alignment of image
        shadow  - show a shadow, default = 1
        teoz    - use teoz layout pragma

        'no-shadow'     -  ditaa specific
        'no-separation' - ditaa specific
        'round-corners' - ditaa specific

=cut

sub uml
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir, $linenum ) = @_ ;
    $params->{size} ||= "" ;
    my ( $x, $y ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ ) ;
    $x = $params->{width}  if ( $params->{width} ) ;
    $y = $params->{height} if ( $params->{height} ) ;
    $params->{align} ||= "left" ;
    $params->{title} ||= "" ;
    $params->{caption} ||= "" ;
    $params->{class} ||= "" ;
    $params->{line}  ||= "normal" ;
    $params->{shadow} //= 1 ;
    $params->{shadow} = 0 if $params->{"no-shadow"} ;

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    # sudoku outputs an image
    $params->{png} = 1 if ( $content =~ /^sudoku(\s?\w+)?$/ism || $content =~ /\@startsalt/ ) ;

    my $extra = "" ;
    if ( $tag eq 'uml' ) {
        $extra .= "skinparam handwritten true\n" if ( $params->{sketch} ) ;
        $extra .= "skinparam monochrome true\n"
            if ( $params->{bw} || $params->{mono} ) ;

        # normal line type does not need a skinparam
        if ( $params->{line} =~ '^poly(line)?' ) {
            $extra .= "skinparam linetype polyline\n" ;
        } elsif ( $params->{line} =~ '^ortho|^square|^straight' ) {
            $extra .= "skinparam linetype ortho\n" ;
        }
# new feature http://forum.plantuml.net/7334/disable-style-heigth-attributes-exported-scaling-browsers
# may help with image scaling, should only use it if we are specifying the image size
        $extra .= "skinparam svgDimensionStyle false\n" if ( !$params->{png} && ( $x || $y ) ) ;
        if ( $tag ne 'ditaa' ) {
            $extra .= "skinparam shadowing false\n" if ( !$params->{shadow} ) ;
            $extra .= "!pragma teoz true\n" if ( $params->{teoz} && $params->{teoz} !~ /false/i ) ;
        }
        # uml specially needs start and end tags
        # however lets not check for @start$tag in case we want to support
        # other things ie @startmath etc
        $content = "\@start$tag\n$content"
            if ( $content !~ /\@start\w+/ ) ;

        # our extra stuff has to happen just after the @start tag
        $content =~ s/(\@start.*?\n)/$1$extra/gsm if ($extra) ;

        $content .= "\n\@end$tag" if ( $content !~ /\@end\w+/ ) ;
    }

    my $out ;
    my $ext = "svg" ;
    my $svg = "-s" ;
    if ( $params->{png} ) {
        $ext = "png" ;
        $svg = "" ;
    }
    # we can use the cache or process everything ourselves
    my $sig = create_sig( $content, $params ) ;
    my $filename = cachefile( $cachedir, "$tag.$sig.$ext" ) ;

    # path("$tag.$sig.uml")->spew_utf8($content) ;

    # only generate the file if we do not already have it
    if ( !-f $filename ) {
        if ( $tag eq 'ditaa' ) {
            my $args = "" ;
            $args .= "-S, "              if ( !$params->{shadow} ) ;
            $args .= "-E, "              if ( $params->{'no-separation'} ) ;
            $args .= "--round-corners, " if ( $params->{'round-corners'} ) ;
            $args =~ s/,\s?$// ;
            path("/tmp/ditaa.log")->append("$$ has $content") ;
            $args = "($args)" if ($args) ;
            path("/tmp/ditaa.log")->append("$$ has args $args") ;
            $content = "\@start$tag$args\n$content\n\@end$tag" ;
            path("/tmp/ditaa.$$")->spew_utf8($content) ;
        }

        # # we are lucky that plantuml can have image sizes
        # if ( $x && $y ) {
        #     $content =~ s/\@startuml/\@startuml\nscale $x*$y\n/;
        # }
        my $umlfile = Path::Tiny->tempfile("umlXXXXXXXX") ;

        path($umlfile)->spew_utf8($content) ;

        my $cmd = UML . " $svg $umlfile $filename" ;
        # verbose("cmd: $cmd") ;
        my ( $exit, $stdout, $stderr ) = run_cmd($cmd) ;
        if ($exit) {
            verbose("exit value $exit") ;
            verbose("stdout: $stdout") if ($stdout) ;
            verbose("stderr: $stderr") if ($stderr) ;
            $linenum //= '??' ;
            if ( $exit == 1 && !$stderr && !$stdout ) {
                # warn "Could not run script " . UML
                #     . " get it from https://github.com/27escape/bin/blob/master/uml" ;
                $out = warning_box(
                    $tag,
                    "not installed",
                    "This tag requires uml, obtain it from https://github.com/27escape/bin/blob/master/uml. \n\nAlso install plantUML from http://plantuml.com/download"
                ) ;
            } else {
                # warn "Issue with tag $tag on line $linenum" ;
                $out = warning_box( $tag, "Processing Error", $stderr ) ;
            }
        } elsif ( $stderr =~ /Syntax Error/i ) {
            # make sure that there is no file
            # unlink($filename) ;
            # warn("Syntax error in $tag") ;
            $out = warning_box( $tag, "Syntax error", $stderr ) ;
        } elsif ($stderr) {
            $out = warning_box( $tag, "Unknown error", $stderr ) ;
        }

    }
    # now check if a file was generated and apply size and alignment
    if ( -f $filename ) {

        # create something suitable for the HTML
        my $s = "" ;
        my $width= "" ;
        if ($x) {
            $s .= " width='$x'"   ;
            $width = "width: " . $x . "px;" ;
        }
        $s .= " height='$y'" if ($y) ;

        if ( $params->{align} ) {
            $params->{align} =~ s/middle/center/i ;
            $params->{align} =~ s/centre/center/i ;
        }
        $out = "<figure style='text-align:$params->{align};$width'>" ;
        if( $params->{title}) {
            $out .= "<figcaption class='title'>$params->{title}</figcaption>" ;
        }
        if( $params->{caption}) {
            $out .= "<figcaption class='footer'>$params->{caption}</figcaption>" ;
            # use as the alt text if there is no title
            $params->{title} ||= $params->{caption} ;
        }
        $out .= "<img src='$filename' class='$tag $params->{class}' alt='$params->{title}' $s />" ;
        $out .= "</figure>" ;
    }

    return $out ;
}

# ----------------------------------------------------------------------------

=item umltree

create a tree using plantuml's salt

Draw a bulleted list like a directory tree, bullets are expected to be indented
by 4 spaces, we will only process bullets that are * +  or -

    ~~~~{.umltree}
    * one
        * 1.1
    * two
        * two point 1
        * 2.2
    * three
        * 3.1
        * 3.2
        * three point 3
    ~~~~

=cut

sub umltree
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir, $linenum ) = @_ ;

    my @lines = split( /\*/, $content ) ;

    if ( !$params->{size} && !$params->{height} ) {
        $params->{height} = ( scalar(@lines) * 20 ) . "px" ;
    }

    # make sure we have no tabs
    $content =~ s/\t/    /gsm ;

    # do twice to get bold with italic and vice versa
    for ( my $i = 0; $i < 2; $i++ ) {
        # make bold things
        $content =~ s/(\*{2,2})\b([\w+-\\\/]+)\b\1/<b>$2<\/b>/gsm ;
        # and others italic
        $content =~ s/(\*{1,1})\b([\w+-\\\/]+)\b\1/<i>$2<\/i>/gsm ;
    }

    # make bullet points all the same
    $content =~ s/(^\s+)[\+-]/$1*/gsm ;
    $content =~ s/\*/+/gsm ;
    $content =~ s/    /+/gsm ;
    $content =~ s/^\+/ ++/gsm ;

    my $out = "
\@startsalt
{
{T
 +
$content
}
}
\@endsalt
" ;

    $params->{png} = 1 ;
    # and process with the normal uml command
    return $self->uml( $tag, $out, $params, $cachedir, $linenum ) ;
}

# ----------------------------------------------------------------------------

=item ditaa

create a ditaa using plantuml's support

Draw a bulleted list like a directory tree, bullets are expected to be indented
by 4 spaces, we will only process bullets that are * +  or -

    ~~~~{.ditaa}
    Full example
    +--------+   +-------+    +-------+
    |        +---+ ditaa +--->|       |
    |  Text  |   +-------+    |diagram|
    |Document|   |!magic!|    |       |
    |     {d}|   |       |    |       |
    +---+----+   +-------+    +-------+
        :                         ^
        |       Lots of work      |
        \-------------------------+
    ~~~~

=cut

sub ditaa
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir, $linenum ) = @_ ;

    $params->{png}             = 1 ;   # force PNG
                                       # default no shadows and no separaion, they need switching on
    $params->{'no-shadow'}     = 1 ;
    $params->{'no-separation'} = 1 ;
    if ( $params->{shadow} ) {
        delete $params->{shadow} ;
        delete $params->{'no-shadow'} ;
    }
    if ( $params->{shadow} ) {
        delete $params->{'no-separation'} ;
        delete $params->{separation} ;
    }

    # and process with the normal uml command
    return $self->uml( $tag, $content, $params, $cachedir, $linenum ) ;
}

# ----------------------------------------------------------------------------

=item project

draw a gantt chart from project information, http://plantuml.com/gantt-diagram

    ~~~~{.project}
    [configuration] as [t1] lasts 10 days
    [headend] as [t2] lasts 5 days
    [t2] is colored in Lavender/LightBlue
    [headend2] as [t3] lasts 5 days
    [t3] is colored in LightSteelBlue/crimson
    ~~~~

=cut

sub project
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir, $linenum ) = @_ ;

    # remove potential things that could cause issues
    map { delete $params->{$_} } qw( bw mono sketch) ;

    # uml specially needs start and end tags
    $content = "\@startuml\n$content"
        if ( $content !~ /\@startuml/ ) ;
    $content .= "\n\@enduml" if ( $content !~ /\@enduml/ ) ;

    # and process with the normal uml command
    return $self->uml( $tag, $content, $params, $cachedir, $linenum ) ;
}

# ----------------------------------------------------------------------------
# decide which simple hanlder should process this request

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir, $linenum ) = @_ ;
    state $css = 0 ;

    if ( !$css ) {
        add_css($default_css) ;
        # add_css( _admonition_css() ) ;
        $css++ ;
    }


    $tag = 'uml' if ( $tag eq 'plantuml' ) ;

    if ( $self->can($tag) ) {
        return $self->$tag(@_) ;
    }
    return undef ;
}

# ----------------------------------------------------------------------------

1 ;
