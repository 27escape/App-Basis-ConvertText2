
=head1 NAME

App::Basis::ConvertText2::Plugin::Mermaid

=head1 SYNOPSIS

    my $content = "
%% Example of sequence diagram
gantt
    title A Gantt Diagram

    section Section
    A task           :a1, 2014-01-01, 30d
    Another task     :after a1  , 20d
    section Another
    Task in sec      :2014-01-12  , 12d
    anther task      : 24d" ;

    my $params = {
        size   => "600x480",
    } ;
    my $obj = App::Basis::ConvertText2::Plugin::Mermaid->new() ;
    my $out = $obj->process( 'gantt', $content, $params) ;

=head1 DESCRIPTION

convert data into an image using http://knsv.github.io/mermaid

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Mermaid ;

use 5.10.0 ;
use strict ;
use warnings ;
use Moo ;
use Path::Tiny ;
use App::Basis ;
use App::Basis::ConvertText2::Support ;
use Furl ;
use namespace::autoclean ;
use feature 'state' ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{mermaid gantt}] }
) ;

# ----------------------------------------------------------------------------

my $default_css = <<END_CSS;
/* Flowchart variables */
/* Sequence Diagram variables */
/* Gantt chart variables */
.mermaid .label {
  color: #333333;
}
.node rect,
.node circle,
.node polygon {
  fill: #ececff;
  stroke: #ccccff;
  stroke-width: 1px;
}
.edgePath .path {
  stroke: #333333;
}
.cluster rect {
  fill: #ffffde !important;
  rx: 4 !important;
  stroke: #aaaa33 !important;
  stroke-width: 1px !important;
}
.cluster text {
  fill: #333333;
}
.actor {
  stroke: #ccccff;
  fill: #ececff;
}
text.actor {
  fill: black;
  stroke: none;
}
.actor-line {
  stroke: grey;
}
.messageLine0 {
  stroke-width: 1.5;
  stroke-dasharray: "2 2";
  marker-end: "url(#arrowhead)";
  stroke: #333333;
}
.messageLine1 {
  stroke-width: 1.5;
  stroke-dasharray: "2 2";
  stroke: #333333;
}
#arrowhead {
  fill: #333333;
}
#crosshead path {
  fill: #333333 !important;
  stroke: #333333 !important;
}
.messageText {
  fill: #333333;
  stroke: none;
}
.labelBox {
  stroke: #ccccff;
  fill: #ececff;
}
.labelText {
  fill: black;
  stroke: none;
}
.loopText {
  fill: black;
  stroke: none;
}
.loopLine {
  stroke-width: 2;
  stroke-dasharray: "2 2";
  marker-end: "url(#arrowhead)";
  stroke: #ccccff;
}
.note {
  stroke: #aaaa33;
  fill: #fff5ad;
}
.noteText {
  fill: black;
  stroke: none;
 /* font-family: arial;*/
  font-size: 10px;
}
/** Section styling */
.section {
  stroke: none;
  opacity: 0.2;
}
.section0 {
  fill: rgba(102, 102, 255, 0.49);
}
.section2 {
  fill: #fff400;
}
.section1,
.section3 {
  fill: white;
  opacity: 0.2;
}
.sectionTitle0 {
  fill: #333333;
}
.sectionTitle1 {
  fill: #333333;
}
.sectionTitle2 {
  fill: #333333;
}
.sectionTitle3 {
  fill: #333333;
}
.sectionTitle {
  text-anchor: start;
  font-size: 10px;
  text-height: 12px;
}
/* Grid and axis */
.grid .tick {
  stroke: lightgrey;
  opacity: 0.3;
  shape-rendering: crispEdges;
}
.grid path {
  stroke-width: 0;
}
/* Today line */
.today {
  /*fill: red;*/
  stroke: red;
  stroke-width: 1px;
}
/* Task styling */
/* Default task */
.task {
  stroke-width: 1px;
}
.taskText {
  text-anchor: middle;
  font-size: 10px;
}
.taskTextOutsideRight {
  fill: black;
  text-anchor: start;
  font-size: 10px;
}
.taskTextOutsideLeft {
  fill: black;
  text-anchor: end;
  font-size: 10px;
}
/* Specific task settings for the sections*/
.taskText0,
.taskText1,
.taskText2,
.taskText3 {
  fill: white;
}
/*future tasks*/
.task0,
.task1,
.task2,
.task3 {
  fill: gray;
  /*stroke: black;
  stroke-width: 1px;
  */
}
.taskTextOutside0,
.taskTextOutside2 {
  fill: black;
}
.taskTextOutside1,
.taskTextOutside3 {
  fill: black;
}
/* Active task */
.active0,
.active1,
.active2,
.active3 {
  fill: DarkOrange;
/*  stroke: black;*/
}
.activeText0,
.activeText1,
.activeText2,
.activeText3 {
  fill: black !important;
}
/* Completed task */
.done0,
.done1,
.done2,
.done3 {
/*  stroke: black;
 stroke-width: 1px;
 */
  fill: green;
}
.doneText0,
.doneText1,
.doneText2,
.doneText3 {
  fill: black !important;
}
/* Tasks on the critical line */
.crit0,
.crit1,
.crit2,
.crit3 {
/*  stroke: #ff8888;
 stroke-width: 1px;
 */
  fill: red;
}
.activeCrit0,
.activeCrit1,
.activeCrit2,
.activeCrit3 {
  stroke: red;
  fill: DarkOrange;
  stroke-width: 1px;
}
.doneCrit0,
.doneCrit1,
.doneCrit2,
.doneCrit3 {
  stroke: red;
  fill: green;
  stroke-width: 1px;
  cursor: pointer;
  shape-rendering: crispEdges;
}
.doneCritText0,
.doneCritText1,
.doneCritText2,
.doneCritText3 {
  fill: black !important;
}
.activeCritText0,
.activeCritText1,
.activeCritText2,
.activeCritText3 {
  fill: black !important;
}
.titleText {
  text-anchor: middle;
  font-size: 12px;
  fill: black;
}

.mermaid {
  width:100%;
}

END_CSS

my $mermaid_html = <<MERMAIDHTML;
<html>
<head>
<script type='text/javascript' src='./mermaid.min.js'></script>

<script type='text/javascript'>
mermaid.initialize({
  startOnLoad:true,
  gantt: {
    titleTopMargin:15,
    fontSize:10,
    barHeight:12,
    barGap:3,
    topPadding:50,
    sidePadding:75,
    gridLineStartPadding:50,
    numberSectionStyles:2,
    // see this page for spec http://knsv.github.io/mermaid/gantt.html
    axisFormatter: [
      // Within a day
      //["%I:%M", function (d) {
      //  return d.getHours();
      //}],
      ["", function (d) {
        return d.getHours();
      }],
      // Monday a week
      ["%b %d", function (d) {
        return d.getDay() == 1;
      }],
      // Day within a week (not monday)
      ["", function (d) {
        return d.getDay() && d.getDate() != 1;
      }],
      // within a month
      ["%d", function (d) {
        return d.getDate() != 1;
      }],
      // Month
      ["%b %d", function (d) {
        return d.getMonth();
      }]
    ]
  }
}) ;

</script>
</head>
<body>
%ELEMENT%
</body>
</html>

MERMAIDHTML

# ----------------------------------------------------------------------------

# all the possible chart types
# flowchart sequence gantt

my %packages = map { $_ => "$_-package" } qw( gantt) ;

my $mermaid_js
    = "https://cdn.rawgit.com/knsv/mermaid/0.5.0/dist/mermaid.min.js" ;

# ----------------------------------------------------------------------------

sub fetch_mermaid
{
    my ($cachedir) = @_ ;

    my $cachefile = "$cachedir/mermaid.min.js" ;

    return if ( -f $cachefile ) ;

    my $furl = Furl->new(
        agent   => get_program(),
        timeout => 0.2,
    ) ;

    my $res = $furl->get($mermaid_js) ;
    if ( $res->is_success ) {
        path($cachefile)->spew_raw( $res->content ) ;
    } else {
        debug( "ERROR", "could not fetch $mermaid_js" ) ;
    }
}

# ----------------------------------------------------------------------------

=item gantt_package

create a gantt chart, from the passed text

 parameters
    data - the chart data, reference to array of lines
    x    - width
    y    - height 

data is 


=cut

sub gantt_package
{
    my $self = shift ;
    my ( $data, $x, $y, $params, $cachedir ) = @_ ;

    state $element_id = 1 ;

    my $element = "gantt_$element_id" ;

    my $style = "style='" ;
    $style .="width: $x;" if( $x) ;
    $style .= "height: $y;" if( $y);
    $style .="'" ;

    my $title = "title $params->{title}" if( $params->{title}) ;

    my $div
        = "<div id='$element' class='mermaid $params->{class}' $style>
gantt
dateFormat  YYYY-MM-DD
$title
$data
</div>" ;
    my $html = $mermaid_html ;
    $html =~ s/%ELEMENT%/$div/gsm ;

    # ready for the next one
    $element_id++ ;

    return phantomjs( $html, $element, 1, $cachedir ) ;
}

# ----------------------------------------------------------------------------

=item mermaid

create a images, from the passed text

 parameters
    data        - the  data
    package     - things we can create

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
    state $css = 0 ;

    if( !$css) {
        add_css( $default_css) ;
        $css++ ;
    }

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

    if ( $tag ne 'mermaid' ) {
        $params->{package} = $tag ;
    }

    # if the drawing command is one we recognise, use it
    if ( $params->{package} && $packages{ $params->{package} } ) {
        $package = $params->{package} ;
    } else {
        return "bad mermaid package defined <b>$params->{package}</b>" ;
    }

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    # setup the package function name
    $package .= "_package" ;

    if ( $self->can($package) ) {
        # we can use the cache or process everything ourselves
        my $sig = create_sig( $content, $params ) ;
        my $filename = cachefile( $cachedir, "$tag.$sig.svg" ) ;
        my $out ;
        if ( !-f $filename ) {
            fetch_mermaid($cachedir) ;
            $out = $self->$package( $content, $x, $y, $params, $cachedir ) ;
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
