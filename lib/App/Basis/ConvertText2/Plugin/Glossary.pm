
=head1 NAME

App::Basis::ConvertText2::Plugin::Glossary

=head1 SYNOPSIS

keep a glossary of terms

=head1 DESCRIPTION

first use always should define what it is, this and subsequent uses will output
<span class='glossary'>abbr</span>

Using the link or ref flag is used it will give a link to a defined reference link
<span class='glossary'>[abbr]</span>


{{.glossary abbr='SMS' def="Subscription Management System" link='1'}}.

other uses do not need the defintion

{{.gloss abbr='SMS'}}.

show a table of the definitions with a class of glossary

{{.glossary show='1'}}


=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Glossary;

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
    default  => sub { [qw{gloss glossary}] }
);

my $default_css =<<END_CSS;
    /* -------------- Glossary.pm css -------------- */
    span.glossary {
        display: inline-block;
        position: relative;
        color: green ;
    }
    span.glossary:before {
        content: "~~~~~~~~~~~~";
        font-size: 0.6em;
        font-weight: 700;
        font-family: Times New Roman, Serif;
        color: green;
        width: 100%;
        position: absolute;
        top: 12px;
        left: -1px;
        overflow: hidden;
    }
    table.glossary td.key {
       font-weight: bold;
       color: gree;
    }
END_CSS

# -----------------------------------------------------------------------------

=item glossary | gloss

Create

 parameters

    hashref params of
        abbr - the abbreviation
        def | define  - what it means
        show - create a table of the glossary
        link | ref make the abbrieviation a reference link

=cut

sub glossary
{
    my $self = shift;
    state $definitions ;

    my ( $tag, $content, $params, $cachedir ) = @_;
    $params->{def} ||= $params->{define} ;

    my $out ='';

    if( $params->{abbr}) {
        my $a = $params->{abbr} ;
        # do we need to turn it into a reference link
        $a = "[$a]" if( $params->{ref} || $params->{link}) ;
        $out .= "<span class='glossary'>$a</span>" ;
    }
    if( $params->{def} && $params->{abbr}) {
        $definitions->{$params->{abbr}} = $params->{def} ;
    }

    if( $params->{show}) {
        $out .= "<table class='glossary'><tr><th>Abbreviation</th><th>Definition</th></tr>\n" ;

        foreach my $key ( sort keys %{$definitions}) {

            $out .= "<tr><td class='key'>$key</td><td class='value'>$definitions->{$key}</td></tr>\n" ;
        }

        $out .= "</table>\n" ;
    }

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

    # same things
    $tag = 'glossary' if( $tag eq 'gloss') ;

    if ( $self->can($tag) ) {
        return $self->$tag(@_);
    }
    return undef;
}
# ----------------------------------------------------------------------------

1;

__END__
