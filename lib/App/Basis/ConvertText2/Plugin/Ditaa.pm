
=head1 NAME

App::Basis::ConvertText2::Plugin::Ditaa

=head1 SYNOPSIS

    my $content = "+--------+   +-------+    +-------+
    |        | --+ ditaa +--> |       |
    |  Text  |   +-------+    |diagram|
    |Document|   |!magic!|    |       |
    |     {d}|   |       |    |       |
    +---+----+   +-------+    +-------+
        :                         ^
        |       Lots of work      |
        \-------------------------+
    " ;
    my $params = { 
        size   => "600x480",
    } ;
    my $obj = App::Basis::ConvertText2::Plugin::Ditaa->new() ;
    my $out = $obj->process( 'ditaa', $content, $params) ;
 
=head1 DESCRIPTION

convert a ditaa text string into a PNG, requires ditaa program from http://ditaa.sourceforge.net/

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Ditaa;

use 5.10.0;
use strict;
use warnings;
use Path::Tiny;
use App::Basis;
use Moo;
use App::Basis;
use App::Basis::ConvertText2::Support;
use namespace::autoclean;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{ditaa}] }
);

use constant DITAA => 'ditaa';

# ----------------------------------------------------------------------------

=item ditaa

create a simple ditaa image

 parameters
    data   - ditaa text      
    filename - filename to save the created image as 

 hashref params of
        size    - size of image, widthxheight - optional
        shadow  - have shadow, default true
        alias   - apply aliasing, default true
        round   - round edges, default false
        separation - default false

=cut

sub process {
    my $self = shift;
    my ( $tag, $content, $params, $cachedir ) = @_;
    $params->{size}   ||= "";
    $params->{shadow} ||= 'true';
    $params->{separation} ||= 'false';
    $params->{alias} ||= 'false';
    $params->{round} ||= 'false';

    my ( $x, $y ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ );
    my $args    = "";
    # say STDERR "params " .Data::Printer::p( $params) ;
    my %allowed = (
        shadow     => { false  => '--no-shadows ' },
        alias      => { false  => '--no-antialias ' },
        round      => { true  => '--round-corners ' },
        separation => { false => '--no-separation ' }
    );

    foreach my $p (qw( shadow round separation)) {
        next if( !$params->{$p}) ;
        if ( $params->{$p} =~ /^true$|^1$|^yes$/i ) {
            $args .= ( $allowed{$p}->{true} || '' );
        }
        else {
            $args .= ( $allowed{$p}->{false} || '' );
        }
    }

    # strip any ending linefeed
    chomp $content;
    return "" if ( !$content );

    # we can use the cache or process everything ourselves
    my $sig = create_sig( $content, $params );
    my $filename = cachefile( $cachedir, "$sig.png" );
    if ( !-f $filename ) {

        my $ditaafile = Path::Tiny->tempfile("ditaa.XXXX");

        path($ditaafile)->spew_utf8($content);

        my $cmd = DITAA . " $args -o $ditaafile $filename";
        # say STDERR $cmd ;
        my ( $exit, $stdout, $stderr ) = run_cmd($cmd);
        if ($exit) {
            warn "Could not run script " . DITAA . " get it from http://ditaa.sourceforge.net/";
        }

        # if we want to force the size of the graph
        if ( -f $filename && $x && $y ) {
            my $image = Image::Resize->new($filename);
            my $gd = $image->resize( $x, $y );

            # overwrite original file with resized version
            if ($gd) {
                path($filename)->spew_raw( $gd->png );
            }
        }
    }

    my $out;
    if ( -f $filename ) {

        # create something suitable for the HTML
        $out = create_img_src( $filename, $params->{title} );
    }
    return $out;

}

# ----------------------------------------------------------------------------

1;
