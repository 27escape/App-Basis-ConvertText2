
=head1 NAME

App::Basis::ConvertText2::Plugin::Dataflow

=head1 SYNOPSIS

    my $content = "diagram 'Webapp' {
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
      server -> client 'Response' 'User Profile'
      client -> analytics 'Log' 'Page Navigation'
    }" ;
    my $params = {
        size   => "600x480",
        format => 'seq'
    } ;
    my $obj = App::Basis::ConvertText2::Plugin::Dataflow->new() ;
    my $out = $obj->process( 'dataflow', $content, $params) ;

=head1 DESCRIPTION

convert a dataflow into PNG,
requires dataflow program from L<https://github.com/sonyxperiadev/dataflow>

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Dataflow ;

use 5.10.0 ;
use strict ;
use warnings ;
use Path::Tiny ;
use App::Basis ;
use Moo ;
use App::Basis::ConvertText2::Support ;
use namespace::autoclean ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{dataflow }] }
) ;

# -----------------------------------------------------------------------------
# convert from the compact form of the description to the expanded form, that
# for some reason seems to be required
# this is not the cleanest bit of code!
# -----------------------------------------------------------------------------
sub expand_content
{
    my ($content) = @_ ;
    my $newc = "" ;

    # test to see if we have any compact form items
    if ( $content =~ /([\w_-]+)\s\<?-\>?\s+([\w_-]+)\s+(["'])[^\3](.*?)\3\s+(["'])(.*?)\5/gsm ) {
        $content =~ s/<br\/?>/\\n/gsm ;
        # if ( $content =~ /\s\<?-\>?\s(["']).*?\1\s(["']).*?\2/sm ) {
        foreach my $line ( split( /\n/, $content ) ) {
            # expand any nodes
            $line
                =~ s/(function|io|database)\s+(["'])?(\w+)\2?\s+(["'])(.*?)\4/$1 $3 {\n        title = "$5"\n    }/
                ;

            # diagrams and boundaries are slightly different
            $line =~ s/(diagram)\s+(["'])?([\w\\n ]+)\2?\s+\{/$1 {\n    title = "$3"/ ;
            if ( $line =~ /(boundary)\s+(["'])?(.*?)\2?\s+\{/ ) {
                my ( $item, $title ) = ( $1, $3 ) ;
                my $t2 = $title ;
                $t2 =~ s/\\n/_/g ;
                $t2 =~ s/[ (){}]/_/g ;
                $line = "$item $t2 {\n    title = \"$title\"" ;
            }

            # now the flow items
            if ( $line =~ /^(\s+)?([\w_-]+)\s+(\<)?-(\>)?\s+(\w+)\s+(.*)/ ) {
                my $left   = $6 ;
                my $fspace = $1 ? "$1$1" : "" ;
                my $space  = $1 || "" ;
                my $tc     = $2 ? "$space$2 " : "$space " ;
                $tc .= "$3"  if ($3) ;
                $tc .= "-" ;
                $tc .= "$4 " if ($4) ;
                $tc .= "$5 {\n" ;

                # lets do it in simpler chunks
                if ( $left =~ /(["'])(.*?)\1\s+((["'])(.*?)\4\s+?)?((["'])(.*?)\7)/ ) {
                    my ( $op, $data, $desc ) = ( $2, $5, $8 ) ;

                    if ( !$data && $desc ) {
                        $data = $desc ;
                        $desc = "" ;
                    }
                    # in operation data or description change a litteral \n to a char \n
                    if ($op) {
                        $op =~ s/\\n/\n/g ;
                        $tc .= $fspace . "operation = '$op'\n" ;
                    }
                    if ($data) {
                        $data =~ s/\\n/\n/g ;
                        $tc .= $fspace . "data = '$data'\n" ;
                    }
                    if ($desc) {
                        $desc =~ s/\\n/\n/g ;
                        $tc .= $fspace . "description = '$desc'\n" ;
                    }
                }

                $tc .= "$space}\n" ;
                $line = $tc ;
            }

            $newc .= "$line\n" ;
        }
    } else {
        verbose("not compact") ;
        $newc = $content ;
    }

    $newc =~ s/'/"/g ;
    verbose( $newc) ;

    return $newc ;
}

# ----------------------------------------------------------------------------

=item dataflow

create a simple dataflow image

 parameters
    data   - dataflow text
    filename - filename to save the created image as

 hashref params of
        size    - size of image, widthxheight - optional
        width   - optional width
        height  - optional
        class   - optional
        format  - either seq/sequence  (default) or of dfd/dataflow
        title   - optional set the alt text
        align   - option, set alignment of image

=cut

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    my %formats = (
        dataflow => 'dfd',
        sequence => 'seq',
        dfd      => 'dfd',
        seq      => 'seq',
        default  => 'seq',
    ) ;
    my $out ;
    eval {

        $params->{size} ||= "" ;
        my ( $x, $y ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ ) ;
        $x = $params->{width}  if ( $params->{width} ) ;
        $y = $params->{height} if ( $params->{height} ) ;
        $params->{title} ||= "" ;
        $params->{class} ||= "" ;

        $params->{format} ||= 'default' ;
        $params->{format} = $formats{ lc( $params->{format} ) } || $formats{default} ;

        my $args = "" ;

        # strip any ending linefeed
        chomp $content ;
        return "" if ( !$content ) ;

        # if( $params->{format} eq 'dfd') {
        #     $content =~ s/\\n/<br>/gsm ;
        # }

        # we can use the cache or process everything ourselves
        my $sig = create_sig( $content, $params ) ;
        my $filename = cachefile( $cachedir, "$tag.$sig.svg" ) ;
        if ( !-f $filename ) {
            $content = expand_content($content) ;

            # we need to alter the data slightly when doing dataflows to cope with
            # embedded new lines
            # if ( $params->{format} eq 'dfd' ) {
                # convert all strings to dataflow text blocks
                $content =~ s/"/`/gsm ;
                # make new lines in the text blocks
                $content =~ s/\\n/\n/gsm ;
            # }

            my $diagfile =
                cachefile( $cachedir, "$tag.$sig.inp" ) ;  # Path::Tiny->tempfile("dataflow.XXXX") ;
            path($diagfile)->spew_utf8($content) ;
            verbose("content is $content") ;
            my $tmpfile = cachefile( $cachedir, "$tag.$sig.out" )
                ;    # Path::Tiny->tempfile("dataflow.tmp.XXXX") ;

            my $cmd = "$tag $params->{format} $diagfile " ;
            verbose("command $cmd") ;
            my ( $exit, $stdout, $stderr ) = run_cmd($cmd) ;
            if ($exit) {
                die
                    "Could not run script $tag get it from https://github.com/sonyxperiadev/dataflow"
                    ;
            }
            my $convertor = "" ;
            path($tmpfile)->spew_utf8($stdout) ;
            verbose("output was $stdout") ;
            if ( $params->{format} eq 'dfd' ) {
                # convert with dot
                $convertor = "dot -Tsvg -o$filename $tmpfile" ;
            } else {
                # convert with plantuml
                $convertor = "uml -s $tmpfile $filename" ;
            }
            # say STDERR "convertor $convertor" ;
            ( $exit, $stdout, $stderr ) = run_cmd($convertor) ;
            if ($exit) {
                verbose("out $stdout\nerr $stderr") ;
                die "Could not run convertor script $convertor" ;
            }
        }

        if ( -f $filename ) {

            # create something suitable for the HTML
            my $s = "" ;
            $s .= " width='$x'"  if ($x) ;
            $s .= " height='$y'" if ($y) ;

            if ( $params->{align} ) {
                $params->{align} =~ s/middle/center/i ;
                $params->{align} =~ s/centre/center/i ;
                $out = "<div style='text-align:$params->{align};width:100%;'>" ;
            }
            $out
                .= "<img src='$filename' class='$tag $params->{class}' alt='$params->{title}' $s />"
                ;
            if ( $params->{align} ) {
                $out .= "</div>" ;
            }
        }
    } ;
    if ($@) {
        $out = "$@" ;
    }

    return $out ;

}

# ----------------------------------------------------------------------------

1 ;
