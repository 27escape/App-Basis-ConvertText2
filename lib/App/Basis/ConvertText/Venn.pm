
=head1 NAME

 App::Basis::ConvertText::Venn

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 Convert a text string of comma separated numbers into a Venn diagran image PNG

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 1999, now updated to become App::Basis::ConvertText::Venn

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Venn;

use 5.10.0;
use strict;
use warnings;
use GD ;
# we need to do this to ensure that venn::chart uses the right level of color
GD::Image->trueColor( 0) ;  
use Venn::Chart;
use File::Slurp qw( write_file);
use Exporter;
use Data::Printer;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( venn );

# -----------------------------------------------------------------------------

my %_colour_schemes = (
    default => [ [ 189,  66, 238, 0 ],   [ 255,  133,  0,    0 ],   [ 0,   107,  44,  0 ] ],
    rgb     => [ [ 0x99, 00, 00,  40 ],  [ 0x33, 0x99, 0xcc, 40 ],  [ 0,   0x66, 0,   40 ] ],
    rgb1    => [ [ 0x99, 00, 00,  240 ], [ 0x33, 0x99, 0xcc, 240 ], [ 0,   0x66, 0,   240 ] ],
    rgb2    => [ [ 0x99, 00, 00,  0 ],   [ 0x33, 0x99, 0xcc, 0 ],   [ 0,   0x66, 0,   0 ] ],
    blue    => [ [ 98,   66, 238, 0 ],   [ 98,   211,  124,  0 ],   [ 110, 205,  225, 0 ] ],
);

# -----------------------------------------------------------------------------

=item venn

create a simple venn diagram image, with some nice defaults, returns some 
markdown explaining the diagram, undex/empty if errors

 parameters
    text   - 2 or 3 space separated lines of items for the venn
    filename - filename to save the created image as 

    hashref params of
        title   - title for the image
        legends - legends to match the lines
        size    - size of image, default 400x400, widthxheight - optional
        scheme - color scheme

=cut

sub venn {
    my ( $text, $filename, $params ) = @_;
    $params->{title}   ||= "";
    $params->{legends} ||= "";
    $params->{size}    ||= "400x400";
    $params->{scheme}  ||= 'default';
    $params->{scheme} = lc( $params->{scheme} );
    my ( $w, $h ) = ( $params->{size} =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/ );
    if ( !$h ) {
        $w = 400;
        $h = 400;
    }
    die "Missing filename" if ( !$filename );
    die "Missing text"     if ( !$text );

    my $venn_chart = Venn::Chart->new( $w, $h ) or die("error : $!");

    # lose any leading spaces
    $text =~ s/^\s+//s;

    # Set a title, colors and a legend for our chart
    my $colors = $_colour_schemes{ $params->{scheme} } ? $_colour_schemes{ $params->{scheme} } : $_colour_schemes{default};

    $venn_chart->set_options( -title => $params->{title}, -colors => $colors );

    my @legends;
    # decide how to split the legends
    if ( $params->{legends} =~ /,/ ) {
        @legends = map { my $n = $_; $n =~ s/^\s+//; $n } split( /,/, $params->{legends} );
    }
    else {
        @legends = split( /\s/, $params->{legends} );
    }

    # get the venn data, max 3 lines of it
    my $lines = 0;
    my @data;
    my @newlegends;
    foreach my $line ( split( /\n/, $text ) ) {
        $line =~ s/^s+//;    # remove leading spaces
        next if ( !$line );
        # update legends with members
        my $l = $legends[$lines] ;
        if( !$l) {
            $l = 'missing' ;
            push @legends, $l ;
        }
        push @newlegends, "$l : $line";
        last if ( ++$lines > 3 );
        my @a = split( /[,\s+]/, $line );
        push @data, \@a;
    }
    $venn_chart->set_legends(@newlegends);

    # Create a diagram with gd object
    my $gd_venn = $venn_chart->plot(@data);
    # Create a Venn diagram image in png format
    write_file( $filename, $gd_venn->png() );

    # now explain what is in each region
    my @ref_lists = $venn_chart->get_list_regions();
    my $md = "\n\n";
    $md .= "* only in $legends[0] : " . join( ' ', @{ $ref_lists[0] } ) . "  
* only in $legends[1] : " . join( ' ', @{ $ref_lists[1] } ) . "
    * $legends[0] and $legends[1] share : " . join( ' ', @{ $ref_lists[2] } ) . "\n";
    if ( scalar(@newlegends) > 2 ) {
        $md .= "* only in $legends[2] : " . join( ' ', @{ $ref_lists[3] } ) . "
    * $legends[0] and $legends[2] share : " . join( ' ', @{ $ref_lists[4] } ) . "
    * $legends[1] and $legends[2] share : " . join( ' ', @{ $ref_lists[5] } ) . "
    * $legends[0], $legends[1] and $legends[2] share : " . join( ' ', @{ $ref_lists[6] } ) . "\n";
    }

    $md .= "\n";

    return $md;
}

# ----------------------------------------------------------------------------

1;

__END__
