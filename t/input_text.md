# Testing Markup

Markup is my version of markdown with extra XML like elements to allow the
creation of charts and graphs.

<!-- do the buffering -->

<buffer to='chart_data'>
apples,bananas,cake,cabbage,edam,fromage,tomatoes,chips
1,2,3,5,11,22,33,55
1,2,3,5,11,22,33,55
1,2,3,5,11,22,33,55
1,2,3,5,11,22,33,55
</buffer>

<buffer to='spark_data'>
1,4,5,20,4,5,3,1
</buffer>

<sparkline title='sparkline' scheme='blue' from_buffer='spark_data'  />

## Nice sparkline

this sparkline was buffered so should not be visible
<sparkline title='sparkline' scheme='orange' from_buffer='spark_data' to_buffer='spark1' no_output='1' />

* this item is inline on a bullet
  * <sparkline title='sparkline' scheme='mono' from_buffer='spark_data' />

This item was buffered <buffer from='spark1' />

| spark | desc |
|:----------+:------------------|
| <buffer from='spark1' /> | some thing buffered |

## Charts

### Pie chart

<chart title="chart1" from_buffer='chart_data' size="400x400" xaxis='things xways' yaxis='Vertical things' format='pie' legends='sample1,sample2,sample3,sample4,sample5,sample6,sample7,sample8' />

### Bar chart

<chart title="chart1" from_buffer='chart_data' size="600x400" xaxis='things xways' yaxis='Vertical things' format='bars' legends='sample1,sample2,sample3,sample4,sample5,sample6,sample7,sample8' />

### Mixed chart

<chart title="chart1" from_buffer='chart_data' size="600x400" xaxis='things xways' yaxis='Vertical things' format='mixed' legends='sample1,sample2,sample3,sample4,sample5,sample6,sample7,sample8'
types='lines linepoints lines bars' />

## XML type extensions

### Mscgen chart

<mscgen title="mscgen1">
msc {
  #hscale = "2" ;
  # setup the columns and hide the labels
  Inview [label=""], IPLA [label=""], STB [label=""];
  # make nice column headings
  Inview rbox Inview [label="Inview", textbgcolour="#ff7f7f"] ,
    IPLA rbox IPLA [label="IPLA", textbgcolour="#7fff7f"] ,
    STB box STB [label="STB", textbgcolour="#7f7fff"];

  |||;
  --- [label="Create catalog"] ;
  Inview => IPLA [label="Obtain full catalog"] ;
  Inview -> Inview [ label="Build catalog database"];

  |||;
  --- [label="Browse catalog"] ;
  STB => Inview [ label="Start IPLA app"] ;
  Inview >> STB [ label="Initial data"] ;
  STB => Inview [ label="Request catalog page"] ;
  Inview >> STB [ label="Catalog page data"] ;
  STB => IPLA [ label="Obtain catalog page images"] ;
  STB => STB [ label ="Choose another page"];
  STB => Inview [ label="Request catalog page data"] ;
  Inview >> STB [ label="Catalog page data"] ;
  STB => IPLA [ label="Obtain catalog page images"] ;
}
</mscgen>

### Ditaa

This is a special system to turn ASCII art into pretty pictures, nice to render diagrams.
You do need to make sure that you are using a proper monospaced font with your editor otherwise
things will go awry with spaces. See [Ditaa](http://ditaa.sourceforge.net) for reference

#### Sample 1 - Full Drawing

<ditaa>
Full example
+--------+   +-------+    +-------+
|        | --+ ditaa +--> |       |
|  Text  |   +-------+    |diagram|
|Document|   |!magic!|    |       |
|     {d}|   |       |    |       |
+---+----+   +-------+    +-------+
    :                         ^
    |       Lots of work      |
    \-------------------------+
</ditaa>

#### Sample 2 - Boxes

<ditaa>
+---------+
| cBLU    |
|         |
|    +----+
|    |cPNK|
|    |    |
+----+----+

Corners
/------+    +------\
|cBLU  |    |cPNK  |
|      |    |      |
|      |    |      |
+------/    \------+
</ditaa>

#### Sample 3 - Colours

<ditaa>
Colors
/----\ /----\
|c33F| |cC02|
|    | |    |
\----/ \----/

/----\ /----\
|c1FF| |c1AB|
|    | |    |
\----/ \----/
Color codes
/-------------+-------------\
|cRED RED     |cBLU BLU     |
+-------------+-------------+
|cGRE GRE     |cPNK PNK     |
+-------------+-------------+
|cBLK BLK     |cYEL YEL     |
\-------------+-------------/
</ditaa>

#### Sample 4 - Objects

<ditaa>
Document
+-----+
|{d}  |
|     |
|     |
+-----+

Storage
+-----+
|{s}  |
|     |
|     |
+-----+

Input/Output
+-----+
|{io} |
|     |
|     |
+-----+

Dashed lines
----+   /----\  +----+  +--------+
    :   |    |  :{s} |  :{d}     |
    |   |    |  |    |  |Document|
    |   |    |  |    |  |        |
    v   \-=--+  +----+  +--------+

Point Markers
*----*
|    |      /--*
*    *      |
|    |  -*--+
*----*
</ditaa>

#### Sample 5 - Text

<ditaa>
Text
/-----------------\
| Things to do    |
| cGRE            |
| o Cut the grass |
| o Buy jam       |
| o Fix car       |
| o Make website  |
\-----------------/
</ditaa>

### UML Diagrams with PlantUML

[PlantUML Reference](http://plantuml.sourceforge.net/)

#### Simple

<uml>
' this is a comment on one line
/' this is a
multi-line
comment'/
Alice -> Bob: Authentication Request
Bob --> Alice: Authentication Response

Alice -> Bob: Another authentication Request
Alice <-- Bob: another authentication Response
</uml>

#### More complex

<uml>
'start/enduml tags are optional
@startuml

skinparam backgroundcolor AntiqueWhite
Alice -> Bob: Authentication Request

alt successful case

    Bob -> Alice: Authentication Accepted

else some kind of failure

    Bob -> Alice: Authentication Failure
    group My own label
      Alice -> Log : Log attack start
        loop 1000 times
            Alice -> Bob: DNS Attack
        end
      Alice -> Log : Log attack end
    end

else Another type of failure

   Bob -> Alice: Please repeat

end
</uml>

#### Actors

<uml>
'start/enduml tags are optional
@startuml
skinparam backgroundcolor AntiqueWhite
left to right direction
skinparam packageStyle rect
actor customer
actor clerk
rectangle checkout {
  customer -- (checkout)
  (checkout) .> (payment) : include
  (help) .> (checkout) : extends
  (checkout) -- clerk
}
@enduml
</uml>

#### Complete Example

<uml size='600x800'>
@startuml
'http://click.sourceforge.net/images/activity-diagram-small.png
title Servlet Container

(*) --> "ClickServlet.handleRequest()"
--> "new Page"

if "Page.onSecurityCheck" then
  ->[true] "Page.onInit()"

  if "isForward?" then
   ->[no] "Process controls"

   if "continue processing?" then
     -->[yes] ===RENDERING===
   else
     -->[no] ===REDIRECT_CHECK===
   endif

  else
   -->[yes] ===RENDERING===
  endif

  if "is Post?" then
    -->[yes] "Page.onPost()"
    --> "Page.onRender()" as render
    --> ===REDIRECT_CHECK===
  else
    -->[no] "Page.onGet()"
    --> render
  endif

else
  -->[false] ===REDIRECT_CHECK===
endif

if "Do redirect?" then
 ->[yes] "redirect request"
 --> ==BEFORE_DESTROY===
else
 if "Do Forward?" then
  -left->[yes] "Forward request"
  --> ==BEFORE_DESTROY===
 else
  -right->[no] "Render page template"
  --> ==BEFORE_DESTROY===
 endif
endif

--> "Page.onDestroy()"
-->(*)

center footer %COPYRIGHT%

@enduml
</uml>

#### Beta - Activity 1

<uml size='600x400'>
start
:ClickServlet.handleRequest();
:new page;
if (Page.onSecurityCheck) then (true)
  :Page.onInit();
  if (isForward?) then (no)
    :Process controls;
    if (continue processing?) then (no)
      stop
    endif

    if (isPost?) then (yes)
      :Page.onPost();
    else (no)
      :Page.onGet();
    endif
    :Page.onRender();
  endif
else (false)
endif

if (do redirect?) then (yes)
  :redirect process;
else
  if (do forward?) then (yes)
    :Forward request;
  else (no)
    :Render page template;
  endif
endif

stop

@enduml
</uml>

#### Beta - Parallel Processing

<uml>
@startuml

start
if (multiprocessor?) then (yes)
  fork
    :Treatment 1;
  fork again
    :Treatment 2;
    :treatment 3;
    if (botox?) then (yes)
      :get nurse;
    else (must be complex)
      :get doctor;
    endif
  end fork
else (monoproc)
  :Treatment 1;
  :Treatment 2;
endif
:pay for treatment;
end

@enduml
</uml>

#### One of Stevens

<uml>
title Liberator API WebMedia
left to right direction
actor Operator

Operator --(Add WebMedia items)
(Add WebMedia items) ..> (Validate WebMedia items?) : "<<includes>>"
Operator -- (View WebMedia items)
(View WebMedia items) -- (Remove WebMedia items)
</uml>

### Ploticus

<ploticus title="ploticus1" title='ploticus chart' type='dist' csv='/home/kmulholland/tmp/live/all.csv' collate_field='date'>
</ploticus>

Currently not implemented

### Graphviz

<graphviz title="graphviz1" size='600x600'>
digraph GRAPH_0 {

  edge [ arrowhead=open ];

  graph [
    fontsize=22,
    style=filled,
    fontname="sans-serif",
    label="Liberator Cloud",
    labelloc=top ];

  node [
    fontsize=11,
    fillcolor=white,
    style=filled,
    shape=box ];

  subgraph "cluster0" {
    label="Group \#0";
    style=filled;
    labelloc=top;
    labeljust=l;
    fontsize="8.8";
    fontname=serif;
    fontcolor="#000000";
    fillcolor="#ffffff";
    color="#000000";
    border=none;
  }

  subgraph "cluster14" {
    label="Group \#14";
    subgraph "cluster50" {
      label="Group \#50";
      style=filled;
      labelloc=top;
      labeljust=l;
      label=Reporting;
      fontsize="8.8";
      fontname="sans-serif";
      fontcolor="#ffffff";
      fillcolor="#e31a1c";
      color="#000000";

      dwh [ fillcolor="#fb9a99", label="Data Warehouse" ]
      one [ fillcolor="#fb9a99" ]
      two [ fillcolor="#fb9a99" ]
    }
    subgraph "cluster31" {
      label="Group \#31";
      style=filled;
      labelloc=top;
      labeljust=l;
      label="Database Cluster";
      fontsize="8.8";
      fontname="sans-serif";
      fontcolor="#ffffff";
      fillcolor="#33a02c";
      color="#000000";

      db [ fillcolor="#b2df8a", label="Database Proxy" ]
      "master1" [ fillcolor="#b2df8a" ]
      "slave1" [ fillcolor="#b2df8a" ]
      "master2" [ fillcolor="#b2df8a" ]
      "slave2" [ fillcolor="#b2df8a" ]
      masterx [ fillcolor="#b2df8a" ]
      slavex [ fillcolor="#b2df8a" ]
      "static master" [ fillcolor="#b2df8a" ]
      "slave master" [ fillcolor="#b2df8a" ]
    }
    subgraph "cluster30" {
      label="Group \#30";
      style=filled;
      labelloc=top;
      labeljust=l;
      label="Cache Cluster";
      fontsize="8.8";
      fontname="sans-serif";
      fontcolor="#ffffff";
      fillcolor="#ff7f00";
      color="#000000";

      cache [ fillcolor="#fdbf6f", label=Cache ]
    }
    subgraph "cluster26" {
      label="Group \#26";
      style=filled;
      labelloc=top;
      labeljust=l;
      label=Services;
      fontsize="8.8";
      fontname="sans-serif";
      fontcolor="#ffffff";
      fillcolor="#6a3d9a";
      color="#000000";

      service [ fillcolor="#cab2d6", label="Services Data Ingest" ]
    }
    subgraph "cluster17" {
      label="Group \#17";
      style=filled;
      labelloc=top;
      labeljust=l;
      label="Web Cluster";
      fontsize="8.8";
      fontname="sans-serif";
      fontcolor="#ffffff";
      fillcolor="#1f78b4";
      color="#000000";

      "load balancers" [ fillcolor="#a6cee3", label="Load Balancers" ]
      proxy [ fillcolor="#a6cee3", label=Proxies ]
      "web srvr" [ fillcolor="#a6cee3", label="Web servers" ]
    }
  style=filled;
  labelloc=top;
  labeljust=l;
  label="Inview Cloud";
  fontsize="8.8";
  fontname="sans-serif";
  fontcolor="#000000";
  fillcolor="#ffffff";
  color="#000000";

  liberator [ fillcolor="#ffff99", label="Liberator" ]
  }

  liberator -> "load balancers" [ color="#000000" ]
  "load balancers" -> proxy [ color="#000000" ]
  proxy -> "web srvr" [ color="#000000" ]
  "web srvr" -> db [ color="#000000" ]
  "web srvr" -> cache [ color="#000000" ]
  db -> "static master" [ color="#000000" ]
  db -> "master1" [ color="#000000" ]
  db -> dwh [ color="#000000" ]
  db -> "master2" [ color="#000000" ]
  db -> masterx [ color="#000000" ]
  service -> db [ color="#000000" ]
  service -> cache [ color="#000000" ]
  dwh -> one [ color="#000000" ]
  "master1" -> "slave1" [ color="#000000" ]
  "master2" -> "slave2" [ color="#000000" ]
  masterx -> slavex [ color="#000000" ]
  "static master" -> "slave master" [ color="#000000" ]
  one -> two [ color="#000000" ]
}
</graphviz>

### Venn diagram

<venn title="sample venn diagram" legends="team1 team2 team3" scheme="rgb" explain='1'>
abel edward momo albert jack julien chris
edward isabel antonio delta albert kevin jake
gerald jake kevin lucia john edward
</venn>

<venn title="sample venn diagram 2 "  legends="team1 team2" scheme="rgb1" size="300x300">
edward isabel antonio delta albert kevin jake
gerald jake kevin lucia john edward
</venn>

<venn title="infra projects" legends="core console systems" scheme="rgb2">
kevin steven chrisE
steven lisa dinis chrisE
chrisL chrisE
</venn>

<h3>Normal html 3 header </h3>

#### H4 what is this styled like

How is the H4 heading styled?

### Tables

With a header line

|name|age|location|
|:-----+:----:+:----------|
|fred|200|space|
|wilma|25|history|
|fred|200|space|
|wilma|25|history|
|fred|200|space|
|wilma|25|history|

Without a header line

|:-----+:----:+:----------|
|fred|200|space|
|wilma|25|history|
|fred|200|space|

### QR codes

We can do qr codes, just put in anything you like, this is a URL for bbc news
<qrcode>
http://news.bbc.co.uk
</qrcode>

#### YAML convert to JSON

This is quite specific to use with md2format as it creates a block suitable for
pandoc to convert into nicely formated html

<yamlasjson>
epg:
  - triplet: [1,2,3,7]
    channel: BBC3
    date: 2013-10-20
    time: 20:30
    crid: dvb://112.4a2.5ec;2d22~20131020T2030000Z—PT01H30M
  - triplet: [1,2,3,9]
    channel: BBC4
    date: 2013-11-20
    time: 21:00
    crid: dvb://112.4a2.5ec;2d22~20131120T2100000Z—PT01H30M
</yamlasjson>
