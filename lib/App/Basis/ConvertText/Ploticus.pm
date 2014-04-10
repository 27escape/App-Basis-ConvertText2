
=head1 NAME

 App::Basis::ConvertText::Ploticus

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 convert a ploticus text string into a PNG, requires graphviz program

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in June 1999, now updated to become App::Basis::ConvertText::Ploticus

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::Ploticus;

use 5.10.0;
use strict;
use warnings;
use App::Basis;
use File::Slurp qw( read_file write_file);
use Exporter;
use App::Basis;
use Data::Printer;
use Carp;
use Text::CSV::Slurp ;
use Try::Tiny ;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( ploticus);

# ----------------------------------------------------------------------------
use constant PLOTICUS_CMD => '/usr/bin/ploticus';

BEGIN {
    die "ploticus not where I expect it"  if ( !-x PLOTICUS_CMD );
}

# ----------------------------------------------------------------------------

my $default_color     = 'green';
my $default_delimitor = ',';

# ----------------------------------------------------------------------------
# _constrain_data
# collate data into a new array, only operates on one column of data
# also takes a constraint argument to allow restricted things to be counted
# append is what is needed to be added back to the field to fix it, ie add minutes back in
#     # to make back into a proper date string add empty seconds back
#     $>constrain_data( [data => $data, field=> 'date', contstraint => '^\d{4}/\d{2}/\d{2} \d{2}:\d{2}', append => ':00']) ;
#     # just get the date
#     $constrain_data( [data => $data, field => 'date', constraint => '^\d{4}/\d{2}/\d{2}']) ;

# we should not assume the data is in any order, though we will sort on output
# returns data matching criteria in arrayref of hashref

sub _constrain_data {
    my $args = @_ % 2 ? croak "Odd number of values passed where even is expected.\n" : {@_};
    my %matches;
    # set arg defaults
    #   $args->{field} ||= '' ;
    #   $args->{constraint} ||= '' ;
    $args->{append} ||= '';

    return {} if ( !$args->{data} || !$args->{field} );

    if ( $args->{data} ) {
        foreach my $record ( @{ $args->{data} } ) {    ### collating [...|          ] % done
            if ( !$args->{constraint} ) {
                $matches{ $args->{field} }++;
            }
            elsif ( $record->{ $args->{field} } && $record->{ $args->{field} } =~ /(?<matched>$args->{constraint})/ ) {
                $matches{"$+{matched}$args->{append}"}++;
            }
        }
    }
    # map returns list of anon hashes each of 1 entry
    return [
        map {
            { $_ => $matches{$_} }
            } sort keys %matches
    ];
}

# ----------------------------------------------------------------------------

sub _plot {
    my ( $type, $data, $params ) = @_;
    my ( $png, $csvdata );

    die "bad or no plot type supplied " if ( !$type || $type !~ /chron|dist/ );
    die "no data field supplied for dist" if ( !$params->{field} );

    # if no data then no need to continue
    if ( !scalar(@$data) ) {
        say "we have no data " . p( $data) ;
        return ;
    }

    if ( !defined $$data[0]->{ $params->{field} } ) {

        say "There is no $params->{field} data field\n";
        say "params is " .p($params) . "\ndata is "  . p($data->[0]) ;
        return;
    }

    # set some defaults if needed
    $params->{color} ||= 'red';
    my $lcount = scalar(@$data);

    my $plotcmd = PLOTICUS_CMD . " -prefab $type data=stdin delim=comma header=yes" . ' -png -o stdout ';

    given ($type) {
        when ('chron') {
            my ( $sdate, $edate ) = ( 0, time() );
            # do specifics for chron
            $plotcmd .= " barwidth=line omitweekends=no x=1 color=$params->{color} ";
            # loop through the data building up csv like data to pipe into ploticus
            foreach my $rec (@$data) {
                next if ( $rec && !$rec->{ $params->{field} } );
                # get the first date
                $sdate = $rec->{ $params->{field} } if ( !$sdate );
                # update final date
                $edate = $rec->{ $params->{field} };
                # replace space between date and time with a period
                $rec->{ $params->{field} } =~ s/\s/./;
                $csvdata .= $rec->{ $params->{field} } . "\n";
            }

            # now will try to do some clever things to determine the date/time types, the range of dates
            # and suchlike so that I can automatically add these things in

            # get range start-end in days
            my $range = int( ( str2time($edate) - str2time($sdate) ) / ( 24 * 60 * 60 ) );

            given ($range) {
                when ( [ 0 .. 7 ] ) {    # test for a week span
                    $plotcmd .= "tab=hour datefmt=yyyy-mm-dd xinc='1 day' automonths=yes xstubfmt=dd unittype=datetime";
                }
                when ( [ 8 .. 14 ] ) {    # test for a week span
                    $plotcmd .= "tab=hour datefmt=yyyy-mm-dd xinc='1 day' automonth=yes xstubfmt=dd unittype=datetime";
                }
                when ( [ 15 .. 31 ] ) {    # test for a week span
                    $plotcmd .= "tab=hour datefmt=yyyy-mm-dd xinc='2 day' xstubfmt=dd automonths=yes unittype=datetime";
                }
                when ( [ 32 .. 124 ] ) {    # month span
                    $plotcmd .= "tab=day datefmt=yyyy-mm-dd xinc='7 day' automonths=yes xstubfmt=dd unittype=datetime";
                }
                default {                   # assume big so year type span
                    $plotcmd .= "tab=day datefmt=yyyy-mm-dd xinc='31 day' automonths=yes unittype=datetime";
                }
            }
        }
        when ('dist') {
            # do specifics for dist
            $plotcmd .= " x=1 color=$params->{color} cats=yes yrange=0 stubvert=yes order=rev";
            # loop through the data building up csv like data to pipe into ploticus
            foreach my $rec (@$data) {
                next if ( $rec && !$rec->{ $params->{field} } );
                $csvdata .= $rec->{ $params->{field} } . "\n";
            }
        }
        when( 'timecard') {
            die "Something missing, lost code" ;
        }
    }

    if ($csvdata) {
        # we are going to pipe the data to ploticus using stdin
        $plotcmd .= " title='$params->{title}' " if ( $params->{title} );

        # make sure ploticus can handle the data nicely
        $lcount += 5000;
        $plotcmd .= " -maxrows $lcount -maxfields " . ( $lcount * 10 );

        # say "data is $csvdata\ncommand is $plotcmd";

        # as we have added in the execute role lets use it
        say "execute $plotcmd" ;
        my $resp = execute_cmd( command => $plotcmd, timeout => 30, child_stdin => $csvdata );
        debug( "ERROR", "problems $resp->{stderr}" ) if ( length $resp->{stderr} );
        if ( !length( $resp->{stdout} ) ) {
            debug( "ERROR", "Ploticus did not generate any $type output - maybe too many uniq fields?" );
        }
        elsif ( $resp->{exit_code} ) {
            debug( "ERROR", "ploticus failed $resp->{err_msg}" );
        }
        else {
            # only return png if there was no problems
            $png = $resp->{stdout};
        }
    }
    return $png;
}

# ----------------------------------------------------------------------------

=item ploticus

create a ploticus chart image, from the passed text

 parameters
    data   - csv data for the plot
    filename - filename to save the created image as 

    hashref params of
        title           - title for the plot
        type            - type of plot chron|dist|timecard
        color           - color of the bars etc
        delimitor       - delimitor for the data - defaults to ','
        headers         - comma separated list of new names for the csv data items
        collate_field   - if doing chron or timecard, which field in the data do we collate on
        csv             - if data is not being passed via text, read it from this CSV file

=cut

sub ploticus {
    my ( $text, $filename, $params ) = @_;
    my $created = 0;
    my $log_data;

    if ( $params->{csv} ) {
        $params->{csv} =~ s/^~/$ENV{home}/ ;
        $text = read_file( $params->{csv} );
    }

    die('valid type option required') if ( !$params->{type} || $params->{type} !~ /chron|dist/i );
    my $type = lc $params->{type};

    # set date defaults
    $params->{color}     ||= $default_color;
    $params->{delimitor} ||= $default_delimitor;
    $params->{title}     ||= '';

    $log_data = Text::CSV::Slurp->load(
        string             => $text,
        binary             => 1,
        sep_char           => $params->{delimitor},
        allow_loose_quotes => 1
    );

    if ( $log_data && scalar(@$log_data) ) {
        # say "data for $params->{title}:\n" . p($log_data);

        my @headers = sort keys %{ ${$log_data}[0] };

        # override the headers
        if ( $params->{headers} ) {
            # get headers, spaces not allowed
            @headers = map { my $h = $_ ; $h =~ s/ //g; $h; } split( /,/, $params->{headers} );
        }

        # tidy title
        $params->{title} =~ s/ to /_/;
        $params->{title} =~ s|\s|_|g;

        my $collate_field = $params->{collate_field};
        $collate_field = 'date' if ( $type eq 'chron' && !$collate_field );

        # collating date to nearest hour
        my $new_data;
        if ( $collate_field && $collate_field eq 'date') {
            $new_data = _constrain_data(
                data       => $log_data,
                field      => $collate_field,
                constraint => '^\d{4}-\d{2}-\d{2}[ |\.]\d{2}:',
                append     => '00:00'
            );
        }
        else {
            if ($collate_field) {
                $new_data = _constrain_data( data => $log_data, field => $collate_field );
            }
            else {
                say "should collate";
                $new_data      = $log_data;
                $collate_field = 'date';
                # will exit
                # die( "collate_field required, cannot process", 1);
            }
        }

        my $png ;
        try {
                $png = _plot(
                    $type,
                    $new_data,
                    {
                        field => $collate_field,
                        title => $params->{title},
                        color => $params->{color}
                    }
                );
        } catch {
            say "something went wrong $_ " ;
        } ;
        if ($png) {

            # override created filename
            $created = 1 if ( write_file( $filename, $png ) );
        }
    } else {
        say "failed to load data " ;
    }
    return $created;
}

# ----------------------------------------------------------------------------
1;
