
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
use namespace::autoclean ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{button }] }
) ;

BEGIN {
    add_css( "
    /* -------------- button.pm css -------------- */

    span.button { vertical-align: center; text-align: center;}

    span.button span.subject { 
        color: white; 
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
        color   - what color should it be, defaults to purple300
        size    - change the font-size from the CSS one to this
        border  - add a 1px border, if param looks like a color will color the border
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

    if ( $params->{color} && $params->{color} =~ /#(\w+)?\.(\w+)/ ) {
        ( $fg, $bg ) = ( $1, $2 ) ;
        $fg = to_hex_color($fg) ;
        $bg = to_hex_color($bg) ;
    } else {
        $bg = $params->{color} ;
    }

    $params->{color} //= 'purple300' ;
    my $style = $bg ? "background-color: $bg; " : "" ;
    $style .= "color: $fg; " if ($fg) ;
    $subject //= 'Missing subject' ;

    if ( $params->{size} ) {
        $params->{size} =~ s/%//g ;
        $style .= "font-size: $params->{size}%; " ;
    }
    if( $params->{border}) {
        my $c = $params->{border} eq "1" ? 'black' : to_hex_color($params->{border}) ;
        $style .= "border: 1px solid $c; ";
    }

    # Icon always preceeds the text
    if( $params->{icon}) {
        $params->{icon} =~ s/^\s?|\s?$//g ;
        # default to font awesome if no prefix
        if( $params->{icon} !~ /^:/) {
            $params->{icon} = ":fa:$params->{icon}" ;
        }
        # if( $params->{icon} !~ /[:|\]]$/) {
        #     $params->{icon} .= ":" ;
        # }
        $subject = "$params->{icon} $subject" ;
    }

    # create something suitable for the HTML, no spaces, no extra lines
    $out
        = "<span class='button'>"
        . "<span class='subject' style='$style'>&nbsp;"
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
