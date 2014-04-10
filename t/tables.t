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

use Test::More  ;

BEGIN { use_ok('App::Basis::ConvertText') ; }

my $story = "# testing tables

|---|---|-----|
|one|two|three|
|one|two|three|
|one|two|three|
|one|two|three|

";

my $format = App::Basis::ConvertText->new( name => 'format_test', use_cache => 1) ;
my $dir = $format->cache_dir() ;
$format->clean_cache() ;
my $data = $format->parse( $story) ;
ok( $data =~ /<table/i, 'table created') ;

# not great but while working on the tests this is fine
done_testing() ;