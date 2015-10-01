title: Using App::Basis::ConvertText2
format: pdf
date: 2015-08-05
author: Kevin Mulholland
keywords: perl, readme, markdown
template: coverpage
version: 8

## Introduction

If you are reading this document as a markdown document you may want to try [README PDF] as an alternative.
This have been generated from this file and the software provided by this distribution.

This is a perl module and a script that makes use of %TITLE%

This is a wrapper for [pandoc] implementing extra fenced code-blocks to allow the creation of charts and graphs etc.
Documents may be created a variety of formats. If you want to create nice PDFs
then it can use [PrinceXML] to generate great looking PDFs or you can use [wkhtmltopdf] to create PDFs that are almost as good, the default is to use pandoc which, for me, does not work as well.

HTML templates can also be used to control the layout of your documents.

The fenced code block handlers are implemented as plugins and it is a simple process to add new ones.

There are plugins to handle

* ditaa
* mscgen
* graphviz
* uml
* gnuplot
* gle
* sparklines
* charts
* barcodes and qrcodes
* and many, many others

As a perl module you can obtain it from https://metacpan.org/pod/App::Basis::ConvertText2
or install

    cpanm App::Basis::ConvertText2

Alternatively it is available from https://github.com/27escape/App-Basis-ConvertText2

You will then be able to use the [ct2](#using-ct2-script-to-process-files) script to process files

If you are reading this document in PDF form, then note that all the images are created by the various plugins and included in the output, there is no store of pre-built images. That you can read this proves the plugins all work!

Most of the chapters are based around the various plugins that are available and the commands that they expose.

## Document header and variables

If you are just creating simple things, then you do not need a document header, but to make full use of the templating system, having header information is vital.

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>
    title: App::Basis::ConvertText2
    format: pdf
    date: 2014-05-12
    author: Kevin Mulholland
    keywords: perl, readme
    template: coverpage
    version: 5
</td></tr></table>

As you can see, we use a series of key value pairs separated with a colon. The keys may be anything you like, except for the following which have special significance.

* *format* shows what output format we should default to.
* *template* shows which template we should use

The keys may be used as variables in your document or in the template, by upper-casing and prefixing and postfixing percent symbols '%'

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>
    version as a variable _%VERSION%
</td></tr></table>

If you want to display the name of a variable without it being interpreted, prefix it
with an underscore '_', this underscore will be removed in the final document.

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr><td>
    _%TITLE%
</td>
<td><br>
%TITLE%
</td></tr></table>

### Gotchas about variables

* Variables used within the content area of a code-block will be evaluated before processing that block, if a variable has not yet been defined or saved to a buffer then it will only be evaluated at the end of document processing, so output may not be as expected.
* Variables used in markdown tables may not do what you expect if the variable is multi-line.

## Table of contents

As documents are processed, the HTML headers (H2..H6) are collected together to make a table of contents. This can be used either in your template or document using the TOC variable.

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>
    _%TOdC%
</td></tr></table>

The built table of contents is at the top of this document.

Note that if using a TOC, then the HTML headers are changed to have a number prefixed to them, this helps ensure that all the TOC references are unique.

### Skipping header {.toc_skip}

If you do not want an item added to the toc add the class 'toc_skip' to the header (or skiptoc)

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>
    ### Skipping header {.toc_skip}
</td></tr></table>

Hopefully you can see that the header for this section is not in the TOC

~~~~{.note}
This feature is disabled at the moment while bugs are fixed.
~~~~

## Admonitions

There are certain statements that you may want to draw attention to by taking them out of the content’s flow and labeling them with a priority. These are called admonitions. It’s rendered style is determined by the assigned label (i.e., value). We provide nine admonition style labels:

* NOTE
* INFO
* TIP
* IMPORTANT
* CAUTION
* WARNING
* DANGER
* TODO
* ASIDE

When you want to call attention to a single paragraph, start the first line of the paragraph with the label you want to use. The label must be uppercase and followed by a colon ':'

    WARNING: Something could go wrong if you do not follow the rules

* The label must be uppercase and immediately followed by a colon ':'
* Separate the first line of the paragraph from the label by a single space.

And here is the generated Admonition

WARNING: Something could go wrong if you do not follow the rules

All the Admonitions have associated icons.

Normal Markup may be used in the paragraph.

Admonitions are processed before the rest of the document, so you cannot put their contents into buffers and expect them to work correctly.

Admonitions are a short cut to [Admonition Boxes](#admonition-boxes) which allow multiple paragraphs to be used.

## Font Awesome

Font Awesome provides many useful icons,see [Font Awesome Cheatsheet], however there is a lot of hassle to add them to your document; we of course offer a simple shortcut, with the form

    \:fa:font-name

E.g.

    \:fa:trash

Will display a :fa:trash icon.

NOTE: We do not use the preceding 'fa-' in the name as Font Awesome does.

So 'trash' rather than 'fa-trash'.

It is possible to scale the images, give them colors and apply CSS classes to them by adding this information in square brackets

E.g.

    \:fa:trash:[2x]

The options are

* size [lg], [2x], [3x], [4x], [5x]
    * :fa:trash:[lg] :fa:trash:[2x], :fa:trash:[3x], :fa:trash:[4x], :fa:trash:[5x].
* foreground color [#red]
    * :fa:trash:[2x #red]
* foreground and background color [#yellow.black]
    * :fa:trash:[2x #yellow.black]
* rotate [90], [180], [270]
    * :fa:flask:[2x 90], :fa:flask:[2x 180], :fa:flask:[2x 270]
* flip vertical [flipv]
    * :fa:flask:[2x] vs :fa:flask:[2x flipv]
* flip horizontal [fliph]
    * :fa:graduation-cap:[2x] vs :fa:graduation-cap:[2x fliph]
* fixed width [fw]
    * :fa:gamepad:[2x]. vs :fa:gamepad:[2x fw].
    * note the normal font (left) has a smaller space before the '.' than the fixed width font (right)
* border [border]
    * :fa:gear:[ border]

Any thing remaining in the square brackets after handling the above options will be considered as a class to be applied to the icon.

Of course multiple options may be combined

    \:fa:trash:[2x 90 #red border]

as :fa:trash:[2x 90 #red border]

## Google Material Icons

Google also provides many useful icons,see [Google Material Font Cheatsheet], however there is a lot of hassle to add them to your document; we of course offer a simple shortcut, with the form

    \:mi:font-name

E.g.

    \:mi:add-shopping-cart

Will display a :mi:add-shopping-cart icon.

NOTE: Google Material fonts do not usually have a '-' in them, we use this to allow us to know where the font name ends. It is removed.

It is possible to scale the images, give them colors and apply CSS classes to them by adding this information in square brackets

E.g.

    \:mi:alarm:[2x]

The options are

* size [lg] [2x], [3x], [4x], [5x]
    * :mi:alarm:[lg] :mi:alarm:[2x], :mi:alarm:[3x], :mi:alarm:[4x], :mi:alarm:[5x]
* rotate [90], [180], [270]
    * :mi:book:[2x 90], :mi:book:[2x 180], :mi:book:[2x 270 ]
* flip vertical [flipv]
    * :mi:build:[2x] vs :mi:build:[2x flipv]
* flip horizontal [fliph]
    * :mi:add-shopping-cart:[2x] vs :mi:add-shopping-cart:[2x fliph]
* foreground color [#orangea700]
    * :mi:book:[2x #orangea700]
* foreground and background color [#yellow.black]
    * :mi:book:[2x #yellow.black]

Any thing remaining in the square brackets after handling the above options will be considered as a class to be applied to the icon.

Of course multiple options may be combined

    \:mi:delete:[2x 90 #red border-inset-grey]

as :mi:delete:[2x 90 #red border-inset-grey]

~~~~{.tip icon=1 title='Google Material Colors'}

All of the google material colors are available to be used both in css and style sections.

Orange with an accent of A700, is named as orangea700. Light blue 500 is lightblue500.

Anywhere in your document/css that uses color= or color: then these replacements can be made.

For the complete list of colors see [Google Colors]
~~~~

## Including other files

It is possible to include content from other files, the methods match fenced code-block and their short cuts.

The optional arguments are

* class
    * add a div with this CSS class name
* style
    * add a div with this CSS style
* markdown
    - import file is markdown and will need some tidying up
* headings
    - if a markdown file, add this nunber of '#' characters to headers in the imported file
* date
    - add the date the import file was updated to the end of the imported text

**import** can also be used as a synonym for include.

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    \{\{.include file="filename"}}

    ~~~~{.include file='filename'}
    ~~~~

</td>
</tr>
</table>

Either of these methods will bring the contents of the file inline to the current document at the location where they are used.

## Font effects

Markdown does not include any facility for setting the maniulating the font of text in a document, however sometimes it is useful to be able to do some basic manipulation.

We have a HTML-like constructs

* For Colors
    * &lt;c\:colorname&gt; Your text &lt;/c&gt;
    * &lt;c\:#foreground.background&gt; Your text &lt;/c&gt;
* For Underline - standard HTML
    * &lt;u&gt; Your text &lt;/u&gt;
* For Strikethroughs - standard HTML
    * &lt;s&gt; Your text &lt;/s&gt;

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    <c\:red>set this string to red</c>

    <c\:#white.blue>White foreground,
      blue background</c>

    <c\:#.green300>green300 background</c>
</td>
<td>

<c:red>set this string to red</c>

<c:#white.blue>White foreground, blue background</c>

<c:#.green300>green300 background</c>

</td></tr></table>

## Fenced code-blocks

A fenced code-block is a way of showing that some text needs to be handled differently. Often this is used to allow markdown systems (and [pandoc] is no exception) to highlight program code.

code-blocks take the form

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.tag argument1='fred' arg2=3}
    contents ...
    ~~~~
</td>
</tr>
</table>

Code-blocks **ALWAYS** start at the start of a line without any preceding whitespace.
The 'top' line of the code-block can wrap onto subsequent lines, this line is considered complete when the final '}' is seen. There should be only whitespace after the closing '}' symbol before the next line.

We use this construct to create our own handlers to generate HTML or markdown.

Note that only code-blocks described in this documentation have special handlers and
can make use of extra features such as buffering.

If using [pandoc] then you can take advantage of the code blocks for code syntax highlighting

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.perl}
    sub process
    {
        my $self = shift ;
        my ( $tag, $content, $params, $cachedir ) = @_ ;

        # make sure we have no tabs
        $content =~ s/\t/    /gsm ;
        $content = "ditaa\n$content" ;

        # and process with the normal uml command
        $params->{png} = 1 ;
        return run_block( 'uml', $content, $params, $cachedir ) ;
    }
    ~~~~
</td>
</tr>
<tr><th>Output</th></tr>
<tr><td>
~~~~{.perl}
sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    # make sure we have no tabs
    $content =~ s/\t/    /gsm ;
    $content = "ditaa\n$content" ;

    # and process with the normal uml command
    $params->{png} = 1 ;
    return run_block( 'uml', $content, $params, $cachedir ) ;
}
~~~~
</table>

#### External content

Its is possible to bring in content from another file by using the *file* attribute.

    ~~~~{.table file="/tmp/data.csv"}
    ~~~~

This is also valid when using short cuts

    \{\{.table file="/tmp/data.csv"}}

### Code-block short cuts

Sometimes using a fenced code-block is overkill, especially if the command to be executed does not have any content. So there is a shortcut to this. Additionally this will allow you to use multiple commands on a single line, this may be important in some instances.

Finally note that the shortcut must completely reside on a single line, it cannot span onto a separate next line, the parser will ignore it!

We wrap the command and its arguments with double braces.

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>
    \{\{.tag argument1='fred' arg2=3}}
</td></tr></table>

Its is possible to add content that would normally be within the fenced code-block, if there is not too much information, by adding it to a *content* attribute.

We can see this in action below and in the barcode examples later on.

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>
    \{\{.tag argument1='fred' arg2=3 content='some text'}}
</td></tr></table>

## Buffers

Sometimes you may either want to repeatedly use the same information or may want to use the output from one of the fenced code-blocks .

To store data we use the **to_buffer** argument to any code-block.

~~~~{.buffer to_buffer='spark_data'}
1,4,5,20,4,5,3,1
~~~~

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.buffer to_buffer='spark_data'}
    1,4,5,20,4,5,3,1
    ~~~~
</td></tr></table>

If the code-block would normally produce some output that we do not want displayed at the current location then we would need to use the **no_output** argument.

~~~~{.sparkline title='green sparkline' scheme='green'
    from_buffer='spark_data' to_buffer='greenspark' no_output=1}
~~~~

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.sparkline title='green sparkline' scheme='green'
        from_buffer='spark_data' to_buffer='greenspark' no_output=1}
    ~~~~
</td></tr></table>

We can also have the content of a code-block replaced with content from a buffer by using the **from_buffer** argument. This is also displayed in the example above.

To use the contents (or output of a buffered code-block) we wrap the name of the buffer
once again with percent '%' symbols, once again we force upper case.

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    _%SPARK_DATA% has content %SPARK_DATA%
    _%GREENSPARK% has a generated image %GREENSPARK%
</td></tr></table>

Buffering also allows us to add content into markdown constructs like bullets.

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    * _%SPARK_DATA%
    * _%GREENSPARK%
</td><td>
* %SPARK_DATA%
* %GREENSPARK%
</td></tr></table>

## Text

The text plugin has lots of simple handlers, they all output text/HTML.

### Yamlasjson

Software engineers often use [JSON] to transfer data between systems, this often is not nice to create for documentation. [YAML] which is a superset of [JSON] is much cleaner
so we have a

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.yamlasjson }
    list:
      - array: [1,2,3,7]
        channel: BBC3
        date: 2013-10-20
        time: 20:30
      - array: [1,2,3,9]
        channel: BBC4
        date: 2013-11-20
        time: 21:00
    ~~~~
</td>
<td>
~~~~{.yamlasjson }
list:
  - array: [1,2,3,7]
    channel: BBC3
    date: 2013-10-20
    time: 20:30
  - array: [1,2,3,9]
    channel: BBC4
    date: 2013-11-20
    time: 21:00
~~~~
</td></tr></table>

### Yamlasxml

Software engineers often use [XML] to transfer data between systems, this often is not nice to create for documentation. We cam create basic XML, we do not allow element attributes. If you want real XML layout use *.xml* in a fenced code block.

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.yamlasxml }
    list:
      - array: [1,2,3,7]
        channel: BBC3
        date: 2013-10-20
        time: 20:30
      - array: [1,2,3,9]
        channel: BBC4
        date: 2013-11-20
        time: 21:00
    ~~~~
</td><td>
~~~~{.yamlasxml }
list:
  - array: [1,2,3,7]
    channel: BBC3
    date: 2013-10-20
    time: 20:30
  - array: [1,2,3,9]
    channel: BBC4
    date: 2013-11-20
    time: 21:00
~~~~
</td></tr></table>

### Table

Create a simple table using CSV style data

* class
    * HTML/CSS class name
* id
    * HTML/CSS class
* width
    * width of the table
* style
    * style the table if not doing anything else
* legends
    * if true first line csv as headings for table, these correspond to the data sets
* separator
    * what should be used to separate cells, defaults to ','
* align
    - align the table, left, middle/center (default), right
* sort
    - column number to sort on, append 'r' to reverse the sort

~~~~{.buffer to_buffer=table_data}
Date,Item,Cost
2012-06-25, Tree, 23.99
2015-04-20, Shed, 400.00
2010-03-02, Lawn mower, 69.95
2014-12-12, Gnome, 7.95
~~~~

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.table separator=',' width='100%' legends=1}
    %TABLE_DATA%
    ~~~~

    The table can be sorted too, reverse date (newest first)

    ~~~~{.table separator=',' width='100%' legends=1 sort='0r'}
    %TABLE_DATA%
    ~~~~

</td></tr>
<tr><th>Output</th></tr>
<tr><td>


~~~~{.table separator=',' width='100%' legends=1 from_buffer='table_data'}
~~~~

The table can be sorted too, reverse date (newest first)

~~~~{.table separator=',' width='100%' legends=1 from_buffer='table_data' sort='0r'}
~~~~

</td></tr></table>

### Links

With one code-block we can create a list of links

The code-block contents comprises a number of lines with a reference and a URL.
The reference comes first, then a '|' to separate it from the URL.

The reference may then be used elsewhere in your document if you enclose it with square ([]) brackets

There is only one argument

* class
    * CSS class to style the list

These links used in this example are the ones used in this document.

~~~~{.buffer to_buffer=weblinks}
pandoc      | http://johnmacfarlane.net/pandoc
PrinceXML   | http://www.princexml.com
markdown    | http://daringfireball.net/projects/markdown
msc         | http://www.mcternan.me.uk/mscgen/
ditaa       | http://ditaa.sourceforge.net
PlantUML    | http://plantuml.sourceforge.net
Salt        | http://plantuml.sourceforge.net/salt.html
graphviz    | http://graphviz.org
JSON        | https://en.wikipedia.org/wiki/Json
YAML        | https://en.wikipedia.org/wiki/Yaml
wkhtmltopdf | http://wkhtmltopdf.org/
My Github   | https://github.com/27escape/App-Basis-ConvertText2/tree/master/scripts
Brewer      | http://www.graphviz.org/content/color-names#brewer
README PDF  | https://github.com/27escape/App-Basis-ConvertText2/blob/master/docs/README.pdf
Font Awesome Cheatsheet | http://fontawesome.io/cheatsheet/
Google Material Font Cheatsheet | https://www.google.com/design/icons/
Google Colors | http://www.google.com/design/spec/style/color.html#color-color-palette
~~~~

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.links class='weblinks' }
    %WEBLINKS%
    ~~~~
</td></tr>
<tr><th>Output</th></tr>
<tr><td>
~~~~{.links class='weblinks' from_buffer=weblinks}
~~~~
</td></tr></table>

### Version

Documents often need revision history. I use this code-block to create a nice
version table of this history.

The content for this code-block comprises a number of sections, each section then makes a row in the generated table.

    version YYYY-MM-DD
       indented change text
       more changes

The version may be any string, YYYY-MM-DD shows the date the change took place.
Alternate date formats is DD-MM-YYYY and '/' may also be used as a field separator.

So give proper formatting to the content in the changes column you should indent
text after the version/date line with 4 spaces, not a tab character.

* class
    * HTML/CSS class name
* id
    * HTML/CSS class
* width
    * width of the table
* style
    * style the table if not doing anything else
- title
    * create a title for the version table

~~~~{.buffer to_buffer=versiontable}
0.1 2014-04-12
  * removed ConvertFile.pm
  * using Path::Tiny
0.006 2014-04-10
  * first release to github
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.version}
    %VERSIONTABLE%
    ~~~~
</td>
<td>
~~~~{.version  width='45%' from_buffer=versiontable}
~~~~
</td>
</tr>
</table>

### Page

There are 2 ways for force the start of a new page, using the **.page** fenced code block or by having 4 '-' signs next to each other, i.e. '----' on a line on their own

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>
  This is start a new page, again using short block form.

    \{\{.page}}

    as will this

    ----
</td></tr>
<tr><th>Output</th></tr>
<tr><td> will not be shown as it will mess up the document!
</td></tr></table>

### Columns

Create a columner layout, like a newspaper. The full text in the content is split into columns, the height of the section is determined by the volume of the text.

The optional arguments are

* count
    * number of columns to split into, defaults to 2
* lines
    * number of lines the section should hold, defaults to 20
* ruler
    * show a line between the columns, defaults to no,
      options are 1, true or yes to show it
* width
    * how wide should the column area be, defaults to 100%

~~~~{.buffer to_buffer=columns}
Flexitarian lo-fi occupy, Echo Park yr chia keffiyeh iPhone pug kale chips
fashion axe PBR&amp;B 90's readymade beard.

McSweeney's Tumblr semiotics
beard, flexitarian artisan bitters twee small batch next level PBR mustache
post-ironic stumptown.

Umami Pinterest mixtape Truffaut, Blue Bottle ugh
artisan whatever blog street art Odd Future crucifix tomato shore invisible
spelling.
~~~~

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.columns count=3 ruler=yes width='95%'}
    %COLUMNS%
    ~~~~
</td>
</tr>
<tr><th width='100%'>Output</th></tr>
<tr><td>
~~~~{.columns from_buffer=columns count=3 ruler=yes width='95%'}
~~~~
</td>
</tr>
</table>

### Appendix

This should generally be used as a short block as an easy way to increment appendix values in headings.

Appendicies will be created as 'Appendix A', 'Appendix B' etc

<table class='box' width='99%'>
<tr><th width='50%'>Example</th><th>Output</th></tr>
<tr>
<td>

    * \{\{.appendix}}
    * \{\{.appendix}}
    * \{\{.appendix}}

</td>
<td>
* {{.appendix}}
* {{.appendix}}
* {{.appendix}}
</td>
</tr>
</table>

### Counter

This should generally be used as a short block as an easy way to increment counter values, e.g. in headings

The optional arguments are

* name
    - the name of the counter to increment, otherwise 'default' will be used
* start
    - start the counter from this number, defaults to '1'

<table class='box' width='99%'>
<tr><th width='50%'>Example</th><th>Output</th></tr>
<tr>
<td>

    * \{\{.counter name=fred}}
    * \{\{.counter name=fred}}
    * default \{\{.counter}}
    * \{\{.counter name=martha start=100}}
    * \{\{.counter name=martha}}

</td>
<td>
* {{.counter name=fred}}
* {{.counter name=fred}}
* default {{.counter}}
* {{.counter name=martha start=100}}
* {{.counter name=martha}}
</td>
</tr>
</table>

### Comment

If its useful to comment your software, likely you will also find it useful to comment your documents. Having a comment construct allows sections to be removed/hidden too.

<table class='box' width='99%'>
<tr><th width='50%'>Example</th><th>Output</th></tr>
<tr>
<td>

    Normal flow of text

    ~~~~\{.comment}
    This comment is not seen in the generated document
    ~~~~

    text continues

</td>
<td>
Normal flow of text

~~~~{{.comment}
This comment is not seen in the generated document
~~~~

text continues
</td>
</tr>
</table>

### Indent

Import a file and indent it 4 spaces. This is useful if you want to pull code or config files etc into your document to explain them.

The optional arguments are

* class
    * add a div with this CSS class name
* style
    * add a div with this CSS style

<table class='box' width='99%'>
<tr><th width='50%'>Example</th></tr>
<tr>
<td>

    Here is the example config file
    \{\{.indent file=fred.conf style='background-color:grey50;'}}

    text continues

</td>
</tr>
</table>



### Tree

Draw a bulleted list as a directory tree. Bullets are expected to be indented
by 4 spaces, we will only process bullets that are * +  or -.

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

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
            * four
                * five
            * six
        * 3 . seven
    ~~~~
</td>
<td><br>
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
        * four
            * five
        * six
    * 3 . seven
~~~~
</td></tr></table>

### Badges

Badges (or shields) are a way to display information, often used to show status of an operation on websites such as github.

Examples of shields can be seen at [sheilds.io](http://shields.io/)

The badges are placed inline, so you can insert text around the fenced codeblock.

Depending on your template the color of the text and the color for the status portion may clash, so take care!

The required argument are

* subject
    + text saying what the badge is
* status
    + text status to put at the end of the badge

The optional arguments are

* color
    + over ride the default color 'goldenrod'
    + can use #foreground.bgbackground format, ie #blue.yellow, or #ffffff.blue
* size
    + the size of the badge
* reverse
    - swap the colors around

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>A basic badge

    ~~~~{.badge subject='test run' status='completed' color='green'}
    ~~~~

Badges / shields work well as short blocks

    \{\{.shield subject='test run' status='pending' size='150'}}

Swap the subject and status around

    \{\{.shield subject='test run' status='pending' size='150' color='orange'
     reverse=1}}

Fully specify the colors

    \{\{.shield subject='test run' status='failed' size='150'
    color='#white.red' }}

</td></tr>
<tr><th>Output</th></tr>
<tr><td>
{{.badge subject='test run' status='completed' color='green'}}

Badges / shields work well as short blocks

{{.shield subject='test run' status='pending' size='150'}}

Swap the subject and status around

{{.shield subject='test run' status='pending' size='150' color='orange' reverse=1}}

Fully specify the colors

{{.shield subject='test run' status='failed' size='150' color='#white.red' }}

</td></tr></table>

### Buttons

Buttons are like badges but with no status, just a simple styled item.

The buttons are placed inline, so you can insert text around the fenced codeblock.

The required argument are

* subject
    + text saying what the button is

The optional arguments are

* color
    + over ride the default background color 'purple300'
    + can use #foreground.bgbackground format, ie #blue.yellow, or #ffffff.blue
    + without a foreground color, this will default to white
* size
    + the width of the button
* icon
    - add an icon before the subject text
    - defaults to a font-awesome icon if there is no ':' prefix to fully specify the icon.
        - 'plus-circle' interpreted as '\:fa:plus-circle'

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>A basic button

    ~~~~{.button subject='test run' color='green'}
    ~~~~

Buttons work well as short blocks

    \{\{.button subject='test run' size='150'}}

Fully specify the colors

    \{\{.button subject='test run' size='150'  color='#blue.yellow' }}

With a border

    \{\{.button subject='test run' border='1'  }}

and a colored border

    \{\{.button subject='test run' border='red'  }}

With an icon

    \{\{.button subject='test run' icon='plus-circle' color='green'}}

Using a Material icon

    \{\{.button subject='Upload' icon='\:mi:file-upload' }}

</td></tr>
<tr><th>Output</th></tr>
<tr><td>
{{.button subject='test run' color='green'}}

Buttons work well as short blocks

{{.button subject='test run' size='150'}}

Fully specify the colors

{{.button subject='test run' size='150' color='#blue.yellow' }}

With a border
{{.button subject='test run' border='1'  }}

and a colored border
{{.button subject='test run' border='red'  }}

With an icon

{{.button subject='test run' icon='plus-circle' color='green'}}

Using a Material icon

{{.button subject='Upload' icon=':mi:file-upload'}}

</td></tr></table>


### Box

Show that something is important by putting it in a box

The optional arguments are

* class
    * HTML/CSS class name
* id
    * HTML/CSS class
* width
    * width of the box (default 98%)
* title
    * optional title for the section
* style
    * style the box if not doing anything else

~~~~{.buffer to_buffer=box}
Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Pellentesque sit amet accumsan est. Nulla facilisi.
Nulla lacus augue, gravida sit amet laoreet id,
commodo vitae velit. Fusce in nisi mi. Nulla congue
nulla ac bibendum semper. In rutrum sem eget purus
auctor porttitor. Mauris vel pellentesque lorem.
Vestibulum consectetur massa non fermentum dignissim.
~~~~~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.box from_buffer=box
      title='Important Notice'
      width='80%'}
    ~~~~
</td>
<td><br>
{{.box from_buffer=box title='Important Notice' width='80%'}}

<br>
</td></tr></table>

### Admonition Boxes

Show that something is important by putting it in a box with an icon

This is the complete form of the [Admonitions](#admoniotions).

There are nine types

* note
* info
* tip
* important
* caution
* warning
* error
* todo
* aside

The optional arguments are

* class
    * HTML/CSS class name
* id
    * HTML/CSS class
* width
    * width of the box (default 100%)
* title
    * optional title for the section
* style
    * style the box if not doing anything else
* icon
    * give the admonition an icon
    * '1' uses the default, otherwise use a [Font Awesome](#font-awesome) or [Google Material Font](#google-material-font) named icon, without :fa or :ma prefix, default will be for fontawesome.

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>
    \{\{.note icon=1
      content='sample text'
    }}
</td>
<td><br/>
{{.note icon=1 content='sample text'}}</td>
</tr>
<tr>
<td>
    \{\{.info icon=1
      content='sample text'
    }}
</td>
<td><br/>
{{.info icon=1 content='sample text'}}</td>
</tr>
<tr>
<td>
    \{\{.tip icon=1
      content='sample text'
    }}
</td>
<td><br/>
{{.tip icon=1 content='sample text'}}</td>
</tr>
<tr>
<td>
    \{\{.important icon=1
      content='sample text'
    }}
</td>
<td><br/>
{{.important icon=1 content='sample text'}}</td>
</tr>
<tr>
<td>
    \{\{.caution icon=1
      content='sample text'
    }}
</td>
<td><br/>
{{.caution icon=1 content='sample text'}}</td>
</tr>
<tr>
<td>
    \{\{.warning icon=1
      content='sample text'
    }}
</td>
<td><br/>
{{.warning icon=1 content='sample text'}}</td>
</tr>
<tr>
<td>
    \{\{.danger icon=1
      content='sample text'
      style='background-color:#FF80AB;
      font-size:1.5em;'
    }}
</td>
<td><br/>
{{.danger icon=1 content='sample text' style='background-color:#FF80AB;font-size:1.5em;'}}</td>
</tr>
<tr>
<td>
    \{\{.todo icon=1
      content='sample text'
      width='70%'
    }}
</td>
<td><br/>
{{.todo icon=1 content='sample text' width='70%'}}</td>
</tr>
<tr>
<td>
    \{\{.aside icon=1
      content='sample text'
      title='Try this'
    }}
</td>
<td><br/>
{{.aside icon=1 content='sample text' title='Try this'}}</td>
</tr>

<tr>
<td>
    \{\{.note
      icon=\:mi:settings-bluetooth
      content='Google material icon'
      title='Bluetooth Settings'
    }}
</td>
<td><br/>
{{.note icon=:mi:settings-bluetooth content='Google material icon' title='Bluetooth Settings' }}
</td>
</tr>
</table>

### Glossary

Build a glossary of terms or abbreviations as you progress with your document. Show them later on, there is no way (currently) to place the glossary ahead of any definitions.

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>
    This is a \{\{.gloss abbr='SMPL' def='short spelling of SAMPLE'}}
    There are other things we can do
    \{\{.glossary abbr='test' define='Test long form and arguments'}}

    Optionally if there is a link to a item e.g. [Links](#links)
    \{\{.gloss abbr='msc' define='Message Sequence Charts' link=1}}
    then this can link to the relevant website, the following link
    has not been added to
    \{\{.gloss abbr='JSON' define='JavaScript Object Notation'}},
    so no link to the website.

    Now finally, show the results
    \{\{.gloss show=1}}
</td></tr>
<tr><th>Output</th></tr>
<tr><td>
This is a {{.gloss abbr='SMPL' def='short spelling of SAMPLE'}}
There are other things we can do {{.glossary abbr='test' define='Test long form and arguments'}}

Optionally if there is a link to a item in [Links](#links) {{.gloss abbr='msc' define='Message Sequence Charts' link=1}} then this can link to the relevant website, the following link has not been added to {{.gloss abbr='JSON' define='JavaScript Object Notation'}}, so no link to the website.

Now finally, show the results
{{.gloss show=1}}
</td></tr></table>

### Quote

Pandoc provides for blockquotes, these are often like

    > a standard quote
    > another line of the block
    >
    > And a final one

as

> a standard quote
> another line of the block
>
> And a final one

We want something that can be styled differently and can have a title

The optional arguments are

* class
    * HTML/CSS class name
* id
    * HTML/CSS class
* title
    * optional title for the section

~~~~{.buffer to_buffer=quote}
Start by doing what's necessary;

then do what's possible;

and suddenly you are doing the
impossible.

~ Francis of Assisi
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.quote title='Title'
      width=100%}
    %QUOTE%
    ~~~~
</td>
<td><br>
{{.quote from_buffer=quote title='Title' width=100%}}
</td>
</tr>
<tr>
<td>
Or without the title

    ~~~~{.quote title='Title'
      width=350px}
    %QUOTE%
    ~~~~
</td>
<td><br>

{{.quote from_buffer=quote width=350px}}
</td></tr></table>

## Sparklines

Sparklines are simple horizontal charts to give an indication of things, sometimes they are barcharts but we have nice smooth lines.

The only valid contents of the code-block is a single line of comma separated numbers.

The optional arguments are

* title
    * used as the generated images 'alt' argument
* bgcolor
    * background color in hex (123456) or transparent
* line
    * color or the line, in hex (abcdef)
* color
    * area under the line, in hex (abcdef)
* scheme
    * color scheme
      * options: red blue green orange mono
* size
    * size of image, default 80x20, widthxheight

~~~~{.buffer to_buffer='spark_data'}
1,4,5,20,4,5,3,1
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.buffer
      to_buffer='spark_data'}
    %SPARK_DATA%
    ~~~~

here is a standard sparkline

    ~~~~{.sparkline
      title='basic sparkline'}
    %SPARK_DATA%
    ~~~~
</td>
<td>

~~~~{.sparkline title='basic sparkline' from_buffer='spark_data'}
~~~~
</td></tr>
<tr><td>
Draw the sparkline using buffered data

    ~~~~{.sparkline
      title='blue sparkline'
      scheme='blue'
      from_buffer='spark_data'}
    ~~~~
</td>
<td>
~~~~{.sparkline title='blue sparkline' scheme='blue' from_buffer='spark_data'}
~~~~
</td>
</tr></table>

## Charts

Displaying charts is very important when creating reports, so we have a simple **chart** code-block.

~~~~{.buffer to='chart_data'}
A,B,C,D,E,F,G,H
1,2,3,5,11,22,33,55
1,2,3,5,11,22,33,55
1,2,3,5,11,22,33,55
1,2,3,5,11,22,33,55
~~~~

We will buffer some data to start. The content comprises lines of comma separated data.
The first line of the content is the legends; subsequent lines relate
to each of these legends.

    ~~~~{.buffer to='chart_data'}
    A,B,C,D,E,F,G,H
    1,2,3,5,11,22,33,55
    1,2,3,5,11,22,33,55
    1,2,3,5,11,22,33,55
    1,2,3,5,11,22,33,55
    ~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>
Pie Chart

    ~~~~{.chart format='pie'
      title='Pie'
      from_buffer='chart_data'
      size='300x300'}
    ~~~~

</td><td>
~~~~{.chart format='pie' title='Pie' from_buffer='chart_data'
    size='300x300'  }
~~~~
</td></tr>
<tr><td>
Bar Chart

    ~~~~{.chart format='bars'
      title='Bars'
      from_buffer='chart_data'
      size='300x300'
      xaxis='things ways'
      yaxis='Vertical things'
      legends='A,B,C,D,E,F,G,H' }
    ~~~~
</td><td>
~~~~{.chart format='bars' title='Bars' from_buffer='chart_data'
    size='300x300' xaxis='things ways' yaxis='Vertical things'
    legends='A,B,C,D,E,F,G,H' }
~~~~
</td>
<tr><td>
Mixed Chart

    ~~~~{.chart format='mixed'
      title='Mixed'
      from_buffer='chart_data'
      size='300x300'
      xaxis='things xways'
      axis='Vertical things'
      legends='A,B,C,D,E,F,G,H' }
      types='lines linepoints lines
        bars' }
    ~~~~
</td><td>
~~~~{.chart format='mixed' title='Mixed' from_buffer='chart_data'
  size='300x300' xaxis='things xways' axis='Vertical things'
  legends='A,B,C,D,E,F,G,H' }
 types='lines linepoints lines bars' }
~~~~
</td></tr></table>

## mscgen

*Message Sequence Charts*

Software (or process) engineers often want to be able to show the sequence in which a number of events take place. We use the [msc] program for this. This program needs to be installed onto your system to allow this to work

The content for this code-block is EXACTLY the same that you would use as input to [msc]

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, widthxheight
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image

~~~~{.buffer to_buffer=mscgen}
# MSC for some fictional process
msc {
  a,b,c;

  a->b [ label = "ab()" ] ;
  b->c [ label = "bc(TRUE)"];
  c=>c [ label = "process(1)" ];
  c=>c [ label = "process(2)" ];
  ...;
  c=>c [ label = "process(n)" ];
  c=>c [ label = "process(END)" ];
  a<<=c [ label = "callback()"];
  ---  [ label = "If more to run" ];
  a->a [ label = "next()"];
  a->c [ label = "ac1()\nac2()"];
  b<-c [ label = "cb(TRUE)"];
  b->b [ label = "stalled(...)"];
  a<-b [ label = "ab() = FALSE"];
}
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.mscgen  title="mscgen1"
      width=350}
    %MSCGEN%
    ~~~~
</td>
<td>
<br>
~~~~{.mscgen  title="mscgen1" width=350 from_buffer=mscgen}
~~~~
</td></tr></table>

## UML Diagrams

Software engineers love to draw diagrams, [PlantUML] is a java component to make this simple.

You will need to have a script on your system called 'uml' that calls java with the plantuml component.
Mine is available from [My Github] repo.

The content for this code-block must be the same that you would use to with the [PlantUML] software

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, widthxheight
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image
* align
    - align the generated image, left, center, right

~~~~{.buffer to_buffer=uml}
' this is a comment on one line
/' this is a
multi-line
comment'/
Alice -> Bob: Auth Request
Bob --> Alice: Auth Response

Alice -> Bob: Auth Request 2
Alice <-- Bob: Auth Response 2
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.uml width=350}
    %UML%
    ~~~~
</td><td>
~~~~{.uml from_buffer=uml width=350}
~~~~
</td></tr></table>

### Salt

[PlantUML] can also create simple application interfaces See [Salt]

~~~~{.buffer to_buffer=salt}
@startuml
salt
{
  Just plain text
  [This is my button]
  ()  Unchecked radio
  (X) Checked radio
  []  Unchecked box
  [X] Checked box
  "Enter text here   "
  ^This is a droplist^

  {T
   + World
   ++ America
   +++ Canada
   +++ **USA**
   ++++ __New York__
   ++++ Boston
   +++ Mexico
   ++ Europe
   +++ Italy
   +++ Germany
   ++++ Berlin
   ++ Africa
  }
}
@enduml
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.uml width=350}
    %SALT%
    ~~~~
</td><td>
~~~~{.uml from_buffer=salt width=350}
~~~~
</td></tr></table>

### Sudocku

Plantuml can generate random sudocku patterns

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.uml width=350}
    sudoku
    ~~~~
</td><td>
~~~~{.uml width=350}
sudoku
~~~~
</td></tr></table>

To always generate the same pattern, append a seed value after 'sudoku'

    ~~~~{.uml}
    sudoku 45azkdf4sqq
    ~~~~

### Umltree

Draw a bulleted list as a tree using the plantuml salt GUI layout tool.
Bullets are expected to be indented by 4 spaces, we will only process bullets that are * +  or -.

~~~~{.buffer to_buffer=umltree}
* one
    * 1.1
* two
    * two point 1
    * 2.2
* three
    * 3.1
    * 3.2
    * three point 3
        * four
            * five
        * six
    * 3 . seven
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.umltree width=350}
    %UMLTREE%
    ~~~~
</td><td>
~~~~{.umltree from_buffer=umltree width=350}
~~~~
</td></tr></table>

### Ditaa

*Diagrams Through Ascii Art*

This is a special system to turn ASCII art into pretty pictures, nice to render diagrams.
You do need to make sure that you are using a proper monospaced font with your editor otherwise things will go awry with spaces.

Rather than use the [ditaa] application and to reduce the number of applications that need to be installed on the system, we use the ditaa component of plantuml. This does have some limitations, for example there is no way to switch spaces or shadows off. However this is a useful tradeoff

The content for this code-block must be the same that you would use to with the ditaa software.

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, widthxheight
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image

~~~~{.buffer to_buffer=ditaa}
Full example
+--------+   +-------+   +-----+
|        +-->| ditaa +-->|     |
|  Text  |   +-------+   |image|
|Document|   |!magic!|   |     |
|     {d}|   |       |   |cBLU |
+---+----+   +-------+   +-----+
    :                       ^
    |       Lots of work    |
    \-----------------------+
           To do by hand
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.ditaa width=350}
    %DITAA%
    ~~~~
</td><td>
~~~~{.ditaa from_buffer=ditaa width=350}
~~~~
</td></tr></table>

## Graphviz

[graphviz] allows you to draw connected graphs using text descriptions.

The content for this code-block must be the same that you would use to with the [graphviz] software

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, widthxheight
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image
* command
    * command used to draw the graph, defaults to dot
      - options are dot, neato, twopi, fdp, sfdp, circo, osage

~~~~{.buffer to_buffer=graphviz}
digraph G {

  subgraph cluster_0 {
    style=filled;
    color=lightgrey;
    node [style=filled,color=white];
    a0 -> a1 -> a2 -> a3;
    label = "process #1";
  }

  subgraph cluster_1 {
    node [style=filled];
    b0 -> b1 -> b2 -> b3;
    label = "process #2";
    color=blue
  }
  start -> a0;
  start -> b0;
  a1 -> b3;
  b2 -> a3;
  a3 -> a0;
  a3 -> end;
  b3 -> end;

  start [shape=Mdiamond];
  end [shape=Msquare];
}
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.graphviz  title="graphviz1"
      size=width=350}
      %GRAPHVIZ%
    ~~~~
</td><td>
~~~~{.graphviz  title="graphviz1" width=350 from_buffer=graphviz}
~~~~
</td></tr></table>

### Mindmap

There is no nice way to convert plain text to mindmaps, the only way normally would be to use graphviz or something similar.

However, converting a bulleted list into a simple mindmap would be ideal!

Each bulleted item would be a node in the mindmap.

Bullets can be '*', '+' or '-' and should be indented 4 spaces to indicate a child. Poor indenting can be managed to a degree.

There should be a single top level bullet, which is used as the root of the map, see the example below. Multiple top level bullets will result in a badly organised mindmap.

Markdown style bold and italics markers can be used, as can '\n' to start a new line in a node.

Comments can be added and will be ignored when rendering the mindmap, anything following ' :' will be considered as a comment.

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, widthxheight
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image
* command
    * command used to draw the graph, defaults to dot
        - options are dot neato twopi fdp sfdp circo osage
- scheme  - color scheme to use - optional
    - default pastel28, schemes taken from [Brewer]
    - blue purple green grey mono orange red brown  are shortcuts
- shapes  - list of shapes to use - optional
    + default box ellipse hexagon octagon

Bullet text can override some shapes

+ wrap in the following to get the required shape
  + [] shape=box
  + () shape=ellipse
  + &lt;&gt; shape=diamond
  + {} shape=octagon
+ include a shape=
    + shape=box3d

Bullet text can include a color override

* \#red or  \#123456 or \#ff00ff

~~~~{.buffer to='mindmap'}
* base thought
  + (force ellipse)
      + in **bold**
  + another thing : ignore this
      + color red #red
  * put this\none\non a few\nlines
~~~~

<table class='box' width=95%>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.mindmap size=350x250}
    %MINDMAP%
    ~~~~
</td>
<td>
{{.mindmap from_buffer='mindmap' size='350x250'}}
</td>
</tr>
<tr>
<td>
Change the node style and the color scheme.

    ~~~~{.mindmap shapes='box'
      scheme=green size=350x250}
    %MINDMAP%
    ~~~~
</td>
<td>
<br>

{{.mindmap shapes='box' scheme=green from_buffer='mindmap' size=350x250}}</td>
</tr>
</table>

## Venn diagram

Creating venn diagrams may sometimes be useful, though to be honest this implementation is not great, if I could find a better way to do this then I would!

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.venn  title="sample venn diagram"
        legends="team1 team2 team3" scheme="rgb" explain='1'}
    abel edward momo albert jack julien chris
    edward isabel antonio delta albert kevin jake
    gerald jake kevin lucia john edward
    ~~~~
</td></tr>
<tr><th>Output</th></tr>
<tr><td>
~~~~{.venn  title="sample venn diagram" legends="team1 team2 team3" scheme="rgb" explain='1'}
abel edward momo albert jack julien chris
edward isabel antonio delta albert kevin jake
gerald jake kevin lucia john edward
~~~~
</td></tr></table>

## Barcodes

Sometimes having barcodes in your document may be useful, certainly qrcodes are popular.

The code-block only allows a single line of content. Some of the barcode types need
content of a specific length, warnings will be generated if the length is incorrect.

The arguments allowed are

* title
    * used as the generated images 'alt' argument
* height
    * height of image
* notext
    * flag to show we do not want the content text printed underneath the barcode.
* version
    * version of qrcode, defaults to '2'
* pixels
    * number of pixels that is a 'bit' in a qrcode, defaults to '2'
* type
    + the type of the barcode
    + code39
    + coop2of5
    + ean8 - 8 characters allowed in content
    + ean13 - 13 characters allowed in content
    + iata20f5
    + industrial20f5
    + itf
    + matrix2of5
    + nw7
    + qrcode

<table class='box' width=95%>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>
Code 39

    ~~~~{.barcode type='code39'}
    123456789}
    ~~~~
</td>
<td><br> {{.barcode type='code39' content=123456789}}</td>
</tr>
<tr>
<td>
EAN8

    ~~~~{.barcode type='ean8'}
    12345678
    ~~~~
</td>
<td><br>{{.barcode type='ean8' content='12345678'}}</td>
</tr>
<tr>
<td>
IATA2of5

    ~~~~{.barcode type='IATA2of5'}
    12345678
    ~~~~
</td>
<td><br>{{.barcode type='IATA2of5' content='12345678'}}</td>
</tr>
</table>

### QR code

As qrcodes are now quite so prevalent, they have their own code-block type.

We can do qr codes, just put in anything you like, this is a URL for bbc news

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>
    ~~~~{.qrcode }
    http://news.bbc.co.uk
    ~~~~
</td>
<td>
~~~~{.qrcode }
http://news.bbc.co.uk
~~~~
</td>
</tr>

<tr>
<td>
To change the size of the barcode

    ~~~~{.qrcode height='80'}
    http://news.bbc.co.uk
    ~~~~
</td>
<td>
~~~~{.qrcode height='80'}
http://news.bbc.co.uk
~~~~
</td>
</tr>

<tr>
<td>
To use version 1

Version 1 only allows 15 characters

    ~~~~{.qrcode height=60 version=1}
    smaller text..
    ~~~~
</td>
<td>
~~~~{.qrcode height=60 version=1}
smaller text..
~~~~
</td>
</tr>

<tr>
<td>
To change pixel size

    ~~~~{.qrcode pixels=5}
    smaller text..
    ~~~~
</td>
<td>
~~~~{.qrcode pixels=5}
smaller text..
~~~~
</td>
</tr>
</table>

## Gle / glx

This is a complex graph/chart drawing package available from http://glx.sourceforge.net/

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, default 720x512, widthxheight, size is approximate
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image
* title
    * used as the generated images 'alt' argument
* transparent
    * flag to use a transparent background

~~~~{.buffer to_buffer=gle}
set font texcmr hei 0.5 just tc

begin letz
   data "saddle.z"
   z = 3/2*(cos(3/5*(y-1))+5/4)/(1+(((x-4)/3)^2))
   x from 0 to 20 step 0.5
   y from 0 to 20 step 0.5
end letz

amove pagewidth()/2 pageheight()-0.1
write "Saddle Plot (3D)"

begin object saddle
   begin surface
      size 10 9
      data "saddle.z"
      xtitle "X-axis" hei 0.35 dist 0.7
      ytitle "Y-axis" hei 0.35 dist 0.7
      ztitle "Z-axis" hei 0.35 dist 0.9
      top color blue
      zaxis ticklen 0.1 min 0 hei 0.25
      xaxis hei 0.25 dticks 4 nolast nofirst
      yaxis hei 0.25 dticks 4
   end surface
end object

amove pagewidth()/2 0.2
draw "saddle.bc"
~~~~
<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.gle}
    %GLE%
    ~~~~
</td></tr>
<tr><th>Output</th></tr>
<tr><td>
~~~~{.gle from_buffer=gle}
~~~~
</td></tr></table>

## Gnuplot

This is the granddaddy of charting/plotting programs, available from http://gnuplot.sourceforge.net/.

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, default 720x512, widthxheight

~~~~{.buffer to_buffer=gnuplot}
set samples 21
set isosample 11
set xlabel "X axis" offset -3,-2
set ylabel "Y axis" offset 3,-2
set zlabel "Z axis" offset -5
set title "3D gnuplot demo"
set label 1 "surface boundary" at -10,-5,150 center
set arrow 1 from -10,-5,120 to -10,0,0 nohead
set arrow 2 from -10,-5,120 to 10,0,0 nohead
set arrow 3 from -10,-5,120 to 0,10,0 nohead
set arrow 4 from -10,-5,120 to 0,-10,0 nohead
set xrange [-10:10]
set yrange [-10:10]
splot x*y
~~~~

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.gnuplot}
    %GNUPLOT%
    ~~~~
</td></tr>
<tr><th>Output</th></tr>
<tr><td>
{{.gnuplot from_buffer=gnuplot}}
</td></tr></table>

## Ploticus

This is a rather old school charting applitcation, though it can create some
graphs and charts that the other plugins cannot, e.g. Timelines.

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, widthxheight
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image

Its best to let ploticus control the size of the generated images, you may need
some trial and error with the ploticus 'pagesize:' directive.

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.ploticus}
    //  specify data using proc getdata
    #proc getdata
    data: Brazil 22
      Columbia 17
      "Costa Rica" 22
      Guatemala 3
      Honduras 12
      Mexico 14
      Nicaragua 28
      Belize 9
      "United States" 21
      Canada 8

    //  render the pie graph using proc pie
    #proc pie
    datafield: 2
    labelfield: 1
    labelmode: line+label
    center: 4 3
    radius: 1
    colors: oceanblue
    outlinedetails: color=white
    labelfarout: 1.3
    total: 256
    ~~~~
</td></tr>
<tr><th>Output</th></tr>
<tr><td>

~~~~{.ploticus}
//  specify data using proc getdata

pagesize: 8 8

#proc getdata
data: Brazil 22
  Columbia 17
  "Costa Rica" 22
  Guatemala 3
  Honduras 12
  Mexico 14
  Nicaragua 28
  Belize 9
  "United States" 21
  Canada 8

//  render the pie graph using proc pie
#proc pie
datafield: 2
labelfield: 1
labelmode: line+label
center: 4 3
radius: 1
colors: oceanblue
outlinedetails: color=white
labelfarout: 1.3
total: 256
~~~~

And here is that timeline (from http://ploticus.sourceforge.net/gallery/clickmap_time2.htm)

~~~~{.ploticus}
#proc getdata
data:
   NBC  8:00  9:00  "Wind\non Water"
   NBC  9:00  9:30  "Encore!\nEncore!"
   NBC  9:30  10:00 "Conrad\nBloom"
   NBC  10:00 11:00 "Trinity"
   ABC  8:00  8:30  "Secret\nLives"
   ABC  8:30  9:00  "Sports\nNight"
   ABC  9:00  11:00 "Movie of the Week"
   CBS  8:00  8:30  "Cosby"
   CBS  8:30  9:00  "Kids say..."
   CBS  9:00  10:00 "Charmed"
   CBS  10:00 11:00 "To have\nand to Hold"

#proc areadef
   title: Evening television schedule
   rectangle: 1 1 7 3
   xscaletype: time
   xrange: 08:00 11:00
   yscaletype: categories
   ycategories:
  NBC
  ABC
  CBS

#proc xaxis
   stubs: inc 1 hours

#proc yaxis
   stubs: categories

#proc bars
   color: powderblue2
   axis: x
   locfield: 1
   segmentfields: 2 3
   labelfield: 4
   longwayslabel: yes
   labeldetails: size=6
~~~~
</td></tr></table>

## Polaroid

Display an image with a bounding box so it looks like a polaroid snap.

reate a polaroid style image with space underneath for writing on.
Image may be automatically rotated depending upon the exif information

The required arguments are

* src
    * filename to convert to a polaroid

The optional arguments are

* title
    * title for the photo
* date
    * optional date for the photo

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.polaroid src='heartp.jpg'
      title='The heart of Paris'
      date='2015-02-06'}
    ~~~~
</td>
<td><br>
~~~~{.polaroid src='heartp.jpg' title='The heart of Paris' date='2015-02-06'}
~~~~
</td></tr></table>

## Blockdiag

Blockdiag provides a number of ways to create nice diagrams. See <http://blockdiag.com/> for more information, how to install and examples.

To keep things simple, we add the correct wrapper around the fenced codeblock, so that there is no need to add **blockdiag {** etc to the start and end of the blocks.

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, widthxheight
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image
* transparent
    + should the background be transparent, default true

### blockdiag

Similar to graphviz, layout is more grid based.

~~~~{.buffer to_buffer=blockdiag}
note [shape = note];
mail [shape = mail];
cloud [shape = cloud];
actor [shape = actor];
note -> mail ;
mail -> cloud ;
mail -> thing ;
note -> actor;
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.blockdiag  width=350}
    %BLOCKDIAG%
    ~~~~
</td><td><br>
~~~~{.blockdiag from_buffer=blockdiag width=350}
~~~~
</td></tr></table>

### nwdiag

One for the system administrators, draw your network nicely with the various networks and systems connected to them.

~~~~{.buffer to_buffer=nwdiag }
 network dmz {
 address = "210.x.x.x/24"

 web01 [address = "210.x.x.1"];
 web02 [address = "210.x.x.2"];
}
network internal {
 address = "172.x.x.x/24";

 web01 [address = "172.x.x.1"];
 web02 [address = "172.x.x.2"];
 db01;
 db02;
}
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.nwdiag  width=350}
    %NWDIAG%
    ~~~~
</td>
<td>
~~~~{.nwdiag from_buffer=nwdiag width=350 }
~~~~
</td></tr></table>

### packetdiag

Useful to describe packets of data, e.g. binary data passed between networks or stored to files.

~~~~{.buffer to_buffer=packetdiag}
colwidth = 32
node_height = 72

0-15: Source Port
16-31: Destination Port
32-63: Sequence Number
64-95: Acknowledgment Number
96-99: Data Offset
100-105: Reserved
106: URG [rotate = 270]
107: ACK [rotate = 270]
108: PSH [rotate = 270]
109: RST [rotate = 270]
110: SYN [rotate = 270]
111: FIN [rotate = 270]
112-127: Window
128-143: Checksum
144-159: Urgent Pointer
160-191: (Options and Padding)
192-223: data [colheight = 3]
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.packetdiag  width=350}
    %PACKETDIAG%
    ~~~~
</td>
<td><br>
{{.packetdiag from_buffer=packetdiag width=350}}
</td></tr></table>

### rackdiag

Useful for system administrators to keep track of their server rooms.

~~~~{.buffer to_buffer=rackdiag}
// define height of rack
10U;

// define rack items
1: UPS [2U];
3: DB Server
4: Web Server
5: Web Server
6: Web Server
7: Load Balancer
8: L3 Switch
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.rackdiag width=350}
    %RACKDIAG%
    ~~~~
</td><td>
~~~~{.rackdiag from_buffer=rackdiag width=350}
~~~~
</td></tr></table>

### actdiag

The classic swim lanes.

~~~~{.buffer to_buffer=actdiag}
write -> convert -> image

lane user {
   label = "User"
   write [label = "request"];
   image [label = "done"];
}
lane server {
   label = "Server"
   convert [label = "process"];
}
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.actdiag}
    %ACTDIAG%
    ~~~~
</td><td>
~~~~{.actdiag from_buffer=actdiag  width=350}
~~~~
</td></tr></table>

### seqdiag

Very similar to the output of mscgen and uml tags.

~~~~{.buffer to_buffer=seqdiag}
browser  -> webserver
 [label = "GET /index.html"];

browser <-- webserver;

browser  -> webserver
 [label = "POST /blog/comment"];

webserver  -> database
 [label = "INSERT comment"];

webserver <-- database;
browser <-- webserver;
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>

    ~~~~{.seqdiag}
    %SEQDIAG%
    ~~~~
</td><td>
~~~~{.seqdiag from_buffer=seqdiag width=350}
~~~~
</td></tr></table>

## Dataflow

Dataflow diagrams allow multiple outputs from a single workflow description.

See <https://github.com/sonyxperiadev/dataflow/blob/master/USAGE.md> for more information, how to install and examples.

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, widthxheight
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image
* format
    - either dfd (default) or seq
* align
    - align the generated image, left, center, right

The example images are a bit compressed to fit in the table, normally they look a lot better than this!

~~~~{.buffer to_buffer='dataflow'}
diagram 'Webapp' {
  boundary 'Browser' {
    function client 'Client'
  }
  boundary 'Amazon AWS' {
    function server 'Web Server'
    database logs 'Logs'
  }
  io analytics 'Google<br/>Analytics'

  client -> server 'Request /' ''
  server -> logs 'Log' 'User IP'
  server -> client 'Resp' 'Profile'
  client -> analytics 'Log' 'Nav'
}
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>Dataflow

    ~~~~{.dataflow format=dfd}
    %DATAFLOW%
    ~~~~
</td>
<td><br>
{{.dataflow format=dfd from_buffer=dataflow size=350x500}}
</td>
</tr>
<tr>
<td><br>
    As a sequence diagram

    ~~~~{.dataflow format=seq}
    %DATAFLOW%
    ~~~~
</td>
<td><br>
{{.dataflow format=seq from_buffer=dataflow size=350x500}}
</td></tr></table>

## Google charts

Some of the charts from https://developers.google.com/chart/ have been implemented.

This plugin requires **phantomjs** to be installed on your system.

All the charts have some optional arguments in common

* size
    - default 700x700
* height
    - height of the chart, defaults to 700
* width
    - width of the chart, defaults to 700
* class
    + add to the class that the chart generates
    + initial class is named after the chart type (timeline, barchart, sankey etc)

### Timeline chart

Timeline charts are useful for project management, as an alternative to gantt charts

The optional arguments are

* title
    * used as the generated images 'alt' argument
* size
    * size of image, widthxheight
* width
    - just constrain the width
* height
    - just constrain the height
+ class
    - add this class to the image

The timeline content consists of rows of lines with a task name, a task item, start and end times.
Optionally a #color note at the end of the line (HTML color name or triplet) will set the color of the bar.

Dates should be in yyyy-mm-dd format.

~~~~{.buffer to_buffer=timeline}
Task1, hello,   1989-03-29, 1997-02-03 #green
Task1, sample,   1995-03-29, 2007-02-03   #663399
Task1, goodbye,   2019-03-29, 2027-02-03 #plum
Task2, eat and eat and eat and eat,  1997-02-03,  2001-02-03 #thistle
Task2, drink,  1998-02-03,  2004-02-03 #grey
Task3, shop,  2001-02-03,  2009-02-03 #red
Task3, drop,  2001-02-03,  2019-02-03 #darkorange
~~~~

We will set some data into a buffer for ease of use

    ~~~~{.buffer to_buffer=timeline}
    Task1, hello,   1989-03-29, 1997-02-03 #green
    Task1, sample,   1995-03-29, 2007-02-03   #663399
    Task1, goodbye,   2019-03-29, 2027-02-03 #plum
    Task2, eat and eat and eat and eat,  1997-02-03,  2001-02-03 #thistle
    Task2, drink,  1998-02-03,  2004-02-03 #grey
    Task3, shop,  2001-02-03,  2009-02-03 #red
    Task3, drop,  2001-02-03,  2019-02-03 #darkorange
    ~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>Default

    ~~~~{.timeline
      from_buffer=timeline
      size=350x300}
    ~~~~
</td>
<td><br>
~~~~{.timeline from_buffer=timeline size=350x300}
~~~~
</td></tr>
<td>Setting a background color

Use the 'background' parameter to set a color, this can be a HTML color name or hex triplet,
'none' or 'transparent' will remove the background.

    ~~~~{.timeline from_buffer=timeline
    background='GhostWhite'
    size=350x300}
    ~~~~
</td>
<td><br>
~~~~{.timeline from_buffer=timeline background='honeydew' size=350x300}
~~~~
</td>
<tr><td>Removing bar labels

This is useful if you only really want to show an approximation of how long things will take without specifying which tasks are which.

Set the 'labels' parameter to 'false' or 0.

    ~~~~{.timeline from_buffer=timeline
      background='none'
      labels=false
      size=350x300}
    ~~~~
</td>
<td><br>
~~~~{.timeline from_buffer=timeline background='none' labels=false size=350x300}
~~~~
</td></tr></table>

### Sankey Chart

*From google charts:*
A sankey diagram is a visualization used to depict a flow from one set of values to another. The things being connected are called nodes and the connections are called links. Sankeys are best used when you want to show a many-to-many mapping between two domains (e.g., universities and majors) or multiple paths through a set of stages (for instance, Google Analytics uses sankeys to show how traffic flows from pages to other pages on your web site).

For the curious, they're named after Captain Sankey, who created a diagram of steam engine efficiency that used arrows having widths proportional to heat loss.

The optional arguments are

* colors
    - comma separated list of HTML color names (or triplets), to be used for the nodes and links
* mode
    - how the link color is chosen
    + source - link color is the same as the source node
    + target - link color is the same as the target node
    + gradient - link color starts as node color and ends as target color

~~~~{.buffer to_buffer=sankey_simple}
A, X, 5
A, Y, 7
A, Z, 6
B, X, 2
B, Y, 9
B, Z, 4
~~~~

<table class='box' width='99%'>
<thead><tr><th width='50%'>Example</th><th>Output</th></tr></thead>
<tr>
<td>A Simple set

    ~~~~{.sankey size=350x200
      mode=target}
    %SANKEY_SIMPLE%
    ~~~~
</td><td>
<br>
~~~~{.sankey from_buffer=sankey_simple size=350x200 mode=target}
~~~~
</td></tr>
<tr>
<td>A Complex set - only a small portion of the data is being shown

    ~~~~{.sankey size=350x400
      mode='source'
      colors="#a6cee3, #b2df8a,
        #fb9a99,#fdbf6f, #cab2d6,
        #ffff99 #1f78b4"}}
    Brazil, Portugal, 5 ,
    Brazil, France, 1 ,
    Brazil, Spain, 1 ,
    Brazil, England, 1 ,
    Canada, Portugal, 1 ,
    Canada, France, 5 ,
    Canada, England, 1 ,
    Mexico, Portugal, 1 ,
    Mexico, England, 1 ,
    USA, Portugal, 1 ,
    Portugal, Angola, 2 ,

    ...
    ~~~~
</td>
<td><br>
~~~~{.sankey size=350x400 mode='source' colors="#a6cee3, #b2df8a, #fb9a99, #fdbf6f, #cab2d6, #ffff99 #1f78b4"}
Brazil, Portugal, 5 ,
Brazil, France, 1 ,
Brazil, Spain, 1 ,
Brazil, England, 1 ,
Canada, Portugal, 1 ,
Canada, France, 5 ,
Canada, England, 1 ,
Mexico, Portugal, 1 ,
Mexico, France, 1 ,
Mexico, Spain, 5 ,
Mexico, England, 1 ,
USA, Portugal, 1 ,
USA, France, 1 ,
USA, Spain, 1 ,
USA, England, 5 ,
Portugal, Angola, 2 ,
Portugal, Senegal, 1 ,
Portugal, Morocco, 1 ,
Portugal, South Africa, 3 ,
France, Angola, 1 ,
France, Senegal, 3 ,
France, Mali, 3 ,
France, Morocco, 3 ,
France, South Africa, 1 ,
Spain, Senegal, 1 ,
Spain, Morocco, 3 ,
Spain, South Africa, 1 ,
England, Angola, 1 ,
England, Senegal, 1 ,
England, Morocco, 2 ,
England, South Africa, 7 ,
South Africa, China, 5 ,
South Africa, India, 1 ,
South Africa, Japan, 3 ,
Angola, China, 5 ,
Angola, India, 1 ,
Angola, Japan, 3 ,
Senegal, China, 5 ,
Senegal, India, 1 ,
Senegal, Japan, 3 ,
Mali, China, 5 ,
Mali, India, 1 ,
Mali, Japan, 3 ,
Morocco, China, 5 ,
Morocco, India, 1 ,
Morocco, Japan, 3
~~~~
</td></tr></table>

## Gantt

~~~~{.buffer to_buffer=gantt}
section A section
Completed item           :done,    des1, 2015-05-26,2015-05-28
Active item              :active,  des2, 2015-05-29, 3d
item                     :         des3, after des2, 5d
item2                    :         des4, after des3, 5d

section Critical items
Completed critical item  :crit, done, 2015-06-06,24h
Implement gantt          :crit, done, after des1, 2d
Create tests             :crit, active, 2015-06-26, 3d
critical item            :crit, 5d
renderer tests           : 2d
Add to CT2               : 1d

section Documentation
Describe syntax          :active, a1, after des1, 3d
Add to demo              : after a1  , 10d

section Last section
Describe  syntax         : after doc1, 3d
Add gantt                : 1d
Add another              : 2d
~~~~

<table class='box' width='99%'>
<tr><th width='100%'>Example</th></tr>
<tr>
<td>

    ~~~~{.gantt title=Demo}
    %GANTT%
    ~~~~
</td>
</tr>
<tr><th width='100%'>Output</th></tr>
<tr><td>

~~~~{.gantt from_buffer=gantt title=Demo}
~~~~

timeline width same data

~~~~{.timeline background='grey90' width=700 height=250}
A section,Completed item, 2015-05-26,2015-05-28 #green
A section,Active item, 2015-05-29, 2015-06-01   #darkorange
A section,item, 2015-06-01, 2015-06-06 #grey
A section,item2, 2015-06-06, 2015-06-11 #grey

Critical items,Completed critical item, 2015-06-06,2015-06-07   #green
Critical items,Implement gantt, 2015-05-28, 2015-05-30   #green
Critical items,Create tests, 2015-06-26, 2015-06-29 #darkorange
Critical items,critical item, 2015-06-29, 2015-07-05    #red
Critical items,renderer tests, 2015-07-05, 2015-07-07 #grey
Critical items,Add to CT2, 2015-07-07, 2015-07-08 #grey

Documentation,Describe syntax, 2015-05-28, 2015-06-01   #darkorange
Documentation,Add to demo, 2015-06-01  , 2015-06-11 #grey

Last section,Describe  syntax, 2015-06-26, 2015-06-28 #grey
Last section,Add gantt, 2015-06-28, 2015-06-29 #grey
Last section,Add another, 2015-06-29, 2015-06-31 #grey
~~~~

</td>
</tr></table>

## Smilies

Conversion of some smilies to font-awesome characters, others to general UTF8 characters that can be displayed in most browsers. **Not everything is working at the moment**

This is tricky to show as however I change things the processor will make smilies of these   :) <3  ;) .

Just try some of your favourite smilies and see what comes out!

There are a range of smilies that are also available as words pre/post fixed with a colon like **:word:**

~~~~{.table class=box width=50% zebra=1 legends=1 separator='\|'}
 smilie      | word
 <3          | \:heart\:
 :)          | \:smile\:
 :D          | \:grin\:
 8-)         | \:cool\:
 :P          | \:tongue\:
 :'(         | \:cry\:
 :(          | \:sad\:
 ;)          | \:wink\:
 :fear:      | \:fear\:
 :halo:      | \:halo\:
 :devil:     | \:devil\:, \:horns\:
 (c)         | \:c\:, \:copyright\:
 (r)         | \:r\:, \:registered\:
 (tm)        | \:tm\:, \:trademark\:
 :email:     | \:email\:
 :yes:       | \:tick\:
 :no:        | \:cross\:
 :beer:      | \:beer\:
 :wine:      | \:wine\:, \:glass\:
 :cake:      | \:cake\:
 :star:      | \:star\:
 :ok:        | \:ok\:, \:thumbsup\:
 :bad:       | \:bad\:, \:thumbsdown\:
 :ghost:     | \:ghost\:
 :skull:     | \:skull\:
 :hourglass: | \:hourglass\:
 :time:      | \:watch\:, \:clock\:
 :sleep:     | \:sleep\:
 :zzz:       | \:zzz\:, \:snooze\:
~~~~


----
## Using ct2 script to process files

Included in the distribution is a script to make use of all of the above code-blocks to alter [markdown] into nicely formatted documents.

Here is the help

    $ ct2 --help

    Syntax: ct2 [options] filename

    About:  Convert my modified markdown text files into other formats, by
        default will create HTML in same directory as the input file, will only
        process .md files.
        If there is no output option used the output will be to file of same
        name
        as the input filename but with an extension (if provided) from the
        document, use format: keyword (pdf html doc).

    [options]
        -h, -?, --help        Show help
        -c, --clean           Clean up the cache before use
        converting to doc/odt
        -o, --output          Filename to store the output as, extension will
        control conversion
        -p, --prince          Convert to PDF using princexml
        --templates           list available templates
        -t, --template        name of template to use
        -v, --verbose         verbose mode
        -w, --wkhtmltopdf     Convert to PDF using wkhtmltopdf

On the first time you run **ct2** a default template will be created in **~/.ct2/templates/default/template.html**, a config file to accompany this will be created in **~/.ct2/templates/default/template.html**

Create new templates in *~/.ct2/templates*, one directory for each template, follow the example in the default directory.

If you are using [PrinceXML], remember that it is only free for non-commercial use, it also adds a purple **P** to the top right of the first page of your document, though this does not appear when you print out the document.

