
=head1 NAME

App::Basis::ConvertText2::Plugin::GoogleCharts

=head1 SYNOPSIS

    my $content = "
Task1, hello,   1789-3-29, 1797-2-3 #green
Task1, sample,   1795-3-29, 1807-2-3   #663399
Task1, goodbye,   1819-3-29, 1827-2-3 #plum
Task2, eat,  1797-2-3,  1801-2-3 #thistle
Task2, drink,  1798-2-3,  1804-2-3 #grey
Task3, shop,  1801-2-3,  1809-2-3 #red
Task3, drop,  1801-2-3,  1819-2-3 #darkorange
" ;

    my $params = {
        size   => "600x480",
        package => 'timeline'
    } ;
    my $obj = App::Basis::ConvertText2::Plugin::GoogleChart->new() ;
    my $out = $obj->process( 'googlechart', $content, $params) ;

=head1 DESCRIPTION

convert data about a chart into an image using https://developers.google.com/chart/

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::GoogleChart ;

use 5.10.0 ;
use strict ;
use warnings ;
use Moo ;
use Path::Tiny ;
use App::Basis ;
use App::Basis::ConvertText2::Support ;
use namespace::autoclean ;
use feature 'state' ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{googlechart timeline sankey}] }
) ;

my $init = 0 ;

# ----------------------------------------------------------------------------

# all the possible chart types
# area bar bubble calendar candlestick column combo donut gauge geo histogram
# interval line map org pie sankey scatter steppedarea table timeline tree
# trend waterfall

my %packages = map { $_ => "$_-package" } qw( timeline sankey) ;

# ----------------------------------------------------------------------------

=item timeline_package

create a timeline chart, from the passed text

 parameters
    data - the chart data, reference to array of lines
    x    - width
    y    - height 
    params - params passed to googlechart
        background - color or hex triplet, none or transparent removes it
        labels - show the task item labels next on/next to the bars

data is a CSV lines of

task, item, start_date, end_date

optionally a color can be specified for the bar using #color at the after the
end_date
 
colors can be a color name or a color hex triplet

eg #blue, #eee, #010203

=cut

sub timeline_package
{
    my $self = shift ;
    my ( $data, $x, $y, $params, $cachedir ) = @_ ;

    state $element_id = 1 ;

    my $element   = "timeline_$element_id" ;
    my $dataTable = "DataTable_$element_id" ;
    my $drawChart = "Chart_$element_id" ;

    my $default_color = 'blue' ;
    my @colors        = () ;
    my @rows          = () ;
    my $bg_color      = "" ;

    if ( $params->{background} ) {
        if ( $params->{background} =~ /^none$|^transparent$/i ) {
            # get rid of the chart background color and zebra stripes etc
            add_css(
                "#$element svg g:first-of-type rect { fill-opacity: 0; }") ;
        } else {
            $bg_color = "backgroundColor: '" .to_hex_color( $params->{background}) . "'," ;
        }
    }

    my $html = "
<html>
<head>
<script type='text/javascript' src='https://www.google.com/jsapi'></script>
<script type='text/javascript'>
google.load('visualization', '1', {packages:['timeline']});
google.setOnLoadCallback($drawChart);

function $drawChart() {
var container = document.getElementById('$element');
var chart = new google.visualization.Timeline(container);
var $dataTable = new google.visualization.DataTable();
$dataTable.addColumn({ type: 'string', id: 'Task' });
$dataTable.addColumn({ type: 'string', id: 'Item' });
$dataTable.addColumn({ type: 'date', id: 'Start' });
$dataTable.addColumn({ type: 'date', id: 'End' });
" ;

    # process the data
    foreach my $line ( @{$data} ) {
        $line =~ s/^\s+|\s+$//g ;
        next if ( !$line ) ;

        my $color = $default_color ;

        # first up get any color from the end
        if ( $line =~ s/(#(\w+)(\/\w+)?\s?)// ) {
            $color = $2 ;
        }
        $color = to_hex_color( $color) ;
        $color = "#$color" if ( $color =~ /^[0-9a-f]+$/i ) ;

        push @colors, "'$color'" ;

        # split into parts
        my @elems = split( /,/, $line ) ;
        # we only use 4 elements
        # and need to trim those for whitespace
        # the dates need to be reformated
        my $task = $elems[0] || "Default Task" ;
        $task =~ s/^\s+|\s+$//g ;
        my $item = $elems[1] || "Item $element_id" ;
        $item =~ s/^\s+|\s+$//g ;

        # dates should be yyyy-mm-dd
        # add a default if missing/wrong
        my $start = $elems[2] ;
        if (   $start
            && $start =~ /(\d{2,4})-(\d{1,2})-(\d{1,2})(\s+\d{2}:\d{2})?/ ) {
            $start
                = "new Date( $1, $2 -1, $3, "
                . ( $5 || 0 ) . ", "
                . ( $6 || 0 )
                . ")" ;
        } else {
            $start = "new Date( 1970, 01, 01)" ;
        }

        my $end = $elems[3] ;
        if (   $end
            && $end =~ /(\d{2,4})-(\d{1,2})-(\d{1,2})(\s+\d{2}:\d{2})?/ ) {
            $end
                = "new Date( $1, $2 -1, $3, "
                . ( $5 || 0 ) . ", "
                . ( $6 || 0 )
                . ")" ;
        } else {
            $end = "new Date( 2020, 01, 01)" ;
        }

        $task =~ s/'/&qout;/g ;
        $item =~ s/'/&qout;/g ;

        push @rows, "[ '$task', '$item', $start, $end ],\n" ;
    }

    my $d
        = ( $params->{labels} && $params->{labels} =~ /0|false/i )
        ? 'showBarLabels: false,'
        : '' ;

    my $style = "style='" ;
    $style .="width: $x;" if( $x) ;
    $style .= "height: $y;" if( $y);
    $style .="'" ;

    my $wid = $x ? "width: '$x'," : "" ;
    my $hig = $y ? "height: '$y'," : "" ;

    $html .= "
var options = {
timeline: { groupByRowLabel: true, colorByRowLabel:false, 
$d
},
avoidOverlappingGridLines: false,
colors: [ " . join( ',', @colors ) . "],
enableInteractivity:'false',
$wid
$hig
$bg_color
};

$dataTable.addRows([ " . join( '', @rows ) . "]);

chart.draw($dataTable, options);
}
</script>
</head>
<body>
<div id='$element' class='timeline $params->{class}' $style></div>
</body>
</html>
" ;

    # ready for the next one
    $element_id++ ;

    return phantomjs( $html, $element, 0, $cachedir ) ;
}

# ----------------------------------------------------------------------------

=item sankey_package

create a sankey chart, from the passed text

 parameters
    data - the chart data, reference to array of lines
    x    - width
    y    - height 
    params - params passed to googlechart

data is a CSV lines of

from, to, weight

=cut

sub sankey_package
{
    my $self = shift ;
    my ( $data, $x, $y, $params, $cachedir ) = @_ ;

    state $element_id = 1 ;

    my $element   = "sankey_$element_id" ;
    my $dataTable = "DataTable_$element_id" ;
    my $drawChart = $element ;

    my @rows = () ;

    my $html = "
<html>
<head>
<script type='text/javascript' src='https://www.google.com/jsapi'></script>
<script type='text/javascript'>
google.load('visualization', '1.1', {packages:['sankey']});
google.setOnLoadCallback($drawChart);

function $drawChart() {
var container = document.getElementById('$element');
var chart = new google.visualization.Sankey(container);
var $dataTable = new google.visualization.DataTable();
$dataTable.addColumn('string', 'From');
$dataTable.addColumn('string', 'To');
$dataTable.addColumn('number', 'Weight');
" ;

    # process the data
    foreach my $line ( @{$data} ) {
        $line =~ s/^\s+|\s+$//g ;
        next if ( !$line ) ;

        # split into parts
        my @elems = split( /,/, $line ) ;
        # we only use 3 elements
        # and need to trim those for whitespace
        # the dates need to be reformated
        $elems[0] ||= "Default Item" ;
        $elems[0] =~ s/^\s+|\s+$//g ;
        $elems[1] ||= "Item $element_id" ;
        $elems[1] =~ s/^\s+|\s+$//g ;
        $elems[1] ||= 1 ;    # default weight
        $elems[2] =~ s/^\s+|\s+$//g ;

        push @rows, "[ '$elems[ 0]', '$elems[ 1]', $elems[ 2] ],\n" ;
    }

    my $colors        = "" ;
    my $color_options = "" ;

    # when using colors we want the lines to have a color if nothing has been
    # set by the user
    $params->{mode} = "target" if ( $params->{colors} && !$params->{mode} ) ;

    $params->{mode} ||= "" ;
    $params->{mode} = lc( $params->{mode} ) ;
    $params->{mode} = "none"
        if ( $params->{mode} !~ /gradient|source|target/ ) ;


    if ( $params->{colors} ) {
        my @colors ;
        foreach my $c ( split( /\s|,/, $params->{colors} ) ) {
            next if ( !$c ) ;
            push @colors, to_hex_color($c) ;
        }
        $colors
            = "var colors = [ "
            . join( ',', map {"'$_'"} @colors )
            . " ] ;\n" ;


        $color_options = "node: { colors: colors },
link: { colors: colors, colorMode: '$params->{mode}' }," ;
    } else {
        $color_options = "link: { colorMode: '$params->{mode}' }," ;
    }


    $html .= "$colors
var options = {
sankey: {
$color_options
},
width: '$x',
height: '$y',
};

$dataTable.addRows([ " . join( '', @rows ) . "]);

chart.draw($dataTable, options);
}
</script>
</head>
<body>
<div id='$element' class='sankey $params->{class}' style='width: $x"
        . "; height: $y;'></div>
</body>
</html>
" ;

    # ready for the next one
    $element_id++ ;

    return phantomjs( $html, $element, 0, $cachedir ) ;
}

# ----------------------------------------------------------------------------

=item googlechart

create a simple graphviz structured graph image, from the passed text

 parameters
    data   - the chart data
    filename - filename to save the created image as

 hashref params of
        size    - size of image, widthxheight - optional
        width   - optional width
        height  - optional
        package - the type of chart to create
        class   - class to add to the created element

=cut

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    $params->{size}  ||= "" ;
    $params->{class} ||= "" ;
    my ( $x, $y ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ ) ;
    $x ||= "" ;
    $y ||= "" ;
    $x = $params->{width}  if ( $params->{width} ) ;
    $y = $params->{height} if ( $params->{height} ) ;
    $x .= "px" if ( $x && $x !~ /%|px/ ) ;
    $y .= "px" if ( $y && $y !~ /%|px/ ) ;

    my $package ;

    if ( !$init ) {
        # add stuff into the template
        # do not use a BEGIN block as this would add this to every document
        # even when this tag is not being used
        $init++ ;
    }

    if ( $tag ne 'googlechart' ) {
        $params->{package} = $tag ;
    }

    # if the drawing command is one we recognise, use it
    if ( $params->{package} && $packages{ $params->{package} } ) {
        $package = $params->{package} ;
    } else {
        return "bad googlechart package defined <b>$params->{package}</b>" ;
    }

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    # run the package
    my @data = split( /\n/, $content ) ;

    # setup the package function name
    $package .= "_package" ;

    if ( $self->can($package) ) {
        # we can use the cache or process everything ourselves
        my $sig = create_sig( $content, $params ) ;
        my $filename = cachefile( $cachedir, "$tag.$sig.svg" ) ;
        my $out ;
        if ( !-f $filename ) {
            $out = $self->$package( \@data, $x, $y, $params, $cachedir ) ;
            path($filename)->spew_utf8($out) ;
        } else {
            $out = path($filename)->slurp_utf8() ;
        }
        return $out ;
    }

    return undef ;
}


# ----------------------------------------------------------------------------

1 ;
