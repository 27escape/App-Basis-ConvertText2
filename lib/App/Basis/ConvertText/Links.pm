
=head1 NAME

 App::Basis::ConvertText::Links

=head1 SYNOPSIS

<links class='weblinks'>
    JuiceBinary | http://infra/jb_docs
    Mega Manifest  | #mega-manifest-file
    Private Sections | http://wiki.inview.co.uk/index.php/Euro:Private_Section_Format
    Inview File Descriptors | http://wiki.inview.co.uk/index.php/Euro:Inview_Descriptors
</links>
 
creates 
 
[JuiceBinary]: http://infra/jb_docs
[Mega Manifest]: #mega-manifest-file
[Private Sections]: http://wiki.inview.co.uk/index.php/Euro:Private_Section_Format
[Inview File Descriptors]: http://wiki.inview.co.uk/index.php/Euro:Inview_Descriptors

<ul class='weblinks'>
    <li> <a href='http://infra/jb_docs'>JuiceBinary</a> http://infra/jb_docs
    <li> <a href='http://wiki.inview.co.uk/index.php/Euro:Private_Section_Format'>Private Sections</a> http://wiki.inview.co.uk/index.php/Euro:Private_Section_Format
    <li> <a href='http://wiki.inview.co.uk/index.php/Euro:Inview_Descriptors'>Inview File Descriptors</a> http://wiki.inview.co.uk/index.php/Euro:Inview_Descriptors
</ul>


=head1 DESCRIPTION

 Create both a HTML div with an unordered list of links to websites and the
 correct links to be embedded back into the document. The document should use
 [JuiceBinary] etc to reference these

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in Sept 2013

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Links;

use 5.10.0;
use strict;
use warnings;
use Exporter;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( links);

# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------

=item links

create a list of website links
links are one per line and the link name is separated from the link with a 
pipe '|' symbol

 parameters
    class   - name of class for the list, defaults to weblinks

=cut
sub links
{
    my ($text, $filename, $params) = @_;
    $params->{class} ||= "weblinks" ;
    my $references = "" ;
    my $ul = "<ul class='$params->{class}'>\n" ;
    my %refs = () ;
    my %uls = () ;

    foreach my $line ( split( /\n/, $text)) {
        my ($ref, $link) = split( /\|/, $line) ;
        next if( !$link) ;
        # trim the items
        $ref =~ s/^\s+// ;
        $link =~ s/^\s+// ;
        $ref =~ s/\s+$// ;
        $link =~ s/\s+$// ;
        # if there is nothing to link to ignore this
        next if( !$ref || !$link) ;

        $references .= "[$ref]: $link\n" ;

        # links that reference inside the document do not get added to the
        # list of weblinks
        if( $link !~ /^#/) {
            $uls{lc($ref)} = "<li><a href='$link'>$ref</a><ul><li>$link</li></ul></li>\n" ;
        }
    }
    # make them nice and sorted
    map { $ul .= $uls{$_} } sort keys %uls ;
    $ul .= "</ul>\n" ;

    return "\n" . $references . "\n" . $ul . "\n" ;
}

# ----------------------------------------------------------------------------

1;
