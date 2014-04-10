
=head1 NAME

 App::Basis::ConvertText::Chart

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 Convert comma separated text strings into charts image PNG

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 1999, now updated to become App::Basis::ConvertText::Chart

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Chart;

use 5.10.0;
use strict;
use warnings;
# the different graph types
use GD::Graph::lines;
use GD::Graph::lines3d;
use GD::Graph::bars;
use GD::Graph::bars3d;
use GD::Graph::pie;
use GD::Graph::points;
use GD::Graph::linespoints;
use GD::Graph::area;
use GD::Graph::mixed;
use GD;
# use GD::Text ;
use File::Slurp qw( write_file);
use Exporter;
use Capture::Tiny qw(capture);
use Data::Printer;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( chart chart_formats);

BEGIN {
    # load up the X11 colour names
    GD::Graph::colour::read_rgb("/etc/X11/rgb.txt");
}
# ----------------------------------------------------------------------------

my %_chart_formats = (
    mixed       => 'GD::Graph::mixed',
    area        => 'GD::Graph::area',
    lines       => 'GD::Graph::lines',
    points      => 'GD::Graph::points',
    linespoints => 'GD::Graph::linespoints',
    bars        => 'GD::Graph::bars',
    lines3d     => 'GD::Graph::lines3d',
    pie         => 'GD::Graph::pie'
);

# ----------------------------------------------------------------------------
sub chart_formats {
    my @charts = sort keys %_chart_formats;
    return @charts;
}

# ----------------------------------------------------------------------------

sub _split_csv_data {
    my $data = shift;
    my @d    = ();

    my $j = 0;
    foreach my $line ( split( /\n/, $data ) ) {
        last if ( !$line );
        my @row = split( /,/, $line );

        for ( my $i = 0; $i <= $#row; $i++ ) {
            undef $row[$i] if ( $row[$i] eq 'undef' );
            # dont' bother with any zero values either
            undef $row[$i] if ( $row[$i] =~ /^0\.?0?$/ );
            push @{ $d[$j] }, $row[$i];
        }
        $j++;
    }

    return @d;
}

# ----------------------------------------------------------------------------

=item chart

create a simple chart image, with some nice defaults

 parameters
    data   - comma separated lines of chart data
    filename - filename to save the created chart image as 

    hashref params of
        size    - size of image, default 400x300, widthxheight - optional
        title   - title for the chart
        xaxis   - label for x axis
        yaxis   - label for y axis
        format  - chart format mixed, area, lines, points, linespoints, bars, lines3d, pie
        types   - space separated list of types, in the same order as the data sets. Possible values are: lines bars points area linespoints
        overwrite - If set to 0, bars of different data sets will be drawn next to each other. If set to 1, they will be drawn in front of each other. Default: 0.
        legends - csv of legends for graph, these correspond to the data sets

=cut
sub chart {
    my ( $text, $filename, $params ) = @_;
    my ( @data, $chart, $format );
    my @types = ();

    # open the csv file, read contents, calc max, add into data array
    @data = _split_csv_data($text);

    $format = $params->{format} || "mixed";
    $format = lc $format;

    $params->{size} ||= "400x300";
    $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/;
    my ( $x, $y ) = ( $1, $2 );
    if ( !$y ) {
        $x = 400;
        $y = 300;
    }

    die "Unknown format type $format" if ( !$_chart_formats{$format} );

    # get the name of the GD::Graph format class to instantiate and do it
    $chart = $_chart_formats{$format}->new( $x, $y );

    if ( $format eq "lines3d" ) {
        # always assume stacked bars when using lines3d
        $chart->set( bar_spacing => 6 );
    }

    if ( $params->{types} ) {
        @types = split( /\s/, $params->{types} );
    }
    else {
        $params->{types} = "points " x scalar(@data);
    }

    # set the types
    $chart->set(
        types        => [@types],
        default_type => $types[0] || "points",

        bgclr     => 'white',
        fgclr     => 'black',
        boxclr    => 'ivory',
        accentclr => 'black',
        valuesclr => 'black',

        labelclr     => 'black',
        axislabelclr => 'black',
        legendclr    => 'black',
        valuesclr    => 'black',
        textclr      => 'black',
        # shadow_depth => 2,

        x_label => $params->{xaxis} || "",
        y_label => $params->{yaxis} || "",
        title   => $params->{title} || "",

        overwrite => $params->{overwrite} || 0,
        bar_spacing => 6,

        long_ticks        => 1,
        x_ticks           => 1,
        x_labels_vertical => 1,

        legend_marker_width => 24,
        line_width          => 3,
        marker_size         => 5,

        legend_placement => 'RC',
    );

    # set the colours for the charts
    # white, lgray, gray, dgray, black, lblue, blue, dblue, gold, lyellow, yellow, dyellow,
    # lgreen, green, dgreen, lred, red, dred, lpurple, purple, dpurple, lorange, orange,
    # pink, dpink, marine, cyan, lbrown, dbrown.
    $chart->set( dclrs => [qw(marine blue lred dgreen orange salmon lbrown gold lgreen yellow gray dred lpurple)] );

    # set the font things
    $chart->set_title_font(gdGiantFont);

    # pie legends are written on the slices, so we don't have this method
    if ( $format eq 'pie' ) {
        $chart->set_value_font(gdMediumBoldFont);
    }
    else {
        # legends comma seperated to allow spaces in descriptions
        $chart->set_legend( split( /,/, $params->{legends} || "" ) );
        $chart->set_legend_font(gdMediumBoldFont);
        $chart->set_x_label_font(gdMediumBoldFont);
        $chart->set_y_label_font(gdMediumBoldFont);
        $chart->set_x_axis_font(gdMediumBoldFont);
        $chart->set_y_axis_font(gdMediumBoldFont);
        $chart->set_values_font(gdMediumBoldFont);
    }
    my $status = 0;

    my ( $stdout, $stderr, $exit ) = capture {
        my $gd = $chart->plot( \@data );
        $status = 1 if ( $gd && write_file( $filename, $gd->png ) );
    };
    return $status;
}

# ----------------------------------------------------------------------------

1;
