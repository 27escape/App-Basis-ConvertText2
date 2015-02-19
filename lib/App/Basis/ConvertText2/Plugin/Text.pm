
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
    default  => sub { [qw{yamlasjson yamlasxml table version page columns links tree box note}] }
) ;


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
    } elsif ( ref( $item) eq '' || ref($item) eq 'SCALAR') {
        if ( $item =~ /^\d+(\.\d+)?$/ ) {
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
    my $str = "" ;
    if( $data) {
        $data = _make_numbers( $data) ;
        my $json = JSON::MaybeXS->new( utf8 => 1, pretty => 1 ) ;
        $str .= "\n\n~~~~{.json wrap='72'}\n" . $json->encode($data) . "\n~~~~\n\n" ;
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
    my $str = "" ;
    if( $data) {
        $data = _make_numbers( $data) ;
        my $xml = XMLout( $data, RootName => "", NoAttr=> 1) ;
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
            undef $row[$i] if ( $row[$i] =~ /^0\.?0?$/ ) ;
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

=cut

sub table
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    $params->{title} ||= "" ;

    $content =~ s/^\n//gsm ;
    $content =~ s/\n$//gsm ;

    # open the csv file, read contents, calc max, add into data array
    my @data = _split_csv_data( $content, $params->{separator} ) ;

    my $out = "<table " ;
    $out .= "class='$params->{class}' " if ( $params->{class} ) ;
    $out .= "id='$params->{id}' "       if ( $params->{id} ) ;
    $out .= "width='$params->{width}' " if ( $params->{width} ) ;
    $out .= "class='$params->{style}' " if ( $params->{style} ) ;
    $out .= ">\n" ;

    for ( my $i = 0; $i < scalar(@data); $i++ ) {
        $out .= "<tr>" ;

        # decide if the top row has the legends
        my $tag = ( !$i && $params->{legends} ) ? 'th' : 'td' ;
        map { $out .= "<$tag>$_</$tag>" ; } @{ $data[$i] } ;
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

=cut

sub version
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    $params->{title} ||= 'Document Revision History' ;

    $content =~ s/^\n//gsm ;
    $content =~ s/\n$//gsm ;

    $params->{class} ||= "version" ;

    my $out = "<h2 class='toc_skip'>$params->{title}</h2>
<table " ;
    $out .= "class='$params->{class}' " if ( $params->{class} ) ;
    $out .= "id='$params->{id}' "       if ( $params->{id} ) ;
    $out .= "width='$params->{width}' " if ( $params->{width} ) ;
    $out .= "class='$params->{style}' " if ( $params->{style} ) ;
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

            # convert any of the data with markdown
            $out
                .= "<tr><td valign='top'>$vers</td><td valign='top'>$date</td><td valign='top'>"
                . markdown($c)
                . "</td></tr>\n" ;

 # adjust $i back so we are either at the end correctly or on the next section
            $i-- ;
        }
    }

    $out .= "</table>\n" ;
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
        $idname = "text_column_id$style_count" ;

        # add in the webkit and mozilla styling for completeness
        # just in case someones browser is not up to date and we are
        # creating html only
        $out = "<style type=\"text/css\">
    .$idname {
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
    }
</style>\n" ;

        $style->{$sig} = { style => $out, name => $idname } ;
    } else {
        $idname = $style->{$sig}->{name} ;
    }

    $out .= "<div class='$idname'>\n$content\n</div>\n" ;

    return $out ;
}

# ----------------------------------------------------------------------------

=item ~~~~{.links }

create a list of website links
links are one per line and the link name is separated from the link with a
pipe '|' symbol

 parameters
    class   - name of class for the list, defaults to weblinks
    table   - create a table rather than a list

=cut

sub links
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    # strip any ending linefeed
    chomp $content ;
    return "" if ( !$content ) ;

    $params->{class} ||= "weblinks" ;
    my $references = "" ;
    my $ul         = "<ul class='$params->{class}'>\n" ;
    my %refs       = () ;
    my %uls        = () ;

    $ul = "<table class='$params->{class}'><tr><th>Reference</th><th>Link</th></tr>\n" if( $params->{table}) ;

    foreach my $line ( split( /\n/, $content ) ) {
        my ( $ref, $link ) = split( /\|/, $line ) ;
        next if ( !$link ) ;

        # trim the items
        $ref  =~ s/^\s+// ;
        $link =~ s/^\s+// ;
        $ref  =~ s/\s+$// ;
        $link =~ s/\s+$// ;

        # if there is nothing to link to ignore this
        next if ( !$ref || !$link ) ;

        $references .= "[$ref]: $link\n" ;

        # links that reference inside the document do not get added to the
        # list of weblinks
        if ( $link !~ /^#/ ) {
            if( $params->{table}) {
                $uls{ lc($ref) } = "<tr><td class='reference'><a href='$link'>$ref</a></td><td class='link'>$link</td></tr>\n" ;
            } else {
                $uls{ lc($ref) } = "<li><a href='$link'>$ref</a><ul><li>$link</li></ul></li>\n" ;
                }
        }
    }

    # make them nice and sorted
    map { $ul .= $uls{$_} } sort keys %uls ;
    $ul .= "</ul>\n" if( !$params->{table});

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
    color   - the foreground color of the tree items, default black

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
    my $class ;

    $params->{color} ||= 'black' ;

    if ( !$style->{ $params->{color} } ) {
        $class = "tree$style_count" ;
        $style_count++ ;

        # taken from http://odyniec.net/articles/turning-lists-into-trees/
        $out .= "<style type=\"text/css\">
ul.$class, ul.$class ul {
    list-style-type: none;
    /* vline.png */
    background: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAKAQMAAABPHKYJAAAAA1BMVEWIiIhYZW6zAAAACXBIWXMA
AAsTAAALEwEAmpwYAAAAB3RJTUUH1ggGExMZBky19AAAAAtJREFUCNdjYMAEAAAUAAHlhrBKAAAA
AElFTkSuQmCC
) repeat-y;
    margin: 0;
    padding: 0;
}

ul.$class ul {
    margin-left: 10px;
}

ul.$class li {
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

ul.$class li.last {
    /*lastnode.png*/
 background: #fff url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAUAQMAAACK1e4oAAAABlBMVEUAAwCIiIgd2JB2AAAAAXRS
TlMAQObYZgAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB9YIBhQIIhs+gc8AAAAQSURBVAjX
Y2hgQIf/GbAAAKCTBYBUjWvCAAAAAElFTkSuQmCC
) no-repeat;
}
</style>\n" ;
        $style->{ $params->{color} } = {
            class => $class,
            style => $out
        } ;
    } else {
        $class = $style->{ $params->{color} }->{color} ;
    }

    # we need to convert the bullet list into a HTML one
    $content = markdown($content) ;

    # make sure the first ul has class tree
    $content =~ s/<ul>/<ul class='$class'>/ ;

    # last nodes before the end of list need marking up

    # <ul class='tree1'>
    #     <li>one
    #         <ul>
    #             <li>1.1</li>
    #         </ul>
    #     </li>
    #     <li>two
    #         <ul>
    #             <li>two point 1</li>
    #             <li>2.2</li>
    #         </ul>
    #     </li>
    #     <li>three
    #         <ul>
    #             <li>3.1</li>
    #             <li>3.2</li>
    #             <li>three point 3
    #                 <ul>
    #                     <li>four
    #                         <ul>
    #                             <li>five</li>
    #                         </ul>
    #                     </li>
    #                     <li>six</li>
    #                 </ul>
    #             </li>
    #             <li>3 . seven</li>
    #         </ul>
    #     </li>
    # </ul>

    # $content =~ s|<li>(.*?</li>\s*</ul>)|<li class='last'>$1|gsm;

    my @lines = split( /\n/, $content ) ;
    for ( my $i = 0; $i < scalar(@lines); $i++ ) {
        if ( $lines[$i] =~ /<li>/ && $lines[ $i + 1 ] =~ /<\/ul>/ ) {
            $lines[$i] =~ s/<li>/<li class='last'>/ ;
        }
        $out .= "$lines[$i]\n" ;
    }

    # $out .= "$content\n";

    # say STDERR $out;

    return "$out<br>" ;
}


# ----------------------------------------------------------------------------

=item box | note

create a box around some text, if note is used and there is no title, then 'Note'
will be added as a default

    hashref params of
        class   - HTML/CSS class name
        id      - HTML/CSS class
        width   - width of the box (default 98%)
        title   - optional title for the section
        style   - style the box if not doing anything else

=cut

sub box
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    #  defaults
    $params->{width} ||= '98%' ;
    $params->{class} ||= "box" ;
    # notes may get a default title if its missing
    $params->{title} = 'Note' if( $tag eq 'note' && ! defined $params->{title}) ;

    my $out = "<div " ;
    $out .= "class='$params->{class}' " if ( $params->{class} ) ;
    $out .= "id='$params->{id}' "       if ( $params->{id} ) ;
    $out .= "width='$params->{width}' " if ( $params->{width} ) ;
    $out .= "class='$params->{style}' " if ( $params->{style} ) ;
    $out .= ">\n" ;
    $out .= "<p class='box_header'>$params->{title}</p>" if( $params->{title}) ;

    # convert any content to HTML from Markdown
    $out .= markdown($content) ;
    $out .= "</div><br/>\n" ;
    return $out ;
}

sub note
{
    my $self = shift ;
    return $self->box( @_)
}

# ----------------------------------------------------------------------------
# decide which simple handler should process this request

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    if ( $self->can($tag) ) {
        return $self->$tag(@_) ;
    }
    return undef ;
}

# ----------------------------------------------------------------------------

1 ;

