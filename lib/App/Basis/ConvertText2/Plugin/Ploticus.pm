
=head1 NAME

App::Basis::ConvertText2::Plugin::Ploticus

=head1 SYNOPSIS

    my $content = "//  specify data using proc getdata
    #proc getdata
    data:   Brazil 22
        Columbia 17
        "Costa Rica" 22
        Guatemala 3
        Honduras 12
        Mexico 14
        Nicaragua 28
        Belize 9
        "United States" 21
        Canada 8

    //  render the pie graph using proc pie
    #proc pie
    datafield: 2
    labelfield: 1
    labelmode: line+label
    center: 4 3
    radius: 1
    colors: oceanblue
    outlinedetails: color=white
    labelfarout: 1.3
    total: 256" ;
    my $params = {} ;
    my $obj = App::Basis::ConvertText2::Plugin::Ploticus->new() ;
    my $out = $obj->process( 'ploticus', $content, $params) ;

=head1 DESCRIPTION

convert a ploticus text string into a PNG, requires ploticus program from http://ploticus.sourceforge.net/

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Ploticus ;

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
    default  => sub { [qw{ploticus}] }
) ;

use constant PLOTICUS => "ploticus" ;

# ----------------------------------------------------------------------------

=item ploticus

create a simple ploticus image

 parameters
    data   - ploticus text
    filename - filename to save the created image as

 hashref params of
        size        - size of image, widthxheight - optional, default 720x512
        width   - optional width
        height  - optional
        class   - optional
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
    $params->{title} ||= "" ;
    $params->{class} ||= "" ;

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    # we can use the cache or process everything ourselves
    my $sig = create_sig( $content, $params ) ;
    my $filename = cachefile( $cachedir, "$tag.$sig.svg" ) ;
    if ( !-f $filename ) {

        my $ploticusfile = Path::Tiny->tempfile("ploticusXXXXXXXX") ;
        # we control the page size
        path($ploticusfile)->spew_utf8($content) ;

        my $cmd = PLOTICUS ;
        $cmd .= " -svg $ploticusfile -o $filename" ;
        my ( $exit, $stdout, $stderr ) = run_cmd($cmd) ;
        if ($exit) {
            warn "Could not run script " . PLOTICUS
                . " get it from http://ploticus.sourceforge.net/" ;
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
