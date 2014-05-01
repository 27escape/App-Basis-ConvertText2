
=head1 NAME

 App::Basis::ConvertText::Sparkline

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 Convert a text string of comma separated numbers into a sparkline image PNG

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 1999, now updated to become App::Basis::ConvertText::Sparkline

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Sparkline;

use 5.10.0;
use strict;
use warnings;
use GD::Sparkline;
use Path::Tiny ;
use Exporter;
use Capture::Tiny qw(capture);
use Data::Printer ;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( sparkline color_schemes);

# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------

my %_colour_schemes = (
    orange => { b => 'transparent', a => 'ffcc66', l => 'ff6000' },
    blue   => { b => 'transparent', a => 'ccffff', l => '3399cc' },
    red    => { b => 'transparent', a => 'ccaaaa', l => '990000' },
    green  => { b => 'transparent', a => '99ff99', l => '006600' },
    mono   => { b => 'ffffff',      a => 'ffffff', l => '000000' }
);

# -----------------------------------------------------------------------------

=item color_schemes

return a list of the color schemes available

=cut

sub color_schemes {
    my @schemes = sort keys %_colour_schemes;
    return @schemes ;
}

# -----------------------------------------------------------------------------

=item sparkline

create a simple sparkline image, with some nice defaults

 parameters
    text   - comma separated list of integers for the sparkline
    filename - filename to save the created sparkline image as 

    hashref params of
        bgcolor - background color in hex (123456) or transparent - optional
        line    - color or the line, in hex (abcdef) - optional
        color   - area under the line, in hex (abcdef) - optional
        scheme  - color scheme, only things in red blue green orange mono are valid - optional
        size    - size of image, default 80x20, widthxheight - optional

=cut

sub sparkline {
    my ( $text, $filename, $params ) = @_;
    my $scheme = $params->{scheme};
    my ( $b, $a, $l ) = ( $params->{bgcolor}, $params->{color}, $params->{line} );
    $params->{size} ||= "80x20" ;
    $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/;
    my ( $w, $h ) = ( $1, $2 );
    if ( !$h ) {
        $w = 80;
        $h = 20;
    }

    die "Missing filename"                               if ( !$filename );
    die "Missing text"                                   if ( !$text );
    die "Does not appear to be comma separated integers" if ( $text !~ /^[,\d ]+$/ );

    $text =~ s/^\n*//gsm ;          # remove any leading new lines
    if( $text !~ /\n$/sm) {         # make sure we have a trailing new line
        $text .= "\n" ;
    }

    if ($scheme) {
        $scheme = lc $scheme;
        if ( !$_colour_schemes{$scheme} ) {
            warn "Unknown color scheme $params->{scheme}";
            $scheme = ( sort keys %_colour_schemes )[0];
        }
        $b = $_colour_schemes{ $params->{scheme} }{b};    # background color
        $a = $_colour_schemes{ $params->{scheme} }{a};    # area under line color
        $l = $_colour_schemes{ $params->{scheme} }{l};    # top line color
    }
    else {
        $b ||= 'transparent';
        $a = 'cccccc';
        $l = '333333';
    }

    my $status = 0;
    my $args = { b => $b, a => $a, l => $l, s => $text, w => $w, h => $h } ;
    my $spark = GD::Sparkline->new( $args );
    if ($spark) {
        my $png = $spark->draw();
        if ($png) {
            my ( $stdout, $stderr, $exit ) = capture {
                $status = 1 if ( path( $filename)->spew_raw( $png ) );
            };
        }
    }

    return $status;
}

# ----------------------------------------------------------------------------

1;

__END__
