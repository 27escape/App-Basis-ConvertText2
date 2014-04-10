
=head1 NAME

 App::Basis::ConvertText::ConvertFile

=head1 SYNOPSIS

 

=head1 DESCRIPTION

 convert a document from one format to another, uses pandoc and prince to do this

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertFile;

use 5.10.0;
use strict;
use warnings;
use App::Basis;
use Exporter;
use Try::Tiny;
use File::Basename qw( dirname);

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( convert_file );

use constant PANDOC => 'pandoc';
use constant PRINCE => 'prince';

# ----------------------------------------------------------------------------

BEGIN {
    my ( $r, $o, $e ) = run_cmd( PANDOC . " --help" );

    die( "Could not find " . PANDOC ) if ($r);
}

# ----------------------------------------------------------------------------

=item convert_file

create a simple msc image

 parameters
    data   - msc text      
    filename - filename to save the created sparkline image as 

=cut

sub convert_file {
    my ( $file, $format, $prince ) = @_;

    # we work on the is that pandoc should be in your PATH
    my $fmt_str = $format;
    my $outfile;
    my $cmd;

    $outfile = $file;
    $outfile =~ s/\.(\w+)$/.pdf/;

    # we can use prince to do PDF conversion, its faster and better, but not free for commercial use
    # you would have to ignore the P symbol on the resultant document
    if ( $format =~ /pdf/i && $prince ) {
        $cmd = PRINCE . " $file -o $outfile";
    }
    else {
        # otherwise lets use pandoc to create the file in the other formats
        $cmd = PANDOC . " -o $outfile $file";
    }

    my ( $exit, $out, $err );
    try {
        # say "$cmd" ;
        ( $exit, $out, $err ) = run_cmd($cmd);
    }
    catch {
        $err  = "run_cmd($cmd) died - $_";
        $exit = 1;
    };
    debug( "ERROR", $err ) if ($err);    # only debug if return code is not 0
                                          # if we failed to convert, then clear the filename
    return $exit == 0 ? $outfile : undef;
}

# ----------------------------------------------------------------------------

1;
