#!/usr/bin/perl -w

=head1 NAME

01_basic.t

=head1 DESCRIPTION

basic test App::Basis::ConvertText2

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=cut

use v5.10;
use strict;
use warnings;
use Path::Tiny;

use Test::More tests => 6;

BEGIN { use_ok('App::Basis::ConvertText2'); }

my $story = "# basic markdown

%TOC%

some text

## section 2

* bullets
    * bullet indented
";

my $format = App::Basis::ConvertText2->new( name => "format_test_$$", use_cache => 1 );
my $dir = $format->cache_dir();
ok( -d $dir, "Cache dir exists") ;
$format->clean_cache();
my $data = $format->parse($story);
ok( $data =~ /<h1.*?>basic/, 'basic markdown converted to HTML' );

my $file   = "$dir/output.pdf";
# make sure it does not exist
unlink( $file);
my $status = $format->save_to_file($file);
ok( $status,  "reported file saved" );
ok( -f $file, "file exists" );

$format->clean_cache();
ok( !-f $file, "file has been cleaned" );

path( $dir)->remove_tree ;
# not great but while working on the tests this is fine
done_testing();
