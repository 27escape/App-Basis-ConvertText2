
=head1 NAME

App::Basis::ConvertText2::Plugin::Dataflow

=head1 SYNOPSIS

    my $content = "diagram 'Webapp' {
      boundary 'Browser' {
        function client 'Client'
      }
      boundary 'Amazon AWS' {
        function server 'Web Server'
        database logs 'Logs'
      }
      io analytics 'Google<br/>Analytics'

      client -> server 'Request /' ''
      server -> logs 'Log' 'User IP'
      server -> client 'Response' 'User Profile'
      client -> analytics 'Log' 'Page Navigation'
    }" ;
    my $params = { 
        size   => "600x480",
        format => 'seq'
    } ;
    my $obj = App::Basis::ConvertText2::Plugin::Dataflow->new() ;
    my $out = $obj->process( 'dataflow', $content, $params) ;
 
=head1 DESCRIPTION

convert a dataflow into PNG, 
requires dataflow program from L<https://github.com/sonyxperiadev/dataflow>

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Dataflow ;

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
    default  => sub { [qw{dataflow }] }
) ;

# ----------------------------------------------------------------------------

=item dataflow

create a simple dataflow image

 parameters
    data   - dataflow text      
    filename - filename to save the created image as 

 hashref params of
        size    - size of image, widthxheight - optional
        width   - optional width
        height  - optional
        class   - optional
        format  - either dfd (default) or seq
        title   - optional set the alt text
        align   - option, set alignment of image

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

    if ( !$params->{format} || $params->{format} !~ /^(seq|dataflow)/i ) {
        # force default if they got it wrong
        $params->{format} = 'dfd' ;
    } else {
        $params->{format} = lc( $params->{format} ) ;
    }

    my $args = "" ;

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    # we can use the cache or process everything ourselves
    my $sig = create_sig( $content, $params ) ;
    my $filename = cachefile( $cachedir, "$tag.$sig.svg" ) ;
    if ( !-f $filename ) {

        my $diagfile = Path::Tiny->tempfile("dataflow.XXXX") ;
        path($diagfile)->spew_utf8($content) ;
        my $tmpfile = Path::Tiny->tempfile("dataflow.tmp.XXXX") ;
    
        my $cmd = "$tag $params->{format} $diagfile " ;
        # say STDERR "command $cmd" ;
        my ( $exit, $stdout, $stderr ) = run_cmd($cmd) ;
        if ($exit) {
            warn
                "Could not run script $tag get it from https://github.com/sonyxperiadev/dataflow"
                ;
        }
        my $convertor = "" ;
        path($tmpfile)->spew_utf8($stdout) ;
        if ( $params->{format} eq 'dfd' ) {

            # convert with dot
            $convertor = "dot -Tsvg -o$filename $tmpfile" ;
        } else {
            # convert with plantuml
            $convertor = "uml -s $tmpfile $filename"
        }
        # say STDERR "convertor $convertor" ;
        ( $exit, $stdout, $stderr ) = run_cmd($convertor) ;
        if ($exit) {
            warn
                "Could not run convertor script $convertor" ;
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

1 ;
