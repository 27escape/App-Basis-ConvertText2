
=head1 NAME

 App::Basis::ConvertText::Uml

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 convert a uml text string into a PNG, requires uml program

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 2013, now updated to become App::Basis::ConvertText::Uml

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Uml;

use 5.10.0;
use strict;
use warnings;
use App::Basis;
use File::Temp qw(tempfile);
use File::Slurp qw(write_file);
use Exporter;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( uml);

# uml is a script to run plantuml basically does java -jar plantuml.jar
use constant UML => '/home/kmulholland/bin/uml';

# ----------------------------------------------------------------------------

BEGIN {
    my ($r, $o, $e) = run_cmd(UML . " -help");
    die "Could not find " . UML if ($r > 0);
}

# ----------------------------------------------------------------------------

=item uml

create a simple uml image

 parameters
    data   - uml text      
    filename - filename to save the created image as 

 hashref params of
        size    - size of image, widthxheight - optional

=cut
sub uml
{
    my ($text, $filename, $params) = @_;
    $params->{size} ||= "";
    my ($x, $y) = ($params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/);

    my ($fh, $umlfile) = tempfile("/tmp/uml.XXXX");

    $text = "\@startuml\n$text" if( $text !~ /\@startuml/) ;
    $text .= "\n\@enduml" if( $text !~ /\@enduml/) ;

    # we are lucky that plantuml can have image sizes
    if( $x && $y) {
        $text =~ s/\@startuml/\@startuml\nscale $x*$y\n/ ;
    }

    write_file($umlfile, $text);

    my $cmd = UML . " $umlfile $filename";
    my ($exit, $stdout, $stderr) = run_cmd($cmd);

    return $exit == 0 ? 1 : 0;
}

# ----------------------------------------------------------------------------

1;
