
=head1 NAME

 App::Basis::ConvertText::YamlAsJson

=head1 SYNOPSIS

<yamlasjson>
epg:
  - triplet: [1,2,3,7]
    channel: BBC3
    date: 2013-10-20
    time: 20:30
    crid: dvb://112.4a2.5ec;2d22~20131020T2030000Z—PT01H30M
  - triplet: [1,2,3,9]
    channel: BBC4
    date: 2013-11-20
    time: 21:00
    crid: dvb://112.4a2.5ec;2d22~20131120T2100000Z—PT01H30M
</yamlasjson>
 
creates 
 
~~~~{.json}
{
  "epg": [
    {
      "triplet": [ 1, 2, 3, 7 ],
      "channel": "BBC3",
      "datetime": "2013-10-20T20:30:00.000Z",
      "crid": "dvb://112.4a2.5ec;2d22~20131020T2030000Z—PT01H30M"
    },
    {
      "triplet": [  1, 2, 3, 9 ],
      "channel": "BBC4",
      "datetime": "2013-11-20T21:00:00.000Z",
      "crid": "dvb://112.4a2.5ec;2d22~20131120T2100000Z—PT01H30M"
    }
  ]
}
~~~~

=head1 DESCRIPTION

 Convert a YAML block into a JSON block for output, to be used as part of L<App::Basis::ConvertText>

=head1 AUTHOR

 kevin mulholland, moodfarm@cpan.org

=head1 VERSIONS

 v0.001

=head1 HISTORY

First created in Oct 2013

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText::YamlAsJson;

use 5.10.0;
use strict;
use warnings;
use Exporter;
use YAML qw(Load);
use JSON;

use vars qw( @EXPORT @ISA);

@ISA = qw(Exporter);

# this is the list of things that will get imported into the loading packages
# namespace
@EXPORT = qw( yamlasjson);

# ----------------------------------------------------------------------------

=item yamlasjson

Convert a YAML block into a JSON block

 parameters

=cut

sub yamlasjson
{
    my ($text) = @_;

    $text =~ s/~~~~{\.yaml}//gsm;
    $text =~ s/~~~~//gsm;

    my $data = Load($text);
    my $json = JSON->new();
    return "\n~~~~{.json}\n" . $json->pretty->encode($data) . "\n~~~~\n\n";
}

# ----------------------------------------------------------------------------

1;
