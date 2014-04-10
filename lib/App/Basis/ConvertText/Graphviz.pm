
=head1 NAME

 App::Basis::ConvertText::Graphviz

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 convert a graphviz text string into a PNG, requires dot program

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 1999, now updated to become App::Basis::ConvertText::Graphviz

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Graphviz;

use 5.10.0;
use strict;
use warnings;
use App::Basis ;
use File::Temp qw(tempfile) ;
use File::Slurp qw(write_file) ;
use Exporter;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( graphviz);

# ----------------------------------------------------------------------------
use constant GRAPHVIZ => 'dot' ;
use constant DPI => 72 ;

BEGIN {
    my ($r, $o, $e) = run_cmd( GRAPHVIZ . " -h") ;  # try help
    die "Could not find " . GRAPHVIZ if( $r != 1) ;
}

# ----------------------------------------------------------------------------

=item graphviz

create a simple graphviz structured graph image, from the passed text

 parameters
    data   - graphviz text      
    filename - filename to save the created image as 

 hashref params of
        size    - size of image, widthxheight - optional

=cut
sub graphviz {
    my ( $text, $filename, $params ) = @_;
    $params->{size} ||= "" ;
    my $size = "" ;
    my ( $x, $y ) = ($params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/);

    my ($fh, $dotfile) = tempfile( "/tmp/graphviz.XXXX");

    if( $x && $y) {
        $size = sprintf( "  size=\"%.5f,%.5f\";", $x / DPI, $y / DPI) ;
        # add calculated image size to the graph
        $text =~ s/(digraph.*?)$/$1\n$size\n/sm ;
    }


    write_file( $dotfile, $text) ;

    my $cmd = GRAPHVIZ . " -Tpng -o$filename $dotfile" ;

    my ( $exit, $stdout, $stderr) = run_cmd( $cmd) ;

    return $exit == 0 ? 1 : 0 ;
}

# ----------------------------------------------------------------------------

1;
