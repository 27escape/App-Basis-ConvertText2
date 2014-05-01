
=head1 NAME

 App::Basis::ConvertText::Mscgen

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 convert a mscgen text string into a PNG, requires mscgen program

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 1999, now updated to become App::Basis::ConvertText::Mscgen

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Mscgen;

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
@EXPORT = qw( mscgen);

use constant MSCGEN => 'mscgen';

# ----------------------------------------------------------------------------

BEGIN {
    my ( $r, $o, $e ) = run_cmd(MSCGEN);
    die "Could not find " . MSCGEN if ( $r != 1 );
}

# ----------------------------------------------------------------------------

=item mscgen

create a simple msc image

 parameters
    data   - msc text      
    filename - filename to save the created image as 

 hashref params of
        size    - size of image, widthxheight - optional

=cut
sub mscgen
{
    my ( $text, $filename, $params ) = @_;
    $params->{title} ||= "";
    $params->{size}  ||= "";
    my ( $x, $y ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ );

    my ( $fh, $mscfile ) = tempfile("/tmp/mscgen.XXXX");

    write_file( $mscfile, $text );

    my $cmd = MSCGEN . " -Tpng -o$filename $mscfile";
    my ( $exit, $stdout, $stderr ) = run_cmd($cmd);

    # if we want to force the size of the graph
    if ( -f $filename && $x && $y ) {
        my $image = Image::Resize->new($filename);
        my $gd = $image->resize( $x, $y );
        # overwrite original file with resized version
        write_file( $filename, $gd->png ), if ($gd);
    }

    return $exit == 0 ? 1 : 0;
}

# ----------------------------------------------------------------------------

1;
