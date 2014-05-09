
=head1 NAME

App::Basis::ConvertText2::Plugin::YamlAsJson

=head1 SYNOPSIS

~~~~{.yamlasjson}
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
~~~~
 
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

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2::Plugin::YamlAsJson;

use 5.10.0;
use strict;
use warnings;
use YAML qw(Load);
use JSON;

use Moo;
use App::Basis::ConvertText2::Support;
use namespace::clean;

has handles => (
    is       => 'ro',
    init_arg => undef,
    default  => sub {[qw{yamlasjson}]}
);

# ----------------------------------------------------------------------------

=item yamlasjson

Convert a YAML block into a JSON block

 parameters

=cut

sub process {
    my $self = shift;
    my ( $tag, $content, $params, $cachedir ) = @_;

    $content =~ s/~~~~{\.yaml}//gsm;
    $content =~ s/~~~~//gsm;

    my $data = Load($content);
    return "\n~~~~{.json}\n" . to_json($data, {utf8 => 1, pretty => 1}) . "\n~~~~\n\n";
}

# ----------------------------------------------------------------------------

1;
