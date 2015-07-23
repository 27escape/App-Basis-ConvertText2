
=head1 NAME

App::Basis::ConvertText2::Plugin::Polaroid

=head1 SYNOPSIS

Create a image with a border like polaroid photographs used to be
Needs the right CSS to go with it though
    
=head1 DESCRIPTION

Create a polaroid style image 4in x 6in

~~~~{.polaroid src="someimg.jpg" date='2014-12-23' title='The Christmas Tree'}
~~~~

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Polaroid;

use 5.14.0;
use strict;
use warnings;
use Path::Tiny;
use Moo;
use App::Basis::ConvertText2::Support;
use feature 'state';
use namespace::autoclean;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{polaroid}] }
);

my $default_css =<<END_CSS;
    /* -------------- Polaroid.pm css -------------- */

    .polaroid {
        background-color: grey;
        width: 4in;
        height: 6in;
        max-width: 4in ;
        hax-height: 6in;
        margin-bottom: 75px;
        padding-bottom: 75px;
        background-color: white;
        border: 1px solid black;
        z-index: -100;
    }
    .polaroid img {
        width: 4in;
        height: 6in;
        max-width: 4in ;
        max-height: 6in;
    }

END_CSS

# -----------------------------------------------------------------------------

=item polaroid

Create a polaroid style image with space underneath for writing on.
Image may be automatically rotated depending upon the exif information

 parameters

    hashref params of
        src   - filename to convert to a polaroid
        title - optional title for the photo
        date  - optional date for the photo
        class - optional

=cut

sub polaroid
{
    my $self = shift;
    my ( $tag, $content, $params, $cachedir ) = @_;
    $params->{title} ||= "" ;
    $params->{class} ||= "" ;

    my $out;

    # create something suitable for the HTML
    $out = "<div class='polaroid $params->{class}'>" . create_img_src( $params->{src});
    if ( $params->{title} || $params->{date} ) {
        $out .= "\n<p>&nbsp;&nbsp;";
        $out .= "$params->{title} " if ( $params->{title} );
        $out .= "<small>$params->{date}</small>" if ( $params->{date} );
        $out .= "</p>\n";
    }

    $out .= "</div>";
    return $out;

}

# ----------------------------------------------------------------------------
# decide which simple handler should process this request

sub process
{
    my $self = shift;
    my ( $tag, $content, $params, $cachedir ) = @_;

    state $css = 0 ;

    if( !$css) {
        add_css( $default_css) ;
        $css++ ;
    }

    if ( $self->can($tag) ) {
        return $self->$tag(@_);
    }
    return undef;
}
# ----------------------------------------------------------------------------

1;

__END__
