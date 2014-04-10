
=head1 NAME

 App::Basis::ConvertText::Versions

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 Create a versions block

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in Mar 2014

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Versions;

use 5.10.0;
use strict;
use warnings;
use App::Basis;
use File::Temp qw(tempfile);
use File::Slurp qw(write_file);
use Exporter;
use Data::Printer;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( versions);

# ----------------------------------------------------------------------------

BEGIN {
}

# ----------------------------------------------------------------------------

=item versions

Create a HTML version table 


 parameters
    text - version text to convert

hashref params of
        class    - additional class to add to version table
=cut
sub versions {
    my ( $text,$params ) = @_;
    my $newtext = "" ;


    return $newtext;
}

# ----------------------------------------------------------------------------

1;
