
=head1 NAME

 App::Basis::ConvertText::Ditaa

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 convert a ditaa text string into a PNG, requires ditaa program

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 2013, now updated to become App::Basis::ConvertText::Ditaa

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Ditaa;

use 5.10.0;
use strict;
use warnings;
use App::Basis;
use File::Temp qw(tempfile);
use File::Slurp qw(write_file);
use Exporter;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( ditaa);

use constant DITAA => 'ditaa';

# ----------------------------------------------------------------------------

BEGIN {
    my ($r, $o, $e) = run_cmd(DITAA . " --help");
    die "Could not find " . DITAA if ($r > 0);
}

# ----------------------------------------------------------------------------

=item ditaa

create a simple ditaa image

 parameters
    data   - ditaa text      
    filename - filename to save the created image as 

 hashref params of
        size    - size of image, widthxheight - optional

=cut
sub ditaa
{
    my ($text, $filename, $params) = @_;
    $params->{size} ||= "";
    my ($x, $y) = ($params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/);

    my ($fh, $ditaafile) = tempfile("/tmp/ditaa.XXXX");

    write_file($ditaafile, $text);

    my $cmd = DITAA . " -o $ditaafile $filename";
    my ($exit, $stdout, $stderr) = run_cmd($cmd);

    # if we want to force the size of the graph
    if (-f $filename && $x && $y) {
        my $image = Image::Resize->new($filename);
        my $gd = $image->resize($x, $y);
        # overwrite original file with resized version
        write_file($filename, $gd->png), if ($gd);
    }

    return $exit == 0 ? 1 : 0;
}

# ----------------------------------------------------------------------------

1;
