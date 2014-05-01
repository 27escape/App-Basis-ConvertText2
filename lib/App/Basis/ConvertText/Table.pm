
=head1 NAME

 App::Basis::ConvertText::Table

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 Convert comma separated text strings into a basic table

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 1999, now updated to become App::Basis::ConvertText::Table

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Table;

use 5.10.0;
use strict;
use warnings;
use Exporter;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( table );

# ----------------------------------------------------------------------------

sub _split_csv_data {
    my $data = shift;
    my @d    = ();

    my $j = 0;
    foreach my $line ( split( /\n/, $data ) ) {
        last if ( !$line );
        my @row = split( /,/, $line );

        for ( my $i = 0; $i <= $#row; $i++ ) {
            undef $row[$i] if ( $row[$i] eq 'undef' );
            # dont' bother with any zero values either
            undef $row[$i] if ( $row[$i] =~ /^0\.?0?$/ );
            push @{ $d[$j] }, $row[$i];
        }
        $j++;
    }

    return @d;
}

# ----------------------------------------------------------------------------

=item table

create a basic html table

 parameters
    data   - comma separated lines of table data

    hashref params of
        class   - HTML/CSS class name
        id      - HTML/CSS class
        width   - width of the table
        style   - style the table if not doing anything else
        legends - csv of headings for table, these correspond to the data sets

=cut
sub table {
    my ( $text, $params ) = @_;

    $params->{title} ||= "";

    $text =~ s/^\n//gsm;
    $text =~ s/\n$//gsm;

    # open the csv file, read contents, calc max, add into data array
    my @data = _split_csv_data($text);

    #$out = "\n~~~~\n" . p( @data) . "\n~~~~\n";

    my $fields = scalar( $data[0]);
    my $out = "<table " ;
    $out .= "class='$params->{class}' " if( $params->{class}) ;
    $out .= "id='$params->{id}' " if( $params->{id}) ;
    $out .= "width='$params->{width}' " if( $params->{width}) ;
    $out .= "class='$params->{style}' " if( $params->{style}) ;
    $out .= ">\n" ;

    for( my $i = 0 ; $i < scalar(@data) ; $i++) {
        $out .= "<tr>" ;
        my $tag = $i ? 'td' : 'th' ;

        map { $out .= "<$tag>$_</$tag>" ; } @{$data[$i]} ;

        $out .= "</tr>\n" ;
    }

    $out .= "</table>\n" ;
    return $out;
}

# ----------------------------------------------------------------------------

1;
