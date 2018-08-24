
=head1 NAME

App::Basis::ConvertText2::Plugin::Button

=head1 SYNOPSIS

Create a simple styled button
use CSS to style all the buttons

=head1 DESCRIPTION

Create a button style image

~~~~{.button subject='The Christmas Tree' color='green'}
~~~~

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Button ;

use 5.14.0 ;
use strict ;
use warnings ;
use Path::Tiny ;
use Moo ;
use App::Basis::ConvertText2::Support ;
use feature 'state' ;
use WebColors ;
use namespace::autoclean ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{button }] }
) ;

BEGIN {
    add_css( "
    /* -------------- button.pm css -------------- */

    span.button { vertical-align: middle; text-align: center;}

    span.button span.subject {
        /*color: white;*/
        background-color: purple300;
        border-radius: 7px;
    }

" ) ;
}

# -----------------------------------------------------------------------------

=item button

Create a button

 parameters

    hashref params of
        subject - whats the button for
        class   - additionally add this class to the button span
        color   - what color should it be, defaults to brown50
        size    - change the font-size from the CSS one to this
        border  - add a 1px border, if param looks like a color will color the border, default 1
        icon    - choose an icon to prefix the subject with,
                  :fa: will be added to default to a font-awesome icon if needed

=cut

sub button
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    my $fg ;
    my $bg ;
    my $subject = $params->{subject} ;
    my $out ;
    my $class = $params->{class} // "" ;

    # default it to on
    $params->{border} ||= "1" ;
    $params->{border} .= "" ;

    $params->{color} ||= 'brown50' ;
    if ( $params->{color} && $params->{color} =~ /#(\w+)?\.(\w+)/ ) {
        ( $fg, $bg ) = ( $1, $2 ) ;
        $bg = to_hex_color($bg) ;
        $fg = to_hex_color($fg) ;
    } else {
        $bg = to_hex_color($params->{color}) ;
        # lets make the text darker than the boder would be
        $fg = "#" . darken( $bg, 4 ) ;
    }

    my $style = $bg ? "background-color: $bg; " : "" ;
    $style .= "color: $fg; " if ($fg) ;
    $subject //= 'Missing subject' ;

    if ( $params->{size} ) {
        $params->{size} =~ s/%//g ;
        $style .= "font-size: $params->{size}%; " ;
    }
    if ( $params->{border} ) {
        my $c ;
        if ( $params->{border} eq "1" && $bg ) {
            $c = "#" . darken( $bg, 2 ) ;
        } else {
            $c = $params->{border} eq "1" ? 'black' : to_hex_color( $params->{border} ) ;
        }
        $style .= "border: 1px solid $c; " ;
    }

    # Icon always preceeds the text
    if ( $params->{icon} ) {
        $params->{icon} =~ s/^\s?|\s?$//g ;
        # default to font awesome if no prefix
        if ( $params->{icon} !~ /^:/ ) {
            $params->{icon} = ":fa:$params->{icon}" ;
        }
        $subject = "$params->{icon} $subject" ;
    }

    # class trumps style
    if ($class) {
        $style = "" ;
    }

    # create something suitable for the HTML, no spaces, no extra lines
    $style = " style='$style'" if ($style) ;
    $out =
          "<span class='button$class'>"
        . "<span class='subject'$style>&nbsp;"
        . $subject
        . "&nbsp;</span></span>" ;

    return $out ;
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

__END__
