#!/usr/bin/perl -w

=head1 NAME

format.t

=head1 DESCRIPTION

test App::Basis::ConvertText

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=cut

use v5.14 ;
use strict ;
use warnings ;
use Try::Tiny ;
use File::Basename ;
use File::Slurp ;
use Data::Printer ;

use Test::More  ;

BEGIN { use_ok('App::Basis::ConvertText') ; }

my $story = read_file( '/home/kmulholland/src/App-Simple-ConvertText/t/input_text.md');

my $format = App::Basis::ConvertText->new( name => 'format_test', use_cache => 1) ;
my $dir = $format->cache_dir() ;
$format->clean_cache() ;
my $data = $format->parse( $story) ;
# say "$data" ;

my $file = "$dir/output.pdf" ;
my $status = $format->save_to_file( $file) ;
say "file is $file" if( $status);

# not great but while working on the tests this is fine
done_testing() ;