
=head1 NAME

 App::Basis::ConvertText::QRcode

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 convert a text string into a QRcode PNG, requires qrencode program

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 2005, now updated to become App::Basis::ConvertText::QRcode

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::QRcode;

use 5.10.0;
use strict;
use warnings;
use App::Basis;
use File::Temp qw(tempfile);
use File::Slurp qw(write_file);
use Exporter;
use Data::Printer;
use Image::Resize;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( qrcode);

use constant QRCODE => 'qrencode';

# ----------------------------------------------------------------------------

BEGIN {
    my ( $r, $o, $e ) = run_cmd(QRCODE . ' -h');
    die "Could not find " . QRCODE if ( $e && $e !~ /Usage: qrencode/ );
}

# ----------------------------------------------------------------------------

=item qrcode

create a qrcode image, just use default options for now

 parameters
    filename - filename to save the created image as 

 hashref params of
        size    - size of image, widthxheight - optional

=cut
sub qrcode {
    my ( $text, $filename, $params ) = @_;
    $params->{size} ||= "";
    my ( $x, $y ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ );

    my ( $fh, $qrfile ) = tempfile("/tmp/qrcode.XXXX");

    my $cmd = QRCODE . " -o$filename $text";
    my ( $exit, $stdout, $stderr ) = run_cmd($cmd);

    # if we want to force the size of the graph
    if ( -f $filename && $x && $y ) {
        my $image = Image::Resize->new($filename);
        my $gd = $image->resize( $x, $y );
        # overwrite original file with resized version
        write_file( $filename, $gd->png ), if ($gd)

    }

    return $exit == 0 ? 1 : 0;
}

# ----------------------------------------------------------------------------

1;
