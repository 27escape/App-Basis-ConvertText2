
=head1 NAME

App::Basis::ConvertText2::Plugin::Links

=head1 SYNOPSIS

    ~~~~{.links class='weblinks' }
        BBC | http://bbc.co.uk
        DocumentReference  | #docreference
        27escape | https://github.com/27escape
    ~~~~
 
creates this markdown and HTML
 
    [BBC]: https://bbc.co.uk
    [DocumentReference]: #docreference
    [27escape]: https://github.com/27escape

    <ul class='weblinks'>
        <li> <a href='https://bbc.co.uk'>BBC</a> BBC
        <li> <a href='#docreference'>DocumentReference</a> DocumentReference
        <li> <a href='https://github.com/27escape'>27escape</a> 27escape
    </ul>

=head1 DESCRIPTION

Create both a HTML div with an unordered list of links to websites and the
correct links to be embedded back into the document. The document should use
[JuiceBinary] etc to reference these

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Links;

use 5.10.0;
use strict;
use warnings;
use Moo;
use App::Basis;
use App::Basis::ConvertText2::Support;
use namespace::autoclean;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{links}] }
);

# ----------------------------------------------------------------------------

=item ~~~~{.links }

create a list of website links
links are one per line and the link name is separated from the link with a 
pipe '|' symbol

 parameters
    class   - name of class for the list, defaults to weblinks

=cut

sub process {
    my $self = shift;
    my ( $tag, $content, $params, $cachedir ) = @_;

    # strip any ending linefeed
    chomp $content;
    return "" if ( !$content );

    $params->{class} ||= "weblinks";
    my $references = "";
    my $ul         = "<ul class='$params->{class}'>\n";
    my %refs       = ();
    my %uls        = ();

    foreach my $line ( split( /\n/, $content ) ) {
        my ( $ref, $link ) = split( /\|/, $line );
        next if ( !$link );

        # trim the items
        $ref  =~ s/^\s+//;
        $link =~ s/^\s+//;
        $ref  =~ s/\s+$//;
        $link =~ s/\s+$//;

        # if there is nothing to link to ignore this
        next if ( !$ref || !$link );

        $references .= "[$ref]: $link\n";

        # links that reference inside the document do not get added to the
        # list of weblinks
        if ( $link !~ /^#/ ) {
            $uls{ lc($ref) } = "<li><a href='$link'>$ref</a><ul><li>$link</li></ul></li>\n";
        }
    }

    # make them nice and sorted
    map { $ul .= $uls{$_} } sort keys %uls;
    $ul .= "</ul>\n";

    return "\n" . $references . "\n" . $ul . "\n";
}

# ----------------------------------------------------------------------------

1;
