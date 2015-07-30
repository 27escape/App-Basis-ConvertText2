
=head1 NAME

App::Basis::ConvertText2::Plugin::Badge

=head1 SYNOPSIS

Create badges/shields like http://shields.io/
use CSS to style all the badges

=head1 DESCRIPTION

Create a badge style image

~~~~{.badge subject='The Christmas Tree' status='up' color='green'}
~~~~

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Badge ;

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
    default  => sub { [qw{badge shield}] }
) ;

BEGIN {
    add_css( "
    /* -------------- Badge.pm css -------------- */

    span.badge { vertical-align: center; text-align: center;}

    span.badge span.subject { 
        color: white; 
        background-color: darkslategray;
        border-top-left-radius: 3px;
        border-bottom-left-radius: 3px;
    }
    span.badge span.status  { 
        color: white; 
        background-color: lightslategray;
        border-top-right-radius: 3px;
        border-bottom-right-radius: 3px;                                
    }
" ) ;
}

# -----------------------------------------------------------------------------

=item badge | shield

aka shield

Create abadge/shield to show status of something

 parameters

    hashref params of
        subject - whats the badge for
        status  - how well is it doing
        color   - what color is the status part, defaults to goldenrod
        size    - change the font-size from the CSS one to this
        reverse - swap status and subject positions

=cut

sub badge
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    my $fg ;
    my $bg ;
    if ( $params->{color} && $params->{color} =~ /#(\w+)?\.(\w+)/ ) {
        ( $fg, $bg ) = ( $1, $2 ) ;
        $fg = to_hex_color($fg) ;
        $bg = to_hex_color($bg) ;
    } else {
        my $bg = $params->{color} ;
    }

    my $out ;
    $params->{color} //= 'goldenrod' ;
    my $subject_style = "" ;
    my $status_style = $bg ? "background-color: $bg; " : "" ;
    $status_style .= "color: $fg; " if ($fg) ;
    $params->{subject} //= 'Missing subject' ;
    $params->{status}  //= 'Missing status' ;

    if ( $params->{size} ) {
        $params->{size} =~ s/%//g ;
        $status_style  .= "font-size: $params->{size}%; " ;
        $subject_style .= "font-size: $params->{size}%; " ;
    }

    if( $params->{reverse}) {
        my $t = $params->{subject} ;
        $params->{subject} = $params->{status} ;
        $params->{status} = $t ;
        $t = $subject_style ;
        $subject_style = $status_style ;
        $status_style = $t ; 
    }

    # create something suitable for the HTML, no spaces, no extra lines
    $out
        = "<span class='badge'>"
        . "<span class='subject' style='$subject_style'>&nbsp;&nbsp;"
        . $params->{subject}
        . "&nbsp;</span><span class='status' style='$status_style'>&nbsp;"
        . $params->{status}
        . "&nbsp;&nbsp;</span></span>" ;

    return $out ;
}

# ----------------------------------------------------------------------------
# decide which simple handler should process this request

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    $tag = 'badge' if ( $tag eq 'shield' ) ;
    if ( $self->can($tag) ) {
        return $self->$tag(@_) ;
    }
    return undef ;
}
# ----------------------------------------------------------------------------

1 ;

__END__
