
=head1 NAME

App::Basis::ConvertText2::Plugin::Graphviz

=head1 SYNOPSIS

    my $content = "digraph G {
      subgraph cluster_0 {
        style=filled;
        color=lightgrey;
        node [style=filled,color=white];
        a0 -> a1 -> a2 -> a3;
        label = "process #1";
      }

      subgraph cluster_1 {
        node [style=filled];
        b0 -> b1 -> b2 -> b3;
        label = "process #2";
        color=blue
      }
      start -> a0;
      start -> b0;
      a1 -> b3;
      b2 -> a3;
      a3 -> a0;
      a3 -> end;
      b3 -> end;

      start [shape=Mdiamond];
      end [shape=Msquare];
    }" ;
    my $params = {
        size   => "600x480",
    } ;
    my $obj = App::Basis::ConvertText2::Plugin::Graphviz->new() ;
    my $out = $obj->process( 'graphviz', $content, $params) ;

=head1 DESCRIPTION

convert a graphviz text string into a SVG requires uml program and plantuml jar
from https://github.com/27escape/bin/blob/master/uml and http://plantuml.sourceforge.net

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Graphviz ;

use 5.10.0 ;
use strict ;
use warnings ;
use Moo ;
use Path::Tiny ;
use App::Basis ;
use App::Basis::ConvertText2::Support ;
use namespace::autoclean ;

# uml is a script to run plantuml basically does java -jar plantuml.jar
use constant UML => "uml" ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{graphviz dot mindmap}] }
) ;

# ----------------------------------------------------------------------------

# now that plantuml is being used instead of graphviz directly
# we lose the ability to use some of the different layout style programs
my %commands = map { $_ => $_ } qw( dot neato twopi fdp sfdp circo osage patchwork) ;

my %drawing_specific = (
    dot       => "",
    neato     => "",
    twopi     => "",
    fdp       => "",
    sfdp      => "",
    circo     => "",
    osage     => "pack=16",
    patchwork => "center=1\nmode=scale",
) ;

# ----------------------------------------------------------------------------

=item graphviz dot

create a simple graphviz structured graph image, from the passed text

 parameters
    data   - graphviz text
    filename - filename to save the created image as

 hashref params of
        size    - size of image, widthxheight - optional
        layout - graphviz command to use to draw graph - optional
                - dot (default) neato twopi fdp sfdp circo osage
        width   - optional width
        height  - optional
        class   - optional
        title   - optional set the alt text

=cut

sub graphviz
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    my $size = "" ;
    $params->{size} ||= "" ;
    my ( $x, $y ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ ) ;
    $x = $params->{width}  if ( $params->{width} ) ;
    $y = $params->{height} if ( $params->{height} ) ;
    $params->{title} ||= "" ;
    $params->{class} ||= "" ;
    $params->{layout} ||= $params->{command} ; # compatibility with old parameter name

    #my $command = $commands{dot} ;
    my $command = UML ;

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    if (   $params->{layout}
        && $commands{ $params->{layout} }
        && $content !~ /^\s+layout=/ ) {
        $content =~ s/(graph\s.*?\s\{)/$1\nlayout=$params->{layout}/ ;
    }

    # we need to do this to enable plantuml to generate from graphviz format
    $content = "\@startdot\n$content\n\@enddot\n" ;
    delete $params->{layout} ;

    my $out ;

    # we can use the cache or process everything ourselves
    my $sig = create_sig( $content, $params ) ;
    my $filename = cachefile( $cachedir, "$tag.$sig.svg" ) ;

    # path("/tmp/$tag.$sig.dot")->spew_utf8($content) ;

    if ( !-f $filename ) {
        my $dotfile = Path::Tiny->tempfile("graphviz.XXXX") ;
        path($dotfile)->spew_utf8($content) ;
        my $cmd ;
        $cmd = $command . " -s $dotfile $filename" ;
        my ( $exit, $stdout, $stderr ) = run_cmd($cmd) ;
        if ($exit) {
            if ( $params->{layout} ) {
                warn "You need to install Graphviz" ;
            } else {
                warn
                    "You need to install PlantUml and the get the uml script from https://github.com/27escape/bin/blob/master/uml"
                    ;
            }
        } elsif ( $stderr =~ /Syntax Error/i ) {

            # make sure that there is no file
            unlink($filename) ;
            warn("Syntax error in $tag") ;
            $out = "**Syntax Error** in $tag\n\n" ;
        }
    }

    if ( -f $filename ) {

        # create something suitable for the HTML
        my $s = "" ;
        $s .= " width='$x'"  if ($x) ;
        $s .= " height='$y'" if ($y) ;

        $out = "<img src='$filename' class='$tag $params->{class}' alt='$params->{title}' $s />" ;
    }
    return $out ;
}

my $head = "graph mindmap {
    graph [fontname = \"helvetica\"];
    node [fontname = \"helvetica\"];
    edge [fontname = \"helvetica\"];
    splines=curved;
    center=true;
    rankdir=LR;
    node [ shape=circle, style=\"rounded,filled\", color=\"black\"] ;
    edge [ style=tapered, penwidth=2, arrowtail=none, arrowhead=none, dir=forward, color=grey50] ;
" ;

my $foot = "}\n" ;

# ----------------------------------------------------------------------------

=item mindmap

create a simple mindmap, from the passed text

 parameters
    data   - bulleted list
    filename - filename to save the created image as

 hashref params of
        size    - size of image, widthxheight - optional
        width   - optional width
        height  - optional
        scheme  - color scheme to use - optional
                - default pastel28, see L<http://www.graphviz.org/content/color-names#brewer>
                - blue purple green grey mono orange red brown  are shortcuts
        shapes  - list of shapes to use - optional
                - default box ellipse hexagon octagon
        layout - graphviz command to use to draw graph - optional
                - dot neato twopi fdp (default) sfdp circo osage

=cut

sub mindmap
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    my $size = "" ;
    $params->{size} ||= "" ;

    $params->{layout} ||= "fdp" ;    # default mindmap layout
                                     # replace tabs with 4 spaces
    $content =~ s/\t/    /gsm ;

    my ( $scheme, $shapelist ) = ( $params->{scheme}, $params->{shapes} ) ;
    my $out ;
    my $level       = 0 ;
    my @lines       = split( /\n/, $content ) ;
    my $header      = "" ;
    my $links       = "" ;
    my @parent      = () ;
    my @shapes      = qw( box ellipse hexagon octagon) ;
    my $colorscheme = "pastel28" ;
    my $last        = -1 ;

    $header =
          $params->{layout} && $commands{ $params->{layout} }
        ? $drawing_specific{ $params->{layout} } . "\n"
        : "" ;

    if ($scheme) {
        my %s = (
            blue   => 'blues9',
            purple => 'bupu9',
            green  => 'greens9',
            grey   => 'greys9',
            mono   => 'greys9',
            orange => 'oranges9',
            red    => 'reds9',
            brown  => 'ylorbr9'
        ) ;

        # check if its one of our quick names
        if ( $s{$scheme} ) {
            $colorscheme = $s{$scheme} ;
        } else {
            # assume its a good name
            $colorscheme = $scheme ;
        }
    }
    if ($shapelist) {
        @shapes = split( /[\s,]/, $shapelist ) ;
    }

    for ( my $id = 0; $id < scalar(@lines); $id++ ) {
        my $font  = "black" ;
        my $shape = "" ;
        my $color = "" ;
        $lines[$id] =~ s/\s+$// ;    # remove trailing space
        next if ( !$lines[$id] ) ;   # ignore blank lines

        my ( $spaces, $txt ) = ( $lines[$id] =~ /^(\s+)?[\*\+\-]\s+(.*)/ ) ;
        next if ( !$txt ) ;

        # remove comments
        $txt =~ s/\s:.*// ;
        $txt =~ s/\s+$// ;
        next if ( !$txt ) ;

        # what about a colour
        if ( $txt =~ s|#(\w+)\s?$|| ) {
            $color = $1 ;
        } elsif ( $txt =~ s|#(\w+)?\/(\w+)|| ) {
            $color = $1 if ($1) ;
            $font = $2 ;
        } elsif ( $txt =~ s|#(\w+)?\.(\w+)|| ) {
            $font = $1 if ($1) ;
            $color = $2 ;
        }
        $txt =~ s/\s+$// ;    # remove trailing spaces
                              # if the color is a number or hex
        $font  = "#$font"  if ( $font  && $font =~ /^[0-9a-f]+$/i ) ;
        $color = "#$color" if ( $color && $color =~ /^[0-9a-f]+$/i ) ;

        # is there shape information here
        if ( $txt =~ s/^\[(.*?)\]$/$1/ ) {
            $shape = 'box' ;
        } elsif ( $txt =~ s/^\((.*?)\)$/$1/ ) {
            $shape = 'ellipse' ;
        } elsif ( $txt =~ s/^\<(.*?)\>$/$1/ ) {
            $shape = 'diamond' ;
        } elsif ( $txt =~ s/^\{(.*?)\}$/$1/ ) {
            $shape = 'octagon' ;
        } elsif ( $txt =~ s/(shape=\s?(\w+)\s?)// ) {
            $shape = $2 ;
        }

        # basic style markup as HTML
        # replace bold
        $txt =~ s/\*\*(.*?)\*\*/<B>$1<\/B>/g ;

        # replace italic
        $txt =~ s/\*(.*?)\*/<I>$1<\/I>/g ;

        # replace newline
        $txt =~ s|\\n|<BR/>|g ;
        $txt =~ s|<br>|<BR/>|gi ;
        $txt =~ s/\s+$// ;    # remove trailing space

        # round up spaces as much as we can
        $spaces = length( $spaces || "" ) ;
        my $indent = 0 ;
        if ( $spaces > 0 ) {
            # calc the number of indents (4 spaces)
            $indent = ( int( $spaces / 4 ) + ( $spaces % 4 ? 1 : 0 ) ) ;
        }

        # are we setting a new parent level
        if ( $last != $indent && $level == $indent ) {
            # remove children
            @parent = splice( @parent, 0, $level ) ;
            $parent[$level] = $id ;

            # set root always to be an octagon
            $shape = 'doubleoctagon' ;
            $color = "/$colorscheme/1" ;
        } else {
            $level = $indent ;
            $parent[$indent] = $id ;
        }

        my $off = $level - 1 ? $level - 1 : 0 ;
        if ( !$shape ) {
            # decide shape based on level, wrap
            $shape = $shapes[ $off % scalar(@shapes) ] ;
        }

        if ( !$color ) {
            # decide color in colorscheme based on level
            my $c = $indent + 1 ;
            $color = "/$colorscheme/$c" ;
        }

        # don't link root to root
        if ( $parent[$off] && $parent[$off] ) {
            # $links .= "  $parent[$off] -> $id\n";
            $links .= "  $parent[$off] -- $id\n" ;
        } else {
            # add link to root, but not root to root
            # $links .= "  0 -> $id\n" if ( $id != 0 );
            $links .= "  0 -- $id\n" if ( $id != 0 ) ;
        }
        $header
            .= "  $id [label=<$txt> shape=\"$shape\" fillcolor=\"$color\" fontcolor=\"$font\" ]\n" ;

        $last = $indent ;
    }

    $out = $head . $header . $links . $foot ;

    # pass any other commands through to graphviz to handle
    return $self->graphviz( 'mindmap', $out, $params, $cachedir ) ;
}

# ----------------------------------------------------------------------------
# decide which simple handler should process this request

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    # my %alt = ( dot => 'graphviz' ) ;

    if ( $self->can($tag) ) {
        return $self->$tag(@_) ;
    }
    return undef ;
}

# ----------------------------------------------------------------------------

1 ;
