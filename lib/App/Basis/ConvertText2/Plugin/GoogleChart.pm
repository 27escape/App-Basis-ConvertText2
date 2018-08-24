=head1 NAME

App::Basis::ConvertText2::Plugin::GoogleCharts

=head1 SYNOPSIS

    # Create a timeline

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

    # Create a Sankey Diagram

    $content = "A, X, 5
A, Y, 7
A, Z, 6
B, X, 2
B, Y, 9
B, Z, 4" ;

    $params = {
        size   => "600x480",
        package => 'sankey'
    } ;
    $obj = App::Basis::ConvertText2::Plugin::GoogleChart->new() ;
    $out = $obj->process( 'googlechart', $content, $params) ;

    # Create a Gantt Chart
    # expects id,name, group, start date, end date [,dependencies , percent]
    $content = "1, hello, Task1,   1789-3-29, 1797-2-3
2, sample, Task1,  1795-3-29, 1807-2-3
3, goodbye, Task1, 1819-3-29, 1827-2-3
4, eat, Task2,   1797-2-3,  1801-2-3
5, drink, Task2, 1798-2-3,  1804-2-3
6, shop, Task3,  1801-2-3,  1809-2-3
7, drop, Task3,  1801-2-3,  1819-2-3" ;

    $params = {
        size   => "600x480",
        package => 'gantt'
    } ;
    $obj = App::Basis::ConvertText2::Plugin::GoogleChart->new() ;
    $out = $obj->process( 'googlechart', $content, $params) ;

=head1 DESCRIPTION

convert data about a chart into an image using https://developers.google.com/chart/

currently supporting timeline gantt and sankey charts

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::GoogleChart ;

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
    default  => sub { [qw{googlechart timeline gantt }] }    # removed sankey
) ;

my $init = 0 ;

my $GOOGLE_LOADER = <<GOOGLE;
<script type='text/javascript' src='https://www.gstatic.com/charts/loader.js'></script>
<script type='text/javascript'>
google.charts.load('current', {packages: ['corechart']});
GOOGLE

# ----------------------------------------------------------------------------

# all the possible chart types
# area bar bubble calendar candlestick column combo donut gauge geo histogram
# interval line map org pie sankey scatter steppedarea table timeline tree
# trend waterfall

my %packages = map { $_ => "$_-package" } qw( timeline gantt ) ;    # removed sankey

# -----------------------------------------------------------------------------
# create a JS date object
# dates should be yyyy-mm-dd or yyyy-mm-dd hh:mm or hh:mm

sub _extract_date
{
    my ($str) = @_ ;
    # add a default if missing/wrong
    my $datestr = "new Date( 1970, 01, 01)" ;

    # print STDERR "input date is $str\n" ;

    if ($str) {
        $str =~ s/^\s+|\s+$//g ;
        if ( $str =~ /((\d{2,4})-(\d{1,2})-(\d{1,2}))?\s?((\d{2}):(\d{2}))?/ ) {
            # print STDERR  "  processing $str\n" ;
            my ( $year, $month, $day, $hour, $mins ) = ( $2, $3, $4, $6, $7 ) ;
            $year += 0 ;
            $month ||= 1 ;
            $day  += 0 ;
            $hour += 0 ;
            $mins += 0 ;
            $month -= 1 ;
            $datestr = "new Date( $year, $month, $day, $hour, $mins, 0)" ;
        }
    }

# print STDERR "  created $datestr\n" ;
    return $datestr ;
}

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
            add_css("#$element svg g:first-of-type rect { fill-opacity: 0; }") ;
        } else {
            $bg_color = "backgroundColor: '" . to_hex_color( $params->{background} ) . "'," ;
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
var chart = new google.visualization.Timeline(document.getElementById('$element'));
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
        $color = to_hex_color($color) ;
        $color = "#$color" if ( $color =~ /^[0-9a-f]+$/i ) ;

        push @colors, "'$color'" ;

        # split into parts
        my @elems = split_csv_line($line) ;

        # we only use 4 elements
        # and need to trim those for whitespace
        # the dates need to be reformated
        my $task = $elems[0] || "Default Task" ;
        $task =~ s/^\s+|\s+$//g ;
        my $item = $elems[1] || "Item $element_id" ;
        $item =~ s/^\s+|\s+$//g ;

        my $start = _extract_date( $elems[2] ) ;
        my $end   = _extract_date( $elems[3] ) ;
        $task =~ s/'/&qout;/g ;
        $item =~ s/'/&qout;/g ;

        push @rows, "[ '$task', '$item', $start, $end ],\n" ;
    }

    my $barlabels =
        ( $params->{labels} && $params->{labels} =~ /0|false/i )
        ? 'showBarLabels: false,'
        : '' ;

    my $style = "" ;
    if ( $x || $y ) {
        $style = "style='" ;
        $style .= "width: $x;"  if ($x) ;
        $style .= "height: $y;" if ($y) ;
        $style .= "'" ;
    }

    my $wid = $x ? "width: '$x',"  : "" ;
    my $hig = $y ? "height: '$y'," : "" ;

    $html .= "
var options = {
timeline: { groupByRowLabel: true, colorByRowLabel:false,
$barlabels
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
<div id='$element' class='timeline $params->{class}' $style style='width:100%;'></div>
</body>
</html>
" ;

    # ready for the next one
    $element_id++ ;

    return phantomjs( $html, $element, $params->{keep}, $cachedir ) ;
}

# ----------------------------------------------------------------------------

=item gantt_package

create a gantt chart, from the passed text

 parameters
    data - the chart data, reference to array of lines
    x    - width
    y    - height
    params - params passed to googlechart
        background - color or hex triplet, none or transparent removes it
        labels - show the task item labels next on/next to the bars

data is a CSV lines of

id, item, group, start_date, end_date, dependency_ids, percent_completed

dependency_ids, percent_completed can be left off
and will be considered as null,0

=cut

sub gantt_package
{
    my $self = shift ;
    my ( $data, $x, $y, $params, $cachedir ) = @_ ;

    state $element_id = 1 ;

    my $element   = "gantt_$element_id" ;
    my $dataTable = "DataTable_$element_id" ;
    my $drawChart = "Chart_$element_id" ;

    # my $default_color = 'blue' ;
    # my @colors        = () ;
    my @rows = () ;
    # my $bg_color      = "" ;

    # if ( $params->{background} ) {
    #     if ( $params->{background} =~ /^none$|^transparent$/i ) {

    #         # get rid of the chart background color and zebra stripes etc
    #         add_css(
    #             "#$element svg g:first-of-type rect { fill-opacity: 0; }") ;
    #     } else {
    #         $bg_color
    #             = "backgroundColor: '"
    #             . to_hex_color( $params->{background} )
    #             . "'," ;
    #     }
    # }

    my $html = "
<html>
<head>
<script type='text/javascript' src='https://www.google.com/jsapi'></script>
<script type='text/javascript'>
google.load('visualization', '1.1', {packages:['gantt']});
google.setOnLoadCallback($drawChart);

function $drawChart() {
    var $dataTable = new google.visualization.DataTable();

    $dataTable.addColumn( 'string', 'ID' );
    $dataTable.addColumn( 'string', 'Task' );
    $dataTable.addColumn( 'string', 'Group' );
    $dataTable.addColumn( 'date',   'Start' );
    $dataTable.addColumn( 'date',   'End' );
    $dataTable.addColumn( 'number', 'Duration');
    $dataTable.addColumn( 'number', 'Percent Complete');
    $dataTable.addColumn( 'string', 'Dependencies');
" ;

    # process the data
    my $counter = 0 ;
    foreach my $line ( @{$data} ) {
        $line =~ s/^\s+|\s+$//g ;
        next if ( !$line ) ;
        $counter++ ;

        # strip any color
        $line =~ s/(#(\w+)(\/\w+)?\s?)// ;

        # my $color = $default_color ;

        # # first up get any color from the end
        # if ( $line =~ s/(#(\w+)(\/\w+)?\s?)// ) {
        #     $color = $2 ;
        # }
        # $color = to_hex_color($color) ;
        # $color = "#$color" if ( $color =~ /^[0-9a-f]+$/i ) ;

        # push @colors, "'$color'" ;

        # split into parts
        my @elems = split_csv_line($line) ;

        # we use 4-7 elements
        # and need to trim those for whitespace
        # the dates need to be reformated
        # default dependency and percent may need to be added
        my $id = $elems[0] || $counter ;
        $id =~ s/^\s+|\s+$//g ;
        my $task = $elems[1] || "task $element_id" ;
        $task =~ s/^\s+|\s+$//g ;
        my $group = $elems[2] || "" ;
        $group =~ s/^\s+|\s+$//g ;

        # dates should be yyyy-mm-dd
        # add a default if missing/wrong
        my $start = $elems[3] ;
        if (   $start
            && $start =~ /(\d{2,4})-(\d{1,2})-(\d{1,2})(\s+\d{2}:\d{2})?/ ) {
            $start = "new Date( $1, $2 -1, $3, " . ( $5 || 0 ) . ", " . ( $6 || 0 ) . ")" ;
        } else {
            $start = "new Date( 1970, 01, 01)" ;
        }

        my $end = $elems[4] ;
        if (   $end
            && $end =~ /(\d{2,4})-(\d{1,2})-(\d{1,2})(\s+\d{2}:\d{2})?/ ) {
            $end = "new Date( $1, $2 -1, $3, " . ( $5 || 0 ) . ", " . ( $6 || 0 ) . ")" ;
        } else {
            $end = "new Date( 2020, 01, 01)" ;
        }
        my $depends = $elems[5] || "" ;
        $depends = join( ',', split( ' ', $depends ) ) ;
        if ($depends) {
            $depends = "'$depends'" ;
        } else {
            $depends = 'null' ;
        }

        my $percent = $elems[6] || "0" ;
        $percent =~ s/%// ;

        $id =~ s/'/&qout;/g ;
        $task =~ s/'/&qout;/g ;
        $group =~ s/'/&qout;/g ;

        # there is a duration but this can be calculated by the chart
        push @rows, "[ '$id', '$task', '$group', $start, $end, null, $percent, $depends ],\n" ;
    }

    # my $d
    #     = ( $params->{labels} && $params->{labels} =~ /0|false/i )
    #     ? 'showBarLabels: false,'
    #     : '' ;

    my $style = "" ;
    # this is a rough calc based on manual testing
    if ( !$y ) {
        $y = ( 40 * $counter ) + 60 ;
    }
    $x = '100%' if ( !$x ) ;

    if ( $x || $y ) {
        $style = "style='" ;
        $style .= "width: $x;"  if ($x) ;
        $style .= "height: $y;" if ($y) ;
        $style .= "'" ;
    }

    my $wid = $x ? "width: '$x',"  : "" ;
    my $hig = $y ? "height: '$y'," : "" ;

    # groupByRowLabel: true,
    # colorByRowLabel:false,

    $html .= "
    $dataTable.addRows([\n      " . join( '      ', @rows ) . "\n    ]);

    var options = {
        gantt: {
            criticalPathEnabled: true,
            criticalPathStyle: {
              stroke: '#e64a19',
              strokeWidth: 5
            },
            trackHeight: 35
        }
    };

    var chart = new google.visualization.GanttChart( document.getElementById('$element'));
    chart.draw( $dataTable, options);
}
</script>
</head>
<body>
<div id='$element' class='gantt$params->{class}' $style ></div>
</body>
</html>
" ;

    # ready for the next one
    $element_id++ ;

    return phantomjs( $html, $element, $params->{keep}, $cachedir ) ;
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
var chart = new google.visualization.Sankey(document.getElementById('$element'););
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
        my @elems = split_csv_line($line) ;

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
        $colors = "var colors = [ " . join( ',', map {"'$_'"} @colors ) . " ] ;\n" ;

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

    return phantomjs( $html, $element, $params->{keep}, $cachedir ) ;
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
