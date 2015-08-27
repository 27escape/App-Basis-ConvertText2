
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
    default  => sub { [qw{plantuml uml umltree }] }
) ;

# uml is a script to run plantuml basically does java -jar plantuml.jar
use constant UML => "uml" ;

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
        title   - optional set the alt text
        png     - optional, force output to be png rather than svg
        align   - option, set alignment of image

=cut

sub uml
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    $params->{size} ||= "" ;
    my ( $x, $y ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ ) ;
    $x = $params->{width}  if ( $params->{width} ) ;
    $y = $params->{height} if ( $params->{height} ) ;
    $params->{title} ||= "" ;
    $params->{class} ||= "" ;

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    # sudoku outputs an image
    $params->{png} = 1 if ( $content =~ /^sudoku(\s?\w+)?$/ism ) ;

    my $ext = "svg" ;
    my $svg = "-s" ;
    if ( $params->{png} ) {
        $ext = "png" ;
        $svg = "" ;
    }
    # we can use the cache or process everything ourselves
    my $sig = create_sig( $content, $params ) ;
    my $filename = cachefile( $cachedir, "$tag.$sig.$ext" ) ;
    if ( !-f $filename ) {

        $content = "\@startuml\n$content" if ( $content !~ /\@startuml/ ) ;
        $content .= "\n\@enduml" if ( $content !~ /\@enduml/ ) ;

        # # we are lucky that plantuml can have image sizes
        # if ( $x && $y ) {
        #     $content =~ s/\@startuml/\@startuml\nscale $x*$y\n/;
        # }
        my $umlfile = Path::Tiny->tempfile("umlXXXXXXXX") ;

        path($umlfile)->spew_utf8($content) ;

        my $cmd = UML . " $svg $umlfile $filename" ;
        my ( $exit, $stdout, $stderr ) = run_cmd($cmd) ;
        if ($exit) {
            warn "Could not run script "
                . UML
                . " get it from https://github.com/27escape/bin/blob/master/uml"
                ;
        }
    }
    my $out ;
    if ( -f $filename ) {

        # create something suitable for the HTML
        my $s = "" ;
        $s .= " width='$x'"  if ($x) ;
        $s .= " height='$y'" if ($y) ;

        if( $params->{align}) {
            $params->{align} =~ s/middle/center/i ;
            $params->{align} =~ s/centre/center/i ;
            $out = "<div style='text-align:$params->{align};width:100%;'>" ;
        }
        $out .= "<img src='$filename' class='$tag $params->{class}' alt='$params->{title}' $s />" ;
        if( $params->{align}) {
            $out .= "</div>";
        }
    }

    return $out ;
}

# ----------------------------------------------------------------------------

=item umltree

create a tree using plantuml's salt 

Draw a bulleted list like a directory tree, bullets are expected to be indented 
by 4 spaces, we will only process bullets that are * +  or -

    ~~~~{.tree} 
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
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    my @lines = split( /\*/, $content ) ;

    if ( !$params->{size} && !$params->{height} ) {
        $params->{height} = (scalar(@lines) * 20) . "px"  ;
    }

    # make sure we have no tabs
    $content =~ s/\t/    /gsm ;

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

    # and process with the normal uml command
    return $self->uml( $tag, $out, $params, $cachedir ) ;
}

# ----------------------------------------------------------------------------
# decide which simple hanlder should process this request

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    $tag = 'uml' if ( $tag eq 'plantuml' ) ;

    if ( $self->can($tag) ) {
        return $self->$tag(@_) ;
    }
    return undef ;
}

# ----------------------------------------------------------------------------

1 ;
