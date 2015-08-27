
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
use Text::Markdown qw(markdown) ;
use namespace::clean ;

use feature 'state' ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub {
        [   qw{yamlasjson yamlasxml table version page
                columns links tree
                box note info tip important caution warning danger todo aside
                quote
                appendix
                counter
                comment
                indent
                }
        ] ;
    }
) ;

# ----------------------------------------------------------------------------
# these things are the same as a box

my %as_box
    = map { $_ => 'box' }
    qw (note info tip important caution warning danger todo aside) ;

# ----------------------------------------------------------------------------

my $default_css = <<END_CSS;
    /* Text.pm css */

    /* zebra tables */
    tr.odd { background: white;}
    tr.even {background: whitesmoke;}

    span.glossary {
      display: inline-block;
      position: relative;
      color: green ;
    }
    span.glossary:before {
      content: "~~~~~~~~~~~~";
      font-size: 0.6em;
      font-weight: 700;
      font-family: Times New Roman, Serif;
      color: green;
      width: 100%;
      position: absolute;
      top: 12px;
      left: -1px;
      overflow: hidden;
    }
    table.glossary td.key {
      font-weight: bold;
      color: gree;
    }

    blockquote {
        font-family: helvetica;
        font-style: italic;
        font-size: 14px;
        margin: 1em 3em;
        padding: .5em 1em;
        border-left: 5px solid #666666;
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
        border-left: 5px solid #fce27c;
        border-right: 5px solid #fce27c;
        background-color: #f6ebc1;
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
        background-color: blue;
        margin-left: auto ;
        margin-right: auto ;
        width: 50%;
    }
    div.quote > p {
        text-align: center;
        font-size: 130%;
        color: white;
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
        if ( $item && $item =~ /^\d+(\.\d+)?$/ ) {
            # force numbers to be numbers
            $item += 0 ;
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
        $str
            .= "\n\n~~~~{.json wrap='72'}\n"
            . $json->encode($data)
            . "\n~~~~\n\n" ;
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
        $str .= "\n\n~~~~{.xml wrap='72'}\n$xml\n~~~~\n\n\n" ;
    }

    return $str ;
}



# ----------------------------------------------------------------------------

sub _split_csv_data
{
    my ( $data, $separator ) = @_ ;
    my @d = () ;

    $separator ||= ',' ;

    my $j = 0 ;
    foreach my $line ( split( /\n/, $data ) ) {
        last if ( !$line ) ;
        my @row = split( /$separator/, $line ) ;

        for ( my $i = 0; $i <= $#row; $i++ ) {
            undef $row[$i] if ( $row[$i] eq 'undef' ) ;

            # dont' bother with any zero values either
            # undef $row[$i] if ( $row[$i] =~ /^0\.?0?$/ ) ;
            push @{ $d[$j] }, $row[$i] ;
        }
        $j++ ;
    }

    return @d ;
}

# ----------------------------------------------------------------------------

=item table

create a basic html table

 parameters
    data   - comma separated lines of table data

    hashref params of
        class   - HTML/CSS class name
        id      - HTML/CSS class
        width   - width of the table
        style   - style the table if not doing anything else
        legends - flag to indicate that the top row is the legends
        separator - characters to be used to separate the fields
        zebra   - apply odd/even classes to table rows, default 0 OFF
        align   - option, set alignment of table
        sort - todo sort on a column number, "1", "1r"
        columns - columns to be included in the output "1,2,3,4"

=cut

sub table
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    return "" if ( !$content ) ;

    $params->{title} ||= "" ;
    $params->{class} ||= "" ;
    $content =~ s/^\n//gsm ;
    $content =~ s/\n$//gsm ;

    # open the csv file, read contents, calc max, add into data array
    my @data = _split_csv_data( $content, $params->{separator} ) ;

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

    for ( my $i = 0; $i < scalar(@data); $i++ ) {
        my @row   = @{ $data[$i] } ;
        my $class = $params->{zebra} ? ( $i & 1 ? 'odd' : 'even' ) : '' ;
        my $style = "" ;
        my $last  = pop @row ;

        # allow {.classname} as a thing on the end of the row
        if ( $last =~ s/\{\.(.*?)\}\s+$// ) {
            $class .= " $1" ;
        }
        if ( $last =~ s/#((\w+)?\.?(\w+)?)// ) {
            my ( $fg, $bg ) = ( $2, $3 ) ;
            $style .= "color: " . to_hex_color($fg) . ";" if ($fg) ;
            $style .= "background-color: " . to_hex_color($bg) . ";"
                if ($bg) ;
        }
        push @row, $last ;
        $out .= "<tr" ;
        $out .= " class='$class'" if ($class) ;
        $out .= " style='$style'" if ($style) ;
        $out .= ">" ;

        # decide if the top row has the legends
        my $tag = ( !$i && $params->{legends} ) ? 'th' : 'td' ;
        map {
            $_ ||= '&nbsp;' ;
            $out .= "<$tag>$_</$tag>" ;
        } @row ;
        $out .= "</tr>\n" ;
    }

    $out .= "</table>\n" ;

    return $out ;
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

    $out .= "<tr><th>Version</th><th>Date</th><th>Changes</th></tr>\n" ;

    # my $section = '^(.*?)\s+(\d{2,4}[-\/]\d{2}[-\/]\d{2,4})\s?$' ;
    my $section = '^([\d|v].*?)\s+(\d{2,4}[-\/]\d{2}[-\/]\d{2,4})\s?$' ;

    my @data = split( /\n/, $content ) ;
    for ( my $i = 0; $i < scalar(@data); $i++ ) {
        if ( $data[$i] =~ /$section/ ) {
            my $vers = $1 ;
            my $date = $2 ;
            $i++ ;
            my $c = "" ;

            # get all the lines in this section
            while ( $i < scalar(@data) && $data[$i] !~ /$section/ ) {
                $data[$i] =~ s/^\s{4}// ;
                $c .= "$data[$i]\n" ;
                $i++ ;
            }

            if ( !$params->{items} || int( $params->{items} ) > $item_count )
            {

                # convert any of the data with markdown
                $out
                    .= "<tr><td valign='top'>$vers</td><td valign='top'>$date</td><td valign='top'>"
                    . markdown( $c, { markdown => 1 } )
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

    $out
        .= "<div id='$idname' class='$tag $params->{class}'>\n$content\n</div>\n"
        ;

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

=cut

sub links
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    $params->{class} ||= "" ;
    my $references = "" ;
    my $ul         = "<ul class='$tag $params->{class}'>\n" ;
    my %refs       = () ;
    my %uls        = () ;

    $ul
        = "<table class='$params->{class} $tag'><tr><th>Reference</th><th>Link</th></tr>\n"
        if ( $params->{table} ) ;

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
                $uls{ lc($ref) }
                    = "<tr><td class='reference'><a href='$link'>$ref</a></td><td class='link'>$link</td></tr>\n"
                    ;
            } else {
                $uls{ lc($ref) }
                    = "<li><a href='$link'>$ref</a><ul><li>$link</li></ul></li>\n"
                    ;
            }
        }
    }

    # make them nice and sorted
    map { $ul .= $uls{$_} } sort keys %uls ;
    $ul .= "</ul>\n" if ( !$params->{table} ) ;

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
    $content = markdown( $content, { markdown => 1 } )
        ;    # do markdown in HTML elements too

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

=item box | note | info | tip | important | caution | warning | danger | todo | aside

create a box around some text, if note is used and there is no title, then 'Note'
will be added as a default

    hashref params of
        class   - HTML/CSS class name
        id      - HTML/CSS class
        width   - width of the box (default 98%)
        title   - optional title for the section
        style   - style the box if not doing anything else
        icon    - add a fontawesome or google material icon to match the tag
                - default is fontawesome name if not specific trash -> :fa:trash

=cut

my %icons = (
    note      => ':fa:bookmark:[#green]',
    info      => ':fa:info-circle:[#01579B]',
    tip       => ':fa:lightbulb-o:[ #FFA000]',
    important => ':fa:exclamation:[ #blue]',
    caution   => ':fa:minus-circle:[ #crimson]',
    warning   => ':fa:exclamation-triangle:[ #red]',
    danger    => ':fa:bomb',
    todo      => ':fa:crosshairs:[ #00695C]',
    aside     => ':fa:angle-double-right:[ #teal]',
) ;

sub box
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    #  defaults
    $params->{width} ||= '100%' ;
    $params->{class} ||= "" ;
    $params->{style} ||= "" ;
    # notes may get a default title if its missing
    $params->{title} = ucfirst($tag)
        if ( !defined $params->{title} && $tag ne 'box' ) ;
    my $out ;

    $params->{class} = "$tag $params->{class}" ;

    my $icon ;
    $params->{style} = "width:$params->{width};$params->{style}" ;
    # boxes cannot have icons
    if ( $tag ne 'box' && $params->{icon} ) {
        # we can over-ride the icon with a string
        $icon
            = $params->{icon} eq "1"
            ? ( $icons{$tag} || "" )
            : $params->{icon} ;
        # allow icon flame hourglass etc, we will fix it up right
        # the default is fontaweome if there is no specific
        if ( $icon !~ /^:[fm]a:/ ) {
            $icon = ":fa:$icon" ;
        }
        if ( $icon !~ /:\[.*?\]/ ) {
            $icon .= ':[]' ;
        }
        # icons need to be at least 2x size to look good here
        if ( $icon !~ /\[(.*?\blg\b|.*?\b\[2345]x\b).*?\]/ ) {
            $icon =~ s/\]/ 2x]/ ;
        }
        # make them fixed width too
        if ( $icon !~ /\[.*?\bfw\b.*?\]/ ) {
            $icon =~ s/\]/ fw]/ ;
        }

        $out .= "<div class='$params->{class}' style='$params->{style}' " ;
        $out .= "id='$params->{id}' " if ( $params->{id} ) ;
        $out .= ">" ;
        $out
            .= "<table width='100%' class='$params->{class}'><tr>"
            . "<td class='$tag"
            . "_left'>$icon</td>\n"
            . "<td class='$tag"
            . "_right'>" ;
    } else {
        $out .= "<div style='$params->{style}' " ;
        $out .= "class='$params->{class}' " if ( !$icon ) ;
        $out .= "id='$params->{id}' " if ( $params->{id} ) ;
        $out .= ">" ;
    }
    $out .= "<p class='$tag" . "_header'>$params->{title}</p>\n"
        if ( $params->{title} ) ;

    # convert any content to HTML from Markdown
    $out .= markdown( $content, { markdown => 1 } ) ;
    if ($icon) {
        $out .= "</td></tr></table></div>\n" if ($icon) ;
    } else {
        $out .= "</div>\n" ;
    }

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
    # lets keep any line spacing
    $content =~ s/\n\n/<br><br>/gsm ;
    $out .= markdown( $content, { markdown => 1 } ) ;

    $out .= "</blockquote></div><br/>\n" ;
    return $out ;
}

# ----------------------------------------------------------------------------

=item appendix

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
        $str
            = "Appendix "
            . chr( 65 + int( $count / 26 ) )
            . chr( 65 + $count % 26 ) ;
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

indent each line of the content by 4 spaces
 
=cut

sub indent
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    $content =~ s/^/    /gsm;

    return $content ;
}

# ----------------------------------------------------------------------------
# build the css for the different box types
sub _admonition_css
{
    my $css = "    /* style for boxes/notes */\n" ;

    $css .= "    " . join( ", ", map {"div.$_ "} keys %as_box ) ;
    $css .= " {
        margin-bottom: 1em;
    }\n" ;

    $css .= "    " . join( ", ", map {"table.$_ "} keys %as_box ) ;
    $css .= " {
        padding: 0px;
        margin: 0px;
        text-align: left;
        border-collapse: collapse;
    }\n" ;

    $css .= "    " . join( ", ", map { "td.$_" . "_left" } keys %as_box ) ;
    $css .= " {
        padding: 0px;
        margin: 0px;
        text-align: center;
        vertical-align: middle;
        width:4%;
        border: 0px;
        border-right: 1px solid black ;
    }\n" ;

    $css .= "    " . join( ", ", map { "td.$_" . "_right" } keys %as_box ) ;
    $css .= " {
        padding: 0px;
        margin: 0px;
        text-align: left;
        border: 0px;
    }\n" ;

    $css .= "    " . join( ", ", map { "p.$_" . "_header" } keys %as_box ) ;
    $css .= " {
        font-weight: bold;
        padding-top: 0px;
        margin-top: 0px;
        padding-left: 5px ;
    }\n" ;

    $css .= "    " . join( ", ", map {"div.$_ p"} keys %as_box ) ;
    $css .= " {
        padding: 0px;
        margin: 0px;
        margin-top: 0px;
        padding-top: 0px;
        padding-left: 5px ;
    }\n" ;
}

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
        add_css( _admonition_css() ) ;
        $css++ ;
    }

    if ( $as_box{$tag} && $self->can('box') ) {
        $retval = $self->box(@_) ;

    } elsif ( $self->can($tag) ) {
        $retval = $self->$tag(@_) ;
    }
    return $retval ;
}

# ----------------------------------------------------------------------------

1 ;

