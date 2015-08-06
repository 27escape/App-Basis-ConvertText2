* support for Text::Xslate ?
* SVG::Sparkline ?
* SVG::Calendar ?
* SVG::Graph ?

* replace Ploticus/Charts with google charts
    - requires phantomjs
        + **done**
    * timelines https://developers.google.com/chart/interactive/docs/gallery/timeline
        - **done**
    * sankey
        - **done**
    * donuts https://developers.google.com/chart/interactive/docs/gallery/timeline
        - provide all corecharts, bar, line, column, bubble, area etc
    * gauge https://developers.google.com/chart/interactive/docs/gallery/gauge
        - though they look a bit pants
* https://metacpan.org/pod/DBD::Chart has some gantt stuff
* replace venn
    * https://developers.google.com/chart/image/docs/gallery/venn_charts
    * though its in end of life
    * could use a d3 venn thing with phantomjs
* or just drop venn
* change ditta
    * plantuml supports ditaa as PNGs only
    - add it to that module and drop Ditaa
    - cannot see how to remove shadows and spaces between items
    - **done**
* graphviz
    - also possible to replace with uml
    - but may not be able to generate different chart types, neato, twopi etc
    - probably a step too far
    - **done**
* ploticus
    - **done**
* add EBNF conversion into syntax/railway charts http://bottlecaps.de/rr/ui


new command internal to ConvertText2

## macros

for things that are not matched, can we find them in the $HOME/.ct2/macros directory
if so run the command if executeable passing the args on the command line
if it is not executable, treat it as an include

## hero

create a hero block

    .hero title= lorem= width=

lorem inserts that number of lorem ipsum words into the content

## mockup

create web page mockups easily

make previously buffered items and short code blocks in additon to the things this plugin provides
there are some special commands that start with '.' as well as some extra constructs

creates, potentially, a webpage with a top bar and a side bar, all other items go into a content section
topbar and sidebar should be the first items in the content


    .mockup width= height= size=

### topbar

split text following .topbar on the '|' character, items with ** surrounding them are assumed to have focus

    .topbar AMS | **BMS** | CMS | EMS | LMS | User | Logout

### sidebar

split text following .sidebar on the '|' character, items with ** surrounding them are assumed to have focus

    .sidebar Add | **Edit** | View

## layout

layout content in a basic invisible table/grid, simpler than using bootstrap ;)
table items are separated with a '|' and may be immediately followed by commands to change how that cell is displayed

layout will default to 100% width and the number of cells may be determined by the first line of the following data or given on the same line

    .layout cols=10 class=fred width= height= size=

layout is continued to be processed until another .layout directive, a .end or the end of the content section

the very first items in the cell data - without any leading space, are assumed to be special

* \.c
    * center content
* \.r
    * right justify content
* \.\d{1,2}
    * use this value as a colspan
* \.\d{1,2}x\.\d{1,2}
    * use these values as colspan and rowspan values

The end of the cell content may, without trailing space, is also special

* \.w+
    * a class to apply to the cell
* #(\w+)(\.(bg))
    * foregrounf color for the cell and optionally a background

Leading and trailing space in the cell will be removed

Other than normal text, markdown, %VAR% items and inline shortblocks, there other special things

* \n
    * starts a new line (ie <br>)
* []
    * defines a button
* ()
    * defines a radio button
* <>
    * defines a checkbox

The first character in the text within the button defines the state of the button

* ^ selected
* ! unavailable

    [OK] [CANCEL] [!SKIP]


special things, may get made into macros or something

* .img\d+x\d+
    * draw a wireframe image this size

* .carousel
    * draw a wireframe image carousel
* .epg
    * add an epg display
* .text\d+
    * add a textbox, with this many lines


~~~~{.mockup}
.topbar AMS | **BMS** | CMS | EMS | LMS | User | Logout
.sidebar Add | **Edit** | View

.layout cols=4

.r start date: | ____________[v] |.r end date: | ____________[v]
story: |.3  .text5
tags: |.3 ____________________________
image: |.2 .img300x200 | [upload] \n [delete]
| [cancel] | [save] |
~~~~


~~~~{.mockup}
.topbar AMS | BMS | CMS | **EMS** | LMS | User | Logout
.sidebar Add | **Edit** | View

.layout cols=12

.2 Name: _________ | LCN: _____ | ONID: _____ | TSID: _____ | SID: _____ | type [v]
.2 Name: _________ | LCN: _____ | ONID: _____ | TSID: _____ | SID: _____ | type [v] | epg\nonid| _____ |epg\ntsid|_____| epg\nsid| broadcast\nstart __:__[v] | broadcast\nend __:__ | [x]


~~~~

## Openiconic

Implement same as fontawesome https://useiconic.com/open/

## Extra markup

Creole (in plantuml does http://www.plantuml.com/creole.html) allowes you to specify color and underlines etc. it would be simple to add something similar

<c:#fg.bg>word</c> inline with other coloring methods

<w>wavy underline</w>
<u>underline</u>

## javascript charting

* http://www.sitepoint.com/15-best-javascript-charting-libraries/
* http://techslides.com/50-javascript-charting-and-graphics-libraries
* https://en.m.wikipedia.org/wiki/Comparison_of_JavaScript_charting_frameworks
* http://modeling-languages.com/javascript-drawing-libraries-diagrams/
* http://code.shutterstock.com/rickshaw/examples/
* http://www.omnipotent.net/jquery.sparkline/#s-about
* http://metricsgraphicsjs.org/examples.htm


### pay for

* http://gojs.net/latest/index.html?gclid=CPPInOyoqcYCFZMZtAodWEwA8A

## RACI

http://www.valuebasedmanagement.net/methods_raci.html


**Responsible** – Who is responsible for the execution of the task?
**Accountable** – Who is accountable for the tasks and signs off the work?
**Support** - optional, supports Responsible person
**Consulted** – Who are the subject matter experts who to be consulted?
**Informed** – Who are the people who need to be updated of the progress?

simple to add {{.raci}} to ct2

top line is roles, so that things can be spaced out nice
subsequent lines are the tasks with the responsibilities
~~~~{.raci }
roles   | PM | EGL | dir engineering | CEO | legal
task 1  | A  |     |                 |     |
task 2  | AR | R   | C               | I   |
task 3  | A  | R   | I               | C   | I
~~~~

There must be one R, errors if more than one R
There must be one A, errors if more than one A
warns if too many Cs (>50%?)

http://project-management.com/understanding-responsibility-assignment-matrix-raci-matrix/

suitable book http://www.amazon.co.uk/Effective-Project-Management-Traditional-Extreme/dp/1118729161/ref=sr_1_1?ie=UTF8&qid=1437980474&sr=8-1&keywords=Effective+Project+Management%3A+Traditional%2C+Agile%2C+Extreme
   http://eu.wiley.com/WileyCDA/WileyTitle/productCd-1118729161.html