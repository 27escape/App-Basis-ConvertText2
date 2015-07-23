
=head1 NAME

App::Basis::ConvertText2::Plugin::Ditaa

=head1 SYNOPSIS

    my $content = "+--------+   +-------+    +-------+
    |        +---+ ditaa +--> |       |
    |  Text  |   +-------+    |diagram|
    |Document|   |!magic!|    |       |
    |     {d}|   |       |    |       |
    +---+----+   +-------+    +-------+
        :                         ^
        |       Lots of work      |
        \-------------------------+
    " ;
    my $params = { 
        size   => "600x480",
    } ;
    my $obj = App::Basis::ConvertText2::Plugin::Ditaa->new() ;
    my $out = $obj->process( 'ditaa', $content, $params) ;
 
=head1 DESCRIPTION

convert a ditaa text string into a PNG, 
requires Uml Plugin

This has been changed from using the ditaa program to reduce the dependency
on installed software

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::Ditaa ;

use 5.10.0 ;
use strict ;
use warnings ;
use Path::Tiny ;
use App::Basis ;
use Moo ;
use App::Basis ;
use App::Basis::ConvertText2::Support ;
use namespace::autoclean ;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub { [qw{ditaa}] }
) ;


# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------

=item ditaa

generate a ditaa chart using platuml

there does not seem to be a way to drop the spaces and shadows

    ~~~~{.ditaa} 
    
      +-----+    +-----+
      | box |    |     |
      |     +--->|thing|
      +-----+    +-----+

    ~~~~

=cut

sub process
{
    my $self = shift ;
    my ( $tag, $content, $params, $cachedir ) = @_ ;

    # make sure we have no tabs
    $content =~ s/\t/    /gsm ;
    $content = "ditaa\n$content" ;

    # and process with the normal uml command
    $params->{png} = 1 ;
    return run_block( 'uml', $content, $params, $cachedir ) ;
}
# ----------------------------------------------------------------------------

1 ;
