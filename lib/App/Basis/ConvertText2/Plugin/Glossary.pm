
=head1 NAME

App::Basis::ConvertText2::Plugin::Glossary

=head1 SYNOPSIS

keep a glossary of terms and abbreviations

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

package App::Basis::ConvertText2::Plugin::Glossary ;

use 5.14.0 ;
use strict ;
use warnings ;
use App::Basis ;
use Path::Tiny ;
use YAML qw(Load) ;
use Moo ;
use App::Basis::ConvertText2::Support ;
use feature 'state' ;
use namespace::autoclean ;

local $YAML::Preserve = 1 ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{gloss glossary}] }
) ;

my $default_css = <<END_CSS;
    /* -------------- Glossary.pm css -------------- */
    span.glossary {
        display: inline-block;
        position: relative;
        font-weight: bold;
    }
    table.glossary td.key {
       font-weight: bold;
    }
    table.glossary td.term {
       font-size: 80%;
    }
END_CSS

# span.glossary:before {
#         content: "~~~~~~~~~~~~";
#         font-size: 0.6em;
#         font-weight: 700;
#         font-family: Times New Roman, Serif;
#         color: green;
#         width: 100%;
#         position: absolute;
#         top: 12px;
#         left: -1px;
#         overflow: hidden;
#     }

# -----------------------------------------------------------------------------

=item glossary | gloss

Create

 parameters

    hashref params of
        abbr | term - the abbreviation or term to describe
        yaml - file of pre defined abbr's and definitions
        def | define  - what it means
        link | ref make the abbrieviation a reference link
        show - create a table of the glossary, if show=complete will show with a heading
        class - also apply this class, esp for show
        width - add this width as a style
        hide - hide the definition from view, in case used elsewhere

=cut

sub glossary
{
    my $self = shift ;
    state $definitions ;
    state $yaml ;

    my ( $tag, $content, $params, $cachedir ) = @_ ;
    $params->{def} ||= $params->{define} ;
    $params->{def} ||= "" ;

    if ( $params->{yaml} ) {
        if ( -f $params->{yaml} ) {
            eval { $yaml = Load( path( $params->{yaml} )->slurp_utf8() ) } ;
            if ($@) {
                warn("Errors in YAML file $params->{yaml}: $@") ;
            }
            if ( $yaml->{glossary} ) {
                $yaml = $yaml->{glossary} ;
            } else {
                verbose("YAML file $params->{yaml} does not contain a glossary field") ;
            }
            if ($@) {
                verbose("YAML file $params->{yaml} does appear to be valid") ;
            }
        } else {
            verbose("YAML file $params->{yaml} does not exist") ;
        }
    }

    my $out = '' ;
    my $class = "glossary" . ( $params->{class} ? " $params->{class}" : "" ) ;

    $params->{abbr} ||= $params->{term} ;    # term is a synomyn for abbr
                                             # sometimes users use the wrong thing
                                             # $params->{abbr} ||= $params->{abbv} ;

    if ( $params->{abbr} ) {
        # verbose( "gloss $params->{abbr}") ;
        my $a = $params->{abbr} ;
        # do we need to turn it into a reference link
        if ( $params->{ref} || $params->{link} ) {
            $a = "[$a]" ;
        }
        $a = "<abbr title='$params->{def}'>$a</abbr>" ;
        my $style = '' ;
        if ( $params->{hide} ) {
            $style = "style='display:none;'" ;
        }
        $out .= "<span $style class='$class'>$a</span>" ;

        # first time in is the right one
        if ( !$definitions->{ $params->{abbr} } ) {
            if ( $params->{def} ) {
                $definitions->{ $params->{abbr} } = $params->{def} ;
            } elsif ( $yaml->{ $params->{abbr} } ) {
                # if we have preloaded this definition, use it
                $definitions->{ $params->{abbr} } = $yaml->{ $params->{abbr} } ;
            } else {
                warn("No definition found for $params->{abbr}") ;
            }
        }
    }

    if ( $params->{show} ) {
        my $style = ( $params->{width} ? "width:$params->{width};" : "" ) ;
        $style .= "margin-left: 0 ; margin-right: auto;" ;
        $style = "style='$style'" ;

        if ( $params->{show} =~ /complete/i ) {
            # hot insert the appendix make sure the values are correct
            $out
                .= "## "
                . run_block( "appendix", undef, undef, $cachedir, 0 )
                . " - Abbreviations, Acronyms and Glossary\n\n" ;
            $out .= "<table class='glossary clear' $style>" ;
            foreach my $key ( sort { lc($a) cmp lc($b) } keys %{$definitions} ) {
                $out
                    .= "<tr><td class='key'>**$key**</td><td class='term'>$definitions->{$key}</td></tr>\n"
                    ;
            }
            $out .= "</table>\n" ;
            $out .= "\n\n" ;
        } else {
            $out
                .= "<table class='$class' $style><tr><th>Abbreviation</th><th>Definition</th></tr>\n"
                ;
            foreach my $key ( sort { lc($a) cmp lc($b) } keys %{$definitions} ) {
                $out
                    .= "<tr><td class='key'>$key</td><td class='value'>$definitions->{$key}</td></tr>\n"
                    ;
            }
            $out .= "</table>\n" ;
        }
    }

    return $out ;
}

# ----------------------------------------------------------------------------
# decide which simple handler should process this request

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;
    state $css = 0 ;

    if ( !$css ) {
        add_css($default_css) ;
        $css++ ;
    }

    # same things
    $tag = 'glossary' if ( $tag eq 'gloss' ) ;

    if ( $self->can($tag) ) {
        return $self->$tag(@_) ;
    }
    return undef ;
}
# ----------------------------------------------------------------------------

1 ;

__END__
