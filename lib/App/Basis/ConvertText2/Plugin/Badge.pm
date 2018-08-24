
=head1 NAME

App::Basis::ConvertText2::Plugin::Badge

=head1 SYNOPSIS

Create badges/shields like http://shields.io/
use CSS to style all the badges

=head1 DESCRIPTION

Create a badge/shield style image

{{.badge subject='The Christmas Tree' status='up' color='green'}}

restapi is a special case of badge

{{.restapi method='GET' url => '/api/1/process' }}

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
use App::Basis ;


has handles => (
    is       => 'ro',
    init_arg => undef,
    #default  => sub { [qw{badge shield restapi rest}] }
    default  => sub { [qw{badge shield }] }
) ;

BEGIN {
    add_css( "
    /* -------------- Badge.pm css -------------- */

    span.badge { vertical-align: middle; text-align: left;}

    span.badge span.subject {
        color: white;
        background-color: darkslategray;
        border-top-left-radius: 2px;
        border-bottom-left-radius: 2px;
    }
    span.badge span.status  {
        color: white;
        background-color: lightslategray;
        border-top-right-radius: 2px;
        border-bottom-right-radius: 2px;
    }

    div.badge {
        display: inline ;
        vertical-align: middle;
        text-align: center;
    }

    div.badge div.subject {
        display: inline ;
        color: white;
        background-color: darkslategray;
        border-top-left-radius: 2px;
        border-bottom-left-radius: 2px;
    }
    div.badge div.status  {
        display: inline ;
        color: white;
        background-color: lightslategray;
        border-top-right-radius: 2px;
        border-bottom-right-radius: 2px;
    }

" ) ;
}

# -----------------------------------------------------------------------------

=item badge | shield

aka shield

Create a badge/shield to show status of something

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
        $bg = $params->{color} ;
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

    if ( $params->{reverse} ) {
        my $t = $params->{subject} ;
        $params->{subject} = $params->{status} ;
        $params->{status}  = $t ;
        $t                 = $subject_style ;
        $subject_style     = $status_style ;
        $status_style      = $t ;
    }

    # create something suitable for the HTML, no spaces, no extra lines
    my $sub_style= $subject_style ? "style='$subject_style'"  : "" ;
    my $stat_style= $status_style ? "style='$status_style'"  : "" ;
    $out
        = "<span class='badge'>"
        . "<span class='subject' $sub_style>&nbsp;&nbsp;"
        . $params->{subject}
        . "&nbsp;</span><span class='status' $stat_style>&nbsp;"
        . $params->{status}
        . "&nbsp;&nbsp;</span></span>" ;

    return $out ;
}

# ----------------------------------------------------------------------------

=item restapi

create a badge with REST API information

hashref params of
        method - get/put/post/patch/delete
        url    - url for the api call

=cut

sub restapi
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    my %style = (
        get  => { icon => ':fa:arrow-circle-down GET', color => 'blue600' },
        post => { icon => ':fa:arrow-circle-up POST',  color => 'green600' },
        put  => { icon => ':fa:plus-circle PUT',       color => 'orange600' },
        delete => { icon => ':fa:times-circle DELETE', color => 'red600' },
        patch  => {
            icon  => ':fa:chevron-circle-right PATCH',
            color => 'purple600'
        },
    ) ;

    if ( $params->{method} && $params->{url} ) {
        $params->{method} = lc( $params->{method} ) ;
        $params->{method} =~ s/^\s+|\s+$//g ; # trim
        if ( $style{ $params->{method} } ) {
            $params->{subject} = $style{ $params->{method} }->{icon} ;
            $params->{status}  = $params->{url} ;
            $params->{color} = $style{ $params->{method} }->{color} ;
        } else {
            $params->{subject} = "Invalid method" ;
            $params->{status}  = $params->{method} ;
            $params->{color} = 'crimson' ;
            $params->{reverse} = 1 ;
        }
        delete $params->{method} ;
        delete $params->{url} ;
        return $self->badge( $tag, '', $params, $cachedir ) ;
    }
    return "**.restapi missing method or parameter**" ;
}


# ----------------------------------------------------------------------------
# decide which simple handler should process this request

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    $tag = 'badge' if ( $tag eq 'shield' ) ;
    $tag = 'restapi' if ( $tag eq 'rest' ) ;
    if ( $self->can($tag) ) {
        return $self->$tag(@_) ;
    }
    return undef ;
}
# ----------------------------------------------------------------------------

1 ;

__END__
