
=head1 NAME

App::Basis::ConvertText2::Plugin::Text

=head1 SYNOPSIS

Handle a few simple text code blocks

    my $obj = App::Basis::ConvertText2::Plugin::Text->new() ;
    my $content = "" ;
    my $params = { } ;
    # new page
    my $out = $obj->process( 'page', $content, $params) ;

    # yamlasjson
    $content = "list:
      - array: [1,2,3,7]
        channel: BBC3
        date: 2013-10-20
        time: 20:30
      - array: [1,2,3,9]
        channel: BBC4
        date: 2013-11-20
        time: 21:00
    " ;
    $out = $obj->process( 'yamlasjson', $content, $params) ;
    # or as XML
    $out = $obj->process( 'yamlasxml', $content, $params) ;

    # table
    $content = "row1,entry 1,cell2
    row2,cell1, entry 2
    " ;
    $out = $obj->process( 'table', $content, $params) ;

    # version
    $content = "0.1 2014-04-12
      * removed ConvertFile.pm
      * using Path::Tiny rather than other things
      * changed to use pandoc fences ~~~~{.tag} rather than xml format <tag>
    0.006 2014-04-10
      * first release to github" ;
    $out = $obj->process( 'table', $content, $params) ;

    $content = "BBC | http://bbc.co.uk
    DocumentReference  | #docreference
    27escape | https://github.com/27escape" ;
    $out = $obj->process( 'table', $content, $params) ;

=head1 DESCRIPTION

Various simple text transformations

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Text ;

use 5.10.0 ;
use strict ;
use warnings ;
use YAML qw(Load) ;
use JSON::MaybeXS ;
use XML::Simple qw(XMLout) ;
use Moo ;
use App::Basis::ConvertText2::Support ;
use namespace::clean ;

local $YAML::Preserve = 1 ;

use feature 'state' ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub {
        [   qw{yamlasjson yamlasxml table spreadsheet version page
                columns links tree
                box note info tip important caution warn warning danger todo aside question fixme error sample read console
                quote
                appendix
                counter
                comment
                indent
                percent
                }
        ] ;
    }
) ;

# ----------------------------------------------------------------------------
# these things are the same as a box

my %as_box = map { $_ => 'box' }
    qw (note info tip important caution warn warning danger todo aside question fixme error sample read console)
    ;

# ----------------------------------------------------------------------------

my $default_css = <<END_CSS;
    /* Text.pm css */

    /* zebra tables */
    tr.odd { background: white;}
    tr.even {background: whitesmoke;}

/* drop-shadow filter applied to anything in the class, we need a background color to make sure it
 * gets used properly for the entire table and not the contents
 */

    table.spreadsheet td {
        border: 1px solid #ccc;
        background: white ;
    }
    table.spreadsheet th {
        border: 1px solid #ccc;
        text-align: center;
    }

    table.spreadsheet td.cell {
        background: grey200;
        color: black ;
    }
    table.spreadsheet td.cell.active {
        background: #5f90b0;
        /*border: 1px solid #5f90b0;*/
        color: white ;
    }

    blockquote {
        font-family: helvetica;
        font-style: italic;
        font-size: 14px;
        margin: 1em 3em;
        padding: .5em 1em;
        border-left: 4px solid #666666;
        background-color: #eeeeee;
    }

    blockquote p {
        margin: 0;
    }

    blockquote.quote {
        font-family: helvetica;
        font-style: italic;
        font-size: 14px;
        margin: 1em 3em;
        padding: .5em 1em;
        border-left: 4px solid #FCC02D; /* yellow700*/
        border-right: 4px solid #FCC02D; /* yellow700*/
        background-color: #FFFDE7; /*yellow50 */
    }

    blockquote.quote p {
        margin: 0;
    }

    blockquote.quote:before, blockquote:after {
        color: red;
        display: block;
        font-size: 400%;
    }

    blockquote.quote:before {
        content: open-quote;
    }

    blockquote.quote:after {
        content: close-quote;
    }

    div.quote {
        margin-left: auto ;
        margin-right: auto ;
        width: 100%;
    }
    div.quote > p {
        text-align: center;
        font-size: 130%;
    }

    .percent {
        display: inline-block ;
        width: 100px;
        padding: 0px;
        margin: 0px ;
        border: 0px ;
        background: bluegrey50;
        vertical-align: middle ;
    }

    .percent > .bar {
        display: inline-block ;
        font-weight: bold;
        background: blue400;
        padding: 0px;
        text-align: right;
        mix-blend-mode:darken;
    }
    /* standard 'title' captions on top */
    caption, caption.title {
        caption-side: top;
        font-size: 70%;
    }
    /* 'footer' captions underneath */
    caption.footer {
        caption-side: bottom ;
        font-size: 70%;
    }

    ul.version {
        margin-top: 0 ;
        margin-bottom: 0;
    }

END_CSS

# ----------------------------------------------------------------------------
# make numeric entries in a hash properly numbers so that when the hash is used
# to generate JSON then the correct values will be displayed
# ie. numbers will not be represented as strings
# use this function recursively to keep things simple!

sub _make_numbers
{
    my $item = shift ;

    if ( ref($item) eq 'HASH' ) {
        foreach my $key ( keys %{$item} ) {
            $item->{$key} = _make_numbers( $item->{$key} ) ;
        }
    } elsif ( ref($item) eq 'ARRAY' ) {
        for ( my $i = 0; $i < scalar( @{$item} ); $i++ ) {
            ${$item}[$i] = _make_numbers( ${$item}[$i] ) ;
        }
    } elsif ( ref($item) eq '' || ref($item) eq 'SCALAR' ) {
        if ($item) {
            if ( $item =~ /^\d+(\.\d+)?$/ ) {
                # force numbers to be numbers
                $item += 0 ;
            } elsif ( $item eq 'true' ) {
                # boolean true
                # $item = Types::Serialiser::true ;
                $item = \1 ;
            } elsif ( $item eq 'false' ) {
                # boolean false
                # $item = Types::Serialiser::false ;
                $item = \0 ;
            }
        }
    }

    return $item ;
}

# ----------------------------------------------------------------------------

=item yamlasjson

Convert a YAML block into a JSON block

 parameters

=cut

sub yamlasjson
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    # make sure we have an extra linefeed at the end to make sure
    # YAML is correct
    $content .= "\n\n" ;

    # $content =~ s/~~~~\{\.yaml\}//gsm ;
    # $content =~ s/~~~~//gsm ;

    my $data = Load($content) ;
    my $str  = "" ;
    if ($data) {
        $data = _make_numbers($data) ;
        my $json = JSON::MaybeXS->new( utf8 => 1, pretty => 1 ) ;
        $str .= "\n\n~~~~ {.json wrap='72'}\n" . $json->encode($data) . "\n~~~~\n\n" ;
    }

    return $str ;
}

# ----------------------------------------------------------------------------

=item yamlasxml

Convert a YAML block into an XML block

 parameters

=cut

sub yamlasxml
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    # make sure we have an extra linefeed at the end to make sure
    # YAML is correct
    $content .= "\n\n" ;

    # $content =~ s/~~~~\{\.xml\}//gsm ;
    # $content =~ s/~~~~//gsm ;

    my $data = Load($content) ;
    my $str  = "" ;
    if ($data) {
        $data = _make_numbers($data) ;
        my $xml = XMLout( $data, RootName => "", NoAttr => 1 ) ;
        $str .= "\n\n~~~~ {.xml wrap='72'}\n$xml\n~~~~\n\n\n" ;
    }

    return $str ;
}


# ----------------------------------------------------------------------------
# get the style and class data from the passed table cell
# add in the cell class and style
# also remove the row class as nothing used it effectively
# {
# .class
# align things need to have a space between them
#  ^ valign top, - valign centre, _ valign bottom
#  < align left, = align center,  > align right
# #foreground.background   - set colors
# 30% - number to set a width percentage
# 30px - set width to number of pixels
# c2 - colspan a number of columns, 2 in this case
# }

sub _split_cell_data
{
    my ($cell) = @_ ;
    my ( $class, $style, $colspan ) ;

    while ( $cell =~ s/\{(.*?)\}\s*$// ) {
        my $cs = $1 ;
        $cs =~ s/^\s+|\s+$//g ;    # trim whitespace

        # cell color may contain a period so lets do that first
        if ( $cs =~ s/#(([\w\-]+)?\.?([\w\-]+)?)$// ) {
            my ( $fg, $bg ) = ( $2, $3 ) ;
            $style .= "color: " . to_hex_color($fg) . ";" if ($fg) ;
            $style .= "background-color: " . to_hex_color($bg) . ";"
                if ($bg) ;
        }

        # any colspan
        if ( $cs =~ s/\bc(\d+)\b// ) {
            $colspan = $1 ;
        }
        # do rowspans??

        # any class
        if ( $cs =~ s/\.([\w\-_]+)// ) {
            $class .= "$1 " ;
        }
        if ( $cs =~ s/(\d+%|\d+px)// ) {
            $style .= "width: $1;" ;
        }

        # we can have one horizontal align
        if ( $cs =~ /=/ ) {
            $style .= "text-align: center;" ;
        } elsif ( $cs =~ /</ ) {
            $style .= "text-align: left;" ;
        } elsif ( $cs =~ />/ ) {
            $style .= "text-align: right;" ;
        }
        # and one vertical align
        if ( $cs =~ /\^/ ) {
            $style .= "vertical-align: top;" ;
        } elsif ( $cs =~ /-/ ) {
            $style .= "vertical-align: middle;" ;
        } elsif ( $cs =~ /_/ ) {
            $style .= "vertical-align: bottom;" ;
        }
    }

    # if we really want 0 lets have it
    $cell =~ s/^\s+|\s+$//g ;
    if ( defined $cell && $cell =~ /^0$/ ) {
        # make sure zero is a string
        $cell .= "" ;
    }
    return ( $class, $style, $cell, $colspan ) ;
}

# ----------------------------------------------------------------------------

=item table

create a basic html table

 parameters
    data   - comma separated lines of table data

    hashref params of
        class   - HTML/CSS class name
        id      - HTML/CSS class
        title   - describe table above it
        caption - describe table below it
        width   - width of the table
        style   - style the table if not doing anything else
        legends - flag to indicate that the top row is the legends
        separator - characters to be used to separate the fields
        zebra   - apply odd/even classes to table rows, default 0 OFF
        align   - option, set alignment of entire table
        sort    - sort on a column number, "1", "1r"
        columns - columns to be included in the output "1,2,3,4"

=cut

sub table
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    return "" if ( !$content ) ;

    # note if we are really a spreadsheet table
    my $spreadsheet = $tag eq 'spreadsheet' ;

    $params->{legends} ||= $params->{legend} ;    # aka just in case
    $params->{title}   ||= "" ;
    $params->{caption} ||= "" ;
    $params->{class}   ||= "" ;
    $content =~ s/^\n//gsm ;
    $content =~ s/\n$//gsm ;

    # open the csv file, read contents, calc max, add into data array
    # inline {{.tag }} constructs need to be protected
    $content =~ s/\{{2}/_BR_O_/gsm ;
    $content =~ s/\}{2}/_BR_C_/gsm ;
    my @data = split_csv_data( $content, $params->{separator} ) ;

    if ( defined $params->{sort} ) {
        my $legends ;
        $legends = shift @data if ( $params->{legends} ) ;
        @data = sort_column_data( \@data, $params->{sort} ) ;

        # add legends back to start
        unshift @data, $legends if ($legends) ;
    }

    # default align center
    my $align = "margin: 0 auto;" ;

    if ( $params->{align} ) {
        if ( $params->{align} =~ /left/i ) {
            $align = "margin-left: 0 ; margin-right: auto;" ;
        } elsif ( $params->{align} =~ /right/i ) {
            $align = "margin-left: auto; margin-right 0;" ;
        }
    }

    my $out = "<table " ;
    $out .= "class='$params->{class}' " ;
    $out .= "id='$params->{id}' " if ( $params->{id} ) ;
    $out .= "width='$params->{width}' " if ( $params->{width} ) ;
    if ( $params->{style} ) {
        $out .= "style='$align$params->{style}' " ;
    } else {
        $out .= "style='$align' " ;
    }
    $out .= ">\n" ;

    # tables can have a title AND a caption
    if ( $params->{title} ) {
        $out .= "<caption class='title'>$params->{title}</caption>\n" ;
    }
    if ( $params->{caption} ) {
        $out .= "<caption class='footer'>$params->{caption}</caption>\n" ;
    }

    my $maxcol = 0 ;
    for ( my $i = 0; $i < scalar(@data); $i++ ) {
        $maxcol = scalar @{ $data[$i] }
            if ( scalar @{ $data[$i] } > $maxcol ) ;
    }

    my $leg_row = 0 ;
    if ($spreadsheet) {

        # lets limit the number of named columns to something sensible
        $maxcol = 26 if ( $maxcol > 26 ) ;

        my @tmp = map {
            my $value = $_ ;

            # first entry is blank to accomodate the row counter, has no class
            $value
                ? "**" . chr( ord('A') + $value - 1 ) . "** {.cell =}"
                : ":fa:table: {.cell =}" ;
        } 0 .. $maxcol ;

        unshift @data, \@tmp ;

        $leg_row++ ;
    }

    # add in the row counters
    my $rcount = 1 ;
    my $w      = '15px' ;

    if ( scalar(@data) > 100 ) {
        $w = '30px' ;
    } elsif ( scalar(@data) > 10 ) {
        $w = '20px' ;
    }
    my $colclass ;
    my $colstyle ;
    for ( my $i = 0; $i < scalar(@data); $i++ ) {
        my @col = @{ $data[$i] } ;
        # for a spreadsheet we need to add a new cell to the start of the list
        # to hold the row number, this has a width dependant on the max number
        # the rows get up to
        if ( $i && $spreadsheet ) {
            my $c = "$rcount {.cell =" ;
            # only need width on first row
            if ( $i == 1 ) {
                $c .= " $w" ;
            }
            unshift @col, "$c}" ;
            $rcount++ ;
        }
        my $class = $params->{zebra} ? ( $i & 1 ? 'odd' : 'even' ) : '' ;
        my $style = "" ;
        my $last  = pop @col ;

        # row color last thing on the line after class removed
        if ( $last && $last =~ s/#(([\w\-]+)?\.?([\w\-]+)?)\s?$// ) {
            my ( $fg, $bg ) = ( $2 || "", $3 || "" ) ;
            $style .= "color: " . to_hex_color($fg) . ";" if ($fg) ;
            $style .= "background-color: " . to_hex_color($bg) . ";"
                if ($bg) ;
        }
        push @col, $last ;

        # pad columns if needed
        if ( @{ $data[$i] } < $maxcol ) {
            push @col, map {"&nbsp;"} scalar( @{ $data[$i] } ) .. $maxcol - 1 ;
        }
        $out .= "<tr" ;
        $out .= " class='$class'" if ($class) ;
        $out .= " style='$style'" if ($style) ;
        $out .= ">" ;

        # decide if the top row has the legends
        my $pos    = 0 ;
        my $ccount = 0 ;
        # ccount keeps track of the number of columns and counts spans
        for ( my $j = 0; $ccount < scalar(@col); $j++ ) {
            my $cell = $col[$j] ;
            $cell //= '&nbsp;' ;    # only add the space if the value is undefined, ie not 0
            $cell =~ s/^\s+|\s+$//g ;

            my $tag = 'td' ;
            # gets messy trying to do this in a single line, so for clarity ...
            if ( $params->{legends} ) {
                if ($spreadsheet) {
                    # need to make sure the row number is not a heading
                    if ( $i == $leg_row && $pos ) {
                        $tag = 'th' ;
                    }
                } elsif ( $i == $leg_row ) {
                    $tag = 'th' ;
                }
            }

            my ( $class, $style, $data, $colspan ) = _split_cell_data($cell) ;
            if ( $tag eq 'th' ) {
                # save col class and style so it can be used as default for element
                $colclass->[$pos] = $class ;
                $colstyle->[$pos] = $style ;
            } else {
                # use column styling if there is nothing specific
                $class ||= $colclass->[$pos] ;
                $style ||= $colstyle->[$pos] ;
            }
            $out .= "<$tag" ;
            $out .= " class='$class'" if ($class) ;
            $out .= " style='$style'" if ($style) ;
            $out .= " colspan='$colspan'" if ($colspan) ;
            $out .= ">$data</$tag>" ;
            if ($colspan) {
                $ccount += $colspan ;
            } else {
                $ccount++ ;
            }
            $pos++ ;
        }
        $out .= "</tr>\n" ;
    }
    $out .= "</table>\n" ;

    $out =~ s/_BR_O_/{{/gsm ;
    $out =~ s/_BR_C_/}}/gsm ;

    return $out ;
}

# ----------------------------------------------------------------------------

=item spreadsheet

a special version of table

 parameters
    data   - comma separated lines of table data

    hashref params of
        class   - HTML/CSS class name
        id      - HTML/CSS class
        title   - describe table above it
        caption - describe table below it
        width   - width of the table, default 100%
        style   - style the table if not doing anything else
        legends - flag to indicate that the top row is the legends
        separator - characters to be used to separate the fields
        align   - option, set alignment of entire table, default left
        sort    - sort on a column number, "1", "1r"
        columns - columns to be included in the output "1,2,3,4"
        worksheets - csv of worksheets for this spreadsheet, 1st bold is the active one

=cut

sub spreadsheet
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    return "" if ( !$content ) ;

    # make sure we are a spreadsheet, also have a shadow (on html output) to
    # make it stand out
    $params->{class} = "spreadsheet shadow" . ( $params->{class} ? " $params->{class}" : "" ) ;
    # no zebra for spreadsheet
    $params->{zebra} = 0 ;
    $params->{align} ||= "left" ;
    $params->{width} ||= "100%" ;

    # add in any workbooks, sheets is the same
    $params->{worksheets} ||= $params->{sheets} ;
    # set a default now for all spreadsheets
    # $params->{worksheets} ||= '!Sheet1' ;
    if ( $params->{worksheets} ) {
        my $sep = $params->{separator} || "," ;
        # add a couple of blank rows to the spreadsheet to make it look nicer
        $content .= "\n" . ( " $sep\n" x 2 ) ;
    }

    my $sheet =
        "<div class='spreadsheet'>" . $self->table( "spreadsheet", $content, $params, $cachedir ) ;
    if ( $params->{worksheets} ) {
        $sheet .= "<table class='$params->{class}' style='margin-left: 0;margin-top:0;'><tr>" ;
        my $has_active = 0 ;
        foreach my $ws ( split( ',', $params->{worksheets} ) ) {
            # active sheet starts with '!'
            my $class = "cell" ;
            if ( $ws =~ /\s?!(.*)/ && !$has_active ) {
                $ws = $1 ;
                $class .= " active" ;

                $has_active = 1 ;
            }
            $sheet .= "<td class='$class'>$ws</td>" ;
        }

        $sheet .= "</tr></table>" ;
    }
    $sheet .= "</div>" ;

    return $sheet ;
}

# ----------------------------------------------------------------------------

=item version

create a version table

 parameters
    data   - sections of version information
        version YYYY-MM-DD
          change text
          more changes


    hashref params of
        class   - HTML/CSS class name
        id      - HTML/CSS class
        width   - width of the table
        title   - option title for the section, default 'Document Revision History'
        style   - style the table if not doing anything else
        separator - characters to be used to separate the fields
        items   - only show top 'x' items

=cut

sub version
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    # $params->{title} ||= 'Document Revision History' ;
    my $item_count = 0 ;

    $content =~ s/^\n//gsm ;
    $content =~ s/\n$//gsm ;
    $params->{class} ||= "" ;
    $params->{width} ||= "100%" ;

    my $out = "<div class='version'>"
        . (
        $params->{title}
        ? "<h2 class='toc_skip'>$params->{title}</h2>"
        : ""
        ) ;
    $out .= "<table " ;
    $out .= "class='$tag $params->{class}' " ;
    $out .= "id='$params->{id}' " if ( $params->{id} ) ;
    $out .= "width='$params->{width}' " if ( $params->{width} ) ;
    $out .= "style='$params->{style}' " if ( $params->{style} ) ;
    $out .= ">\n" ;

    $out .= "<tr><th width='20%'>Version</th><th width='20%'>Date</th><th>Changes</th></tr>\n" ;

    # my $section = '^(.*?)\s+(\d{2,4}[-\/]\d{2}[-\/]\d{2,4})\s?$' ;
    my $section = '^([\d|v].*?)\s+(\d{2,4}[-\/]\d{2}[-\/]\d{2,4})(.*)?$' ;

    my @data = split( /\n/, $content ) ;
    for ( my $i = 0; $i < scalar(@data); $i++ ) {
        if ( $data[$i] =~ /$section/ ) {
            my ( $vers, $date, $extra ) = ( $1, $2, $3 ) ;

            $i++ ;
            my $c = "" ;
            $c = "* $extra\n" if ($extra) ;

            # get all the lines in this section
            while ( $i < scalar(@data) && $data[$i] !~ /$section/ ) {
                $data[$i] =~ s/^\s{4}// ;
                $c .= "$data[$i]\n" ;
                $i++ ;
            }

            if ( !$params->{items} || int( $params->{items} ) > $item_count ) {
                # convert any of the data with markdown
                my $list = convert_md($c) ;
                $list =~ s/<ul>/<ul class=version>/gsm ;
                $out
                    .= "<tr><td valign='top' align=center>$vers</td><td valign='top' align=center>$date</td><td valign='top'>"
                    . $list
                    . "</td></tr>\n" ;
            }
            $item_count++ ;

            # adjust $i back so we are either at the end correctly or on the next section
            $i-- ;
        }
    }

    $out .= "</table></div>\n" ;
    return $out ;
}

# ----------------------------------------------------------------------------

=item ~~~~{.page }

Start a new page, alternatively just use '---' as the only thing on a line

There are no contents to a page

    ~~~~{.page}
    ~~~~

=cut

sub page
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    return "<div style='page-break-before: always;'></div>" ;
}

# ----------------------------------------------------------------------------

=item ~~~~{.columns }

Split a section into multiple columns

 parameters
    count   - number of columns to split into, defaults to 2
    lines   - number of lines the section should hold, defaults to 20
    ruler   - show a line between the columns, defaults to no,
              options are 1, true or yes to show it
    width   - how wide should it be, defaults to 100%
    class

    ~~~~{.columns count=2 lines=5}
    some text
    more text
    even more text
    line 4
    line5
    this should be at the start of column 2
    ~~~~

=cut

sub columns
{
    my $self = shift ;
    state $style ;
    state $style_count = 0 ;

    my ( $tag, $content, $params, $cachedir ) = @_ ;
    my $out  = "" ;
    my $rule = 'none' ;

    $params->{count} ||= 2 ;
    $params->{lines} ||= 20 ;
    $params->{ruler} ||= 'no' ;
    $params->{width} ||= '100%' ;
    $params->{class} ||= "" ;

    # make sure its a string
    $params->{ruler} .= "" ;
    if ( $params->{ruler} =~ /^(1|yes|true)$/i ) {
        $rule = 'thin solid black' ;
        $params->{ruler} = 'yes' ;
    } else {
        $params->{ruler} = 'yes' ;
    }

    # we create a sig based on the parameters and do not include the content
    # as we can reuse the same layout for other elements
    my $sig = create_sig( '', $params ) ;
    my $idname ;

    # we may have to add a new style section for this column layout
    if ( !$style->{$sig} ) {

        # create a uniq name for this style
        $style_count++ ;
        $idname = "column$style_count" ;

        # add in the webkit and mozilla styling for completeness
        # just in case someones browser is not up to date and we are
        # creating html only
        my $css = "#$idname {
        max-height: $params->{lines} ;
        width: $params->{width};
        column-width: auto;
        column-count: $params->{count} ;
        column-rule: $rule;
        column-gap: 2em;
        column-rule: $rule;
        overflow: visible;

        -webkit-column-count: $params->{count};
        -webkit-column-rule: $rule;
        -webkit-column-gap: 2em;

        -moz-column-count: $params->{count};
        -moz-column-rule: $rule;
        -moz-column-gap: 2em;

        display: block;
    }\n" ;
        add_css($css) ;

        $style->{$sig} = $idname ;
    } else {
        $idname = $style->{$sig} ;
    }

    $out .= "<div id='$idname' class='$tag $params->{class}'>\n$content\n</div>\n" ;

    return $out ;
}

# ----------------------------------------------------------------------------

=item ~~~~{.links }

create a list of website links
links are one per line and the link name is separated from the link with a
pipe '|' symbol

 parameters
    class   - name of class for the list
    table   - create a table rather than a list
    width   - width of the table, if used
    hide    - hide the links, still allows them to act as references to websites

=cut

sub links
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    chomp $content ;
    return "" if ( !$content ) ;

    $params->{class} ||= "" ;
    my $references = "" ;
    my $ul         = "<ul class='$tag $params->{class}'>\n" ;
    my %refs       = () ;
    my %uls        = () ;
    my $width      = $params->{width} ? " width='$params->{width}'" : "" ;

    if ( $params->{table} ) {
        $ul =
            "<table class='$params->{class} $tag'$width><tr><th>Reference</th><th>Link</th></tr>\n"
            ;
    }

    foreach my $line ( split( /\n/, $content ) ) {
        my ( $ref, $link ) = split( /\|/, $line ) ;
        next if ( !$link ) ;

        # trim the items
        $ref =~ s/^\s+// ;
        $link =~ s/^\s+// ;
        $ref =~ s/\s+$// ;
        $link =~ s/\s+$// ;

        # if there is nothing to link to ignore this
        next if ( !$ref || !$link ) ;

        $references .= "[$ref]: $link\n" ;

        # links that reference inside the document do not get added to the
        # list of links
        if ( $link !~ /^#/ ) {
            if ( $params->{table} ) {
                $uls{ lc($ref) } =
                    "<tr><td class='reference'><a href='$link'>$ref</a></td><td class='link'>$link</td></tr>\n"
                    ;
            } else {
                $uls{ lc($ref) } = "<li><a href='$link'>$ref</a><ul><li>$link</li></ul></li>\n" ;
            }
        }
    }

    # make them nice and sorted
    map { $ul .= $uls{$_} } sort keys %uls ;

    if ( $params->{table} ) {
        $ul .= "</table>\n" ;
    } else {
        $ul .= "</ul>\n" ;
    }
    if ( $params->{hide} ) {
        # wrap the output in a hidden div
        $references = "<div style='display: none'>\n$references" ;
        $ul .= "\n</div>" ;
    }

    return "\n" . $references . "\n" . $ul . "\n" ;
}

# ----------------------------------------------------------------------------

=item ~~~~{.tree }

Draw a bulleted list as a directory tree, bullets are expected to be indented
by 4 spaces, we will only process bullets that are * +  or -

    ~~~~{.tree}
    * one
        * 1.1
    * two
        * two point 1
        * 2.2
    * three
        * 3.1
        * 3.2
        * three point 3
    ~~~~

This shows up great when creating PDF with princexml, less well when using wkhtmltopdf
or viewing HTML with a browser, not sure why, likely to be the embedded background images
which are not displaying

 parameters

@todo try this: find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'
or
tree -C -L 2 -T "Ice's webpage" -H "http://mama.indstate.edu/users/ice" --charset=utf8 -o 00Tree.html

=cut

sub tree
{
    my $self = shift ;
    state $style       = {} ;
    state $style_count = 1 ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    my $out = "" ;

    $params->{class} ||= "" ;
    $params->{color} ||= 'black' ;

    # incase material colors used
    $params->{color} = to_hex_color( $params->{color} ) ;

    # we create a sig based on the parameters and do not include the content
    # as we can reuse the same layout for other elements
    my $sig = create_sig( '', $params ) ;
    my $idname ;

    # we may have to add a new style section for this column layout
    if ( !$style->{$sig} ) {

        # create a uniq name for this style
        $style_count++ ;
        $idname = "column$style_count" ;

        # taken from http://odyniec.net/articles/turning-lists-into-trees/
        my $css .= "ul#$idname, ul#$idname ul {
    list-style-type: none;
    /* vline.png */
    background: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAKAQMAAABPHKYJAAAAA1BMVEWIiIhYZW6zAAAACXBIWXMA
AAsTAAALEwEAmpwYAAAAB3RJTUUH1ggGExMZBky19AAAAAtJREFUCNdjYMAEAAAUAAHlhrBKAAAA
AElFTkSuQmCC
) repeat-y;
    margin: 0;
    padding: 0;
}

ul#$idname ul {
    margin-left: 10px;
}

ul#$idname li {
    margin: 0;
    padding: 0 12px;
    line-height: 20px;
    /* node.png */
    background: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAUAQMAAACK1e4oAAAABlBMVEUAAwCIiIgd2JB2AAAAAXRS
TlMAQObYZgAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB9YIBhQIJYVaFGwAAAARSURBVAjX
Y2hgQIf/GTDFGgDSkwqATqpCHAAAAABJRU5ErkJggg==
) no-repeat;
    color: $params->{color};
    font-weight: bold;
}

ul#$idname li.last {
    /*lastnode.png*/
 background: #fff url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAUAQMAAACK1e4oAAAABlBMVEUAAwCIiIgd2JB2AAAAAXRS
TlMAQObYZgAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB9YIBhQIIhs+gc8AAAAQSURBVAjX
Y2hgQIf/GbAAAKCTBYBUjWvCAAAAAElFTkSuQmCC
) no-repeat;
}
\n" ;
        add_css($css) ;

        $style->{$sig} = $idname ;
    } else {
        $idname = $style->{$sig} ;
    }

    # we need to convert the bullet list into a HTML one
    $content = convert_md($content) ;

    # make sure the first ul has class tree
    $content =~ s/<ul>/<ul id='$idname' class='$tag $params->{class}'>/ ;

    my @lines = split( /\n/, $content ) ;
    for ( my $i = 0; $i < scalar(@lines); $i++ ) {
        if ( $lines[$i] =~ /<li>/ && $lines[ $i + 1 ] =~ /<\/ul>/ ) {
            $lines[$i] =~ s/<li>/<li class='last'>/ ;
        }
        $out .= "$lines[$i]\n" ;
    }

    return "$out<br>" ;
}

# ----------------------------------------------------------------------------

=item box | note | info | tip | important | caution | warn | warning | danger | todo | aside | question | fixme | error | sample | read | console

create a box around some text, if note is used and there is no title, then 'Note'
will be added as a default

    hashref params of
        class   - HTML/CSS class name
        id      - HTML/CSS class
        width   - width of the box (default 99%)
        title   - optional title for the section
        style   - style the box if not doing anything else
        icon    - add a fontawesome or google material icon to match the tag
                - default is fontawesome name if not specific trash -> :fa:trash
        align   - left, center, right

=cut

my %icons = (
    # danger    => ':mi:report:[2x]',
    # note      => ':mi:bookmark-border:[2x]',
    # info      => ':mi:info-outline:[2x]',
    # tip       => ':mi:lightbulb-outline:[2x]',
    # important => ':mi:star-border:[fliph 2x]',
    # warning   => ':mi:error-outline:[2x]',
    # caution   => ':mi:remove-circle-outline:[2x]',
    # danger    => ':mi:block:[2x #crimson]',
    # aside     => ':mi:center-focus-weak:[2x]',
    # todo      => ':mi:chat-bubble-outline:[fliph 2x]',
    # question  => ':mi:help-outline:[2x]',
    # fixme     => ':mi:pan-tool:[2x fliph #crimson]',
    # error     => ':mi:highlight-off:[2x #crimson]',
    danger    => ':mi:report:',
    note      => ':mi:bookmark-border:',
    info      => ':mi:info-outline:',
    tip       => ':mi:lightbulb-outline:',
    important => ':mi:star-border:[fliph]',
    warning   => ':mi:error-outline:',
    caution   => ':mi:remove-circle-outline:',
    danger    => ':mi:block:[#crimson]',
    aside     => ':mi:center-focus-weak:',
    todo      => ':mi:chat-bubble-outline:[fliph]',
    question  => ':mi:help-outline:',
    fixme     => ':mi:pan-tool:[fliph #crimson]',
    error     => ':mi:highlight-off:[#crimson]',
    sample    => ':fa:flask:',
    read      => ':fa:book:',
    console   => ':fa:terminal:[border]',
) ;

my %classmap = (
    box       => 'light',
    note      => 'normal',
    aside     => 'normal',
    todo      => 'primary',
    tip       => 'primary',
    info      => 'success',
    important => 'success',
    warning   => 'warning',
    caution   => 'danger',
    danger    => 'danger',
    question  => 'secondary',
    fixme     => 'danger',
    error     => 'danger',
    sample    => 'sample',
    read      => 'light',
    console   => 'console',
) ;

sub box
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    #  defaults
    # $params->{width} ||= '100%' ;
    $params->{width} ||= '100%' ;
    $params->{class} ||= "" ;
    $params->{style} ||= "" ;

    # notes may get a default title if its missing
    $params->{title} = ucfirst($tag)
        if ( !defined $params->{title} && $tag ne 'box' ) ;
    $params->{title} ||= "" ;
    my $out ;
    if($tag eq 'console') {
        # ALWAYS make console text in a pre block
        $content = "<pre>\n$content\n</pre>" ;
    }

    # $params->{class} = "$tag $params->{class} shadow" ;
    $params->{class} = "alert $classmap{$tag} $params->{class}" ;

    my $icon = "" ;
    $params->{style} = "width:$params->{width};$params->{style}" ;
    # if ( $tag ne 'box' ) {
    #     $params->{style} .= "margin-left: auto; margin-right: auto;" ;
    # }
    my $align = "margin-left: 0 ; margin-right: auto;" ;
    if ( $params->{align} ) {
        if ( $params->{align} =~ /center|centre/i ) {
            $align = "margin: 0 auto;" ;
        } elsif ( $params->{align} =~ /right/i ) {
            $align = "margin-left: auto; margin-right 0;" ;
        }
    }
    $params->{style} .= $align ;


    # boxes cannot have icons
    if ( $tag ne 'box' && $params->{icon} ) {

        # we can over-ride the icon with a string
        $icon =
            $params->{icon} eq "1"
            ? ( $icons{$tag} || "" )
            : $params->{icon} ;

        # allow icon flame hourglass etc, we will fix it up right
        # the default is fontaweome if there is no specific
        if ( $icon !~ /^:(fa|mi):/ ) {
            $icon = ":fa:$icon" ;
        }
        if ( $icon !~ /:\[.*?\]/ ) {
            $icon .= ':[]' ;
        }
        $icon =~ s/::/:/g ;

        # make them fixed width too
        if ( $icon !~ /\[.*?\bfw\b.*?\]/ ) {
            $icon =~ s/\]/ fw]/ ;
        }
    }
    $out .= "<div style='$params->{style}' class='$params->{class}' " ;
    $out .= "id='$params->{id}' " if ( $params->{id} ) ;
    $out .= ">" ;
    if ( $icon || $params->{title} ) {
        # $out .= "\n\n$icon " . ( $params->{title} ? "**$params->{title}**" : "" ) . "\n\n" ;
        $out
            .= "\n\n<span class='alert_title'><span class='alert_icon'>$icon</span> "
            . ( $params->{title} ? "$params->{title}</span>\n\n" : "" )
            . "\n\n" ;
    }
    # convert any content to HTML from Markdown
    # $out .= convert_md($content) ;
    $out .= "<div class='alert_content'>$content\n</div>" if ($content) ;
    $out .= "</div>\n" ;

    return $out ;
}

# ----------------------------------------------------------------------------

=item quote

create a quoted area around some text, slightly different to the usual blockquote
as you can provide a title for the quote

    hashref params of
        class   - HTML/CSS class name
        id      - HTML/CSS id
        title   - optional title to display above the quote
        width

=cut

sub quote
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    #  defaults
    $params->{class} ||= "" ;
    my $w = $params->{width} ? "style='width:$params->{width};' " : "" ;

    my $out = "<div class='$tag $params->{class}' $w>" ;
    $out .= "<p>$params->{title}</p>" if ( $params->{title} ) ;
    $out .= "<blockquote " ;
    $out .= "class='$tag $params->{class}' " ;
    $out .= "id='$params->{id}' "     if ( $params->{id} ) ;
    $out .= ">\n" ;

    # convert any content to HTML from Markdown
    $out .= convert_md($content) ;

    $out .= "</blockquote></div><br/>\n" ;
    return $out ;
}

# ----------------------------------------------------------------------------

=item appen
dix

return the next appendix value 'Appendix A' 'Appendix B'

 parameters

=cut

sub appendix
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    state $count = 0 ;
    my $str = "Appendix " . chr( 65 + $count ) ;
    if ( $count > 26 ) {
        # gives AA, AB, AC etc
        $str = "Appendix " . chr( 65 + int( $count / 26 ) ) . chr( 65 + $count % 26 ) ;
    }

    $count++ ;

    return $str ;
}

# ----------------------------------------------------------------------------

=item counter

return the next value of a named counter

 parameters

 name - name of counter to increment or default
 start - number to count from - or 0

=cut

sub counter
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    state $counters = {} ;
    my $name = $params->{name} || 'default' ;

    if ( $params->{start} && $params->{start} =~ s/^.*?(\d+).*/$1/ ) {
        $counters->{$name} = $params->{start} ;
    } else {
        $counters->{$name}++ ;
    }

    return $counters->{$name} ;
}

# ----------------------------------------------------------------------------

=item comment

remove block from the document, its just a comment

=cut

sub comment
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    return "" ;
}

# ----------------------------------------------------------------------------

=item indent

return each line of the content by 4 spaces

 parameters

 class - optional class to wrap around import
 style - optional style to wrap around import

=cut

sub indent
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    $content =~ s/^/    /gsm ;

    # add a div for class and style if required
    if ( $params->{class} || $params->{style} ) {
        my $div = "<div " ;
        $div .= "class='$params->{class}'" if ( $params->{class} ) ;
        $div .= "style='$params->{style}'" if ( $params->{style} ) ;
        $content = "$div>$content</div>" ;
    }

    return $content ;
}

# ----------------------------------------------------------------------------

=item percent

draw a percent bar

 parameters
     value - value of the percent, required, max 100, min 0
     color - color of the bar, optional
     border - add a grey border to the box, optional
     trigger - set the color based on the value
     width - width of the bounding box, optional

=cut

sub percent
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    my $style = "" ;

    $style .= $params->{border} ? "border:1px solid grey;" : "" ;

    if ( $params->{width} ) {
        $params->{width} .= "px" if ( $params->{width} !~ /%|px/ ) ;
        $style .= "width:$params->{width};" ;
    }
    $params->{value} =~ s/.*?(\d+).*/$1/ if ( $params->{value} ) ;
    my $value = int( $params->{value} ) ;
    if ( $value < 0 ) {
        $value = 0 ;
    } elsif ( $value > 100 ) {
        $value = 100 ;
    }
    my $barstyle = "" ;
    my $color = $params->{color} ? $params->{color} : "" ;

    if ( $params->{trigger} ) {
        $color = 'reda700' ;
        if ( $value >= 100 ) {
            $color = 'green700' ;
        } elsif ( $value >= 75 ) {
            $color = 'yellow500' ;
        } elsif ( $value >= 50 ) {
            $color = 'amber800' ;
        } elsif ( $value >= 25 ) {
            $color = 'red400' ;
        }
    }
    $barstyle .= "background:$color;" if ($color) ;

    $style .= $params->{size} ? "font-size:$params->{size};" : "" ;

    # $barstyle .= $params->{size} ? "font-size:$params->{size};" : "" ;
    $barstyle .= "width:$value%;" ;
    $content =
          "<div class='percent' style='$style'>"
        . "<div class='bar' style='$barstyle'>$value%</div>"
        . "</div>" ;

    return $content ;
}

# ----------------------------------------------------------------------------
# build the css for the different box types
# sub _admonition_css
# {
#     my $css = "    /* style for boxes/notes */\n" ;

# $css .= "    " . join( ", ", map {"div.$_ "} keys %as_box ) ;
# $css .= " {
#     margin-bottom: 1em;
#     border: 1px solid #e0e0e0 ;
# }\n" ;

# $css .= "    " . join( ", ", map {"table.$_ "} keys %as_box ) ;
# $css .= " {
#     padding: 0px;
#     margin: 0px;
#     text-align: left;
#     border-collapse: collapse;
# }\n" ;

# $css .= "    " . join( ", ", map { "td.$_" . "_left" } keys %as_box ) ;
# $css .= " {
#     padding: 0px;
#     margin: 0px;
#     text-align: center;
#     vertical-align: middle;
#     width:4%;
#     border: 0px;
#     border-right: 1px solid #e0e0e0 ;
# }\n" ;

# $css .= "    " . join( ", ", map { "td.$_" . "_right" } keys %as_box ) ;
# $css .= " {
#     padding: 0px;
#     margin: 0px;
#     text-align: left;
#     border: 0px;
# }\n" ;

# $css .= "    " . join( ", ", map { "p.$_" . "_header" } keys %as_box ) ;
# $css .= " {
#     font-weight: bold;
#     padding-top: 0px;
#     margin-top: 0px;
#     padding-left: 5px ;
# }\n" ;

# $css .= "    " . join( ", ", map {"div.$_ p"} keys %as_box ) ;
# $css .= " {
#     padding: 0px;
#     margin: 0px;
#     margin-top: 0px;
#     padding-top: 0px;
#     padding-left: 5px ;
# }\n" ;
# }

# ----------------------------------------------------------------------------
# decide which simple handler should process this request

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    state $css = 0 ;
    my $retval = undef ;

    if ( !$css ) {
        add_css($default_css) ;
        # add_css( _admonition_css() ) ;
        $css++ ;
    }

    # same same
    $tag = 'warning' if ( $tag eq 'warn' ) ;

    if ( $as_box{$tag} && $self->can('box') ) {
        $retval = $self->box( $tag, $content, $params, $cachedir ) ;

    } elsif ( $self->can($tag) ) {
        $retval = $self->$tag(@_) ;
    }
    return $retval ;
}

# ----------------------------------------------------------------------------

1 ;

