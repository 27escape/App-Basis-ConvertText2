
=head1 NAME

App::Basis::ConvertText2::Plugin::Blockdiag

=head1 SYNOPSIS

    my $content = "// branching edges to multiple children
  A -> B, C;

  // branching edges from multiple parents
  D, E -> F;" ;
    my $params = { 
        size   => "600x480",
    } ;
    my $obj = App::Basis::ConvertText2::Plugin::Blockdiag->new() ;
    my $out = $obj->process( 'blockdiag', $content, $params) ;
 
=head1 DESCRIPTION

convert a blockdiag, nwdiag, seqdiag and actdiag text strings into PNGs, 
requires blockdiag programs from L<http://blockdiag.com/en/>

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Blockdiag ;

use 5.10.0 ;
use strict ;
use warnings ;
use Path::Tiny ;
use App::Basis ;
use Moo ;
use App::Basis ;
use App::Basis::ConvertText2::Support ;
use namespace::autoclean ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default =>
        sub { [qw{blockdiag nwdiag actdiag seqdiag rackdiag packetdiag}] }
) ;

# ----------------------------------------------------------------------------

=item blockdiag nwdiag actdiag seqdiag

create a simple blockdiag image

 parameters
    data   - blockdiag/nwdiag/actdiag/seqdiag text      
    filename - filename to save the created image as 

 hashref params of
        size    - size of image, widthxheight - optional
        width   - optional width
        height  - optional
        class   - optional
        transparent - make background transparent - optional
        title   - optional set the alt text

=cut

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    $params->{size} ||= "" ;
    my ( $x, $y ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ ) ;
    $x = $params->{width}  if ( $params->{width} ) ;
    $y = $params->{height} if ( $params->{height} ) ;
    $params->{title}       ||= "" ;
    $params->{class}       ||= "" ;
    $params->{transparent} ||= 'true' ;

    my $args = "" ;
    # say STDERR "params " .Data::Printer::p( $params) ;
    my %allowed = ( transparent => { false => '--no-transparency ' }, ) ;

    foreach my $p (qw( transparent)) {
        next if ( !$params->{$p} ) ;
        if ( $params->{$p} =~ /^true$|^1$|^yes$/i ) {
            $args .= ( $allowed{$p}->{true} || '' ) ;
        } else {
            $args .= ( $allowed{$p}->{false} || '' ) ;
        }
    }

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    # we add the correct headers/footers to the data

    $content = "$tag {\n$content\n}\n" ;

    # we can use the cache or process everything ourselves
    my $sig = create_sig( $content, $params ) ;
    my $filename = cachefile( $cachedir, "$tag.$sig.svg" ) ;
    if ( !-f $filename ) {

        my $diagfile = Path::Tiny->tempfile("blockdiag.XXXX") ;

        path($diagfile)->spew_utf8($content) ;

        if ( $x && $y ) {
            $args .= " --size=$x" . "x$y " ;
        }
        my $cmd = "$tag $args -o $filename -T SVG $diagfile" ;
        # say STDERR $cmd ;
        my ( $exit, $stdout, $stderr ) = run_cmd($cmd) ;
        if ($exit) {
            warn
                "Could not run script $tag get it from http://blockdiag.com/en/"
                ;
        }
    }

    my $out ;
    if ( -f $filename ) {

        # create something suitable for the HTML
        my $s = "" ;
        $s .= " width='$x'"  if ($x) ;
        $s .= " height='$y'" if ($y) ;

        $out
            = "<img src='$filename' class='$tag $params->{class}' alt='$params->{title}' $s />"
            ;
    }
    return $out ;

}

# ----------------------------------------------------------------------------

1 ;
