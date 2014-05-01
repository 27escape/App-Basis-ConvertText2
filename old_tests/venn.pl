#!/usr/bin/env perl

use 5.10.0 ;

use strict;
use warnings;
use App::Basis;
use App::Basis::ConvertText::Venn;

# 3 lists for the Venn diagram
my $text = "
one two three eight nine
three four five eight nine
one five seven nine
";

my $options = {
    legends => 'alpha beta gama',
    title   => "Venn diagram",
    scheme => 'rgb',
};

my $file = "/tmp/venn1.png" ;
$file = '/home/kmulholland/.markup/cache/markup/venn.png' ;
unlink( $file) ;
my $explain = venn( $text, $file, $options );

if( -f $file) {
    say "created $file" ;
    # say $explain ;
}
