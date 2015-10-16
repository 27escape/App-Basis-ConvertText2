
=head1 NAME

App::Basis::ConvertText2

=head1 SYNOPSIS

To be used in conjuction with the supplied ct2 script, which is part of this distribution.
Not really to be used on its own.

=head1 DESCRIPTION

This is a perl module and a script that makes use of %TITLE%

This is a wrapper for [pandoc] implementing extra fenced code-blocks to allow the
creation of charts and graphs etc.
Documents may be created a variety of formats. If you want to create nice PDFs
then it can use [PrinceXML] to generate great looking PDFs or you can use [wkhtmltopdf] to create PDFs that are almost as good, the default is to use pandoc which, for me, does not work as well.

HTML templates can also be used to control the layout of your documents.

The fenced code block handlers are implemented as plugins and it is a simple process to add new ones.

There are plugins to handle

    * ditaa
    * mscgen
    * graphviz
    * uml
    * gnuplot
    * gle
    * sparklines
    * charts
    * barcodes and qrcodes
    * and many others

See
https://github.com/27escape/App-Basis-ConvertText2/blob/master/README.md
for more information.

=head1 Todo

Consider adding plugins for

    * https://metacpan.org/pod/Chart::Strip
    * https://metacpan.org/pod/Chart::Clicker

Possibly create something for D3.js, though this would need to use PhantomJS too
https://github.com/ariya/phantomjs/blob/master/examples/rasterize.js
http://stackoverflow.com/questions/18240391/exporting-d3-js-graphs-to-static-svg-files-programmatically

=head1 Public methods

=over 4

=cut

# ----------------------------------------------------------------------------

package App::Basis::ConvertText2 ;

use 5.10.0 ;
use strict ;
use warnings ;
use feature 'state' ;
use Moo ;
use Data::Printer ;
use Try::Tiny ;
use Path::Tiny ;
use Digest::MD5 qw(md5_hex) ;
use Encode qw(encode_utf8) ;
use GD ;
use MIME::Base64 ;
use Furl ;
use POSIX qw(strftime) ;
use Module::Pluggable
    require          => 1,
    on_require_error => sub {
    my ( $plugin, $err ) = @_ ;
    warn "$plugin, $err" ;
    } ;
use App::Basis ;
use App::Basis::ConvertText2::Support ;
use utf8::all ;

# ----------------------------------------------------------------------------
# this contents string is to be replaced with the body of the markdown file
# when it has been converted
use constant CONTENTS => '_CONTENTS_' ;
use constant PANDOC   => 'pandoc' ;
use constant PRINCE   => 'prince' ;
use constant WKHTML   => 'wkhtmltopdf' ;

# ----------------------------------------------------------------------------

# http://www.fileformat.info/info/unicode/category/So/list.htm
# not great matches in all cases but best that can be done when there is no support
# for emoji's
my %smilies = (
    '<3'      => ":fa:heart",    # heart
    ':heart:' => ":fa:heart",    # heart
    ':)'      => ":fa:smile-o",  # smile
    ':smile:' => ":fa:smile-o",  # smile
                                 # ':D'           => "\x{1f601}",    # grin
                                 # ':grin:'       => "\x{1f601}",    # grin
                                 # '8-)'     => "\x{1f60e}",      # 😎, cool
                                 # ':cool:'       => "\x{1f60e}",    # cool
         # ':P'           => "\x{1f61b}",    # pull tounge
         # ':tongue:'     => "\x{1f61b}",    # pull tounge
         # ":'("          => "\x{1f62d}",    # cry
         # ":cry:"        => "\x{1f62d}",    # cry
    ':('       => ":fa:frown-o",    # sad
    ':sad:'    => ":fa:frown-o",    # sad
                                    # ";)"      => "\x{1f609}",    # wink
                                    # ":wink:"  => "\x{1f609}",      # wink
    ":sleep:"  => ":fa:bed",        # sleep
    ":zzz:"    => ":mi:snooze",     # snooze
    ":snooze:" => ":mi:snooze",     # snooze
                                    # ":halo:"       => "\x{1f607}",    # halo
         # ":devil:"  => "\x{1f608}",     # 😈, devil
         # ":imp:"  => "\x{1f608}",     # 😈, devil
         # ":horns:"      => "\x{1f608}",    # devil
         # ":fear:"  => "\x{1f631}",      # fear
    "(c)"          => "\x{a9}",                       # copyright
    ":c:"          => "\x{a9}",                       # copyright
    ":copyright:"  => "\x{a9}",                       # copyright
    "(r)"          => "\x{ae}",                       # registered
    ":r:"          => "\x{ae}",                       # registered
    ":registered:" => "\x{ae}",                       # registered
    "(tm)"         => "\x{99}",                       # trademark
    ":tm:"         => "\x{99}",                       # trademark
    ":trademark:"  => "\x{99}",                       # trademark
    ":email:"      => ":fa:envelope-o",               # email
    ":yes:"        => "\x{2714}",                     # tick / check
    ":no:"         => "\x{2718}",                     # cross
    ":beer:"       => ":fa:beer:[fliph]",             # beer
    ":wine:"       => ":fa:glass",                    # wine
    ":glass:"      => ":fa:glass",                    # wine
    ":cake:"       => ":fa:birthday-cake",            # cake
    ":star:"       => ":fa:star-o",                   # star
    ":ok:"         => ":fa:thumbs-o-up:[fliph]",      # ok = thumbsup
    ":thumbsup:"   => ":fa:thumbs-o-up:[fliph]",      # thumbsup
    ":thumbsdown:" => ":fa:thumbs-o-down:[fliph]",    # thumbsdown
    ":bad:"        => ":fa:thumbs-o-down:[fliph]",    # bad = thumbsdown
         # ":ghost:"      => "\x{1f47b}",            # ghost
         # ":skull:"      => "\x{1f480}",            # skull 1f480
    ":time:"      => ":fa:clock-o",        # time, watch face
    ":clock:"     => ":fa:clock-o",        # time, watch face
    ":hourglass:" => ":fa:hourglass-o",    # hourglass

    ":bowtie:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bowtie.png"> />',

) ;


my %emoji_cheatsheet = (
    ":bowtie:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bowtie.png"> />',
    ":smile:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/smile.png"> />',
    ":laughing:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/laughing.png"> />',
    ":blush:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/blush.png"> />',
    ":smiley:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/smiley.png"> />',
    ":relaxed:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/relaxed.png"> />',
    ":smirk:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/smirk.png"> />',
    ":heart_eyes:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heart_eyes.png"> />',
    ":kissing_heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/kissing_heart.png"> />',
    ":kissing_closed_eyes:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/kissing_closed_eyes.png"> />',
    ":flushed:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/flushed.png"> />',
    ":relieved:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/relieved.png"> />',
    ":satisfied:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/satisfied.png"> />',
    ":grin:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/grin.png"> />',
    ":wink:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wink.png"> />',
    ":stuck_out_tongue_winking_eye:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/stuck_out_tongue_winking_eye.png"> />',
    ":stuck_out_tongue_closed_eyes:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/stuck_out_tongue_closed_eyes.png"> />',
    ":grinning:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/grinning.png"> />',
    ":kissing:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/kissing.png"> />',
    ":kissing_smiling_eyes:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/kissing_smiling_eyes.png"> />',
    ":stuck_out_tongue:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/stuck_out_tongue.png"> />',
    ":sleeping:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sleeping.png"> />',
    ":worried:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/worried.png"> />',
    ":frowning:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/frowning.png"> />',
    ":anguished:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/anguished.png"> />',
    ":open_mouth:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/open_mouth.png"> />',
    ":grimacing:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/grimacing.png"> />',
    ":confused:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/confused.png"> />',
    ":hushed:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hushed.png"> />',
    ":expressionless:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/expressionless.png"> />',
    ":unamused:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/unamused.png"> />',
    ":sweat_smile:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sweat_smile.png"> />',
    ":sweat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sweat.png"> />',
    ":disappointed_relieved:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/disappointed_relieved.png"> />',
    ":weary:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/weary.png"> />',
    ":pensive:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pensive.png"> />',
    ":disappointed:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/disappointed.png"> />',
    ":confounded:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/confounded.png"> />',
    ":fearful:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fearful.png"> />',
    ":cold_sweat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cold_sweat.png"> />',
    ":persevere:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/persevere.png"> />',
    ":cry:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cry.png"> />',
    ":sob:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sob.png"> />',
    ":joy:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/joy.png"> />',
    ":astonished:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/astonished.png"> />',
    ":scream:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/scream.png"> />',
    ":neckbeard:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/neckbeard.png"> />',
    ":tired_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tired_face.png"> />',
    ":angry:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/angry.png"> />',
    ":rage:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rage.png"> />',
    ":triumph:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/triumph.png"> />',
    ":sleepy:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sleepy.png"> />',
    ":yum:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/yum.png"> />',
    ":mask:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mask.png"> />',
    ":sunglasses:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sunglasses.png"> />',
    ":dizzy_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dizzy_face.png"> />',
    ":imp:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/imp.png"> />',
    ":smiling_imp:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/smiling_imp.png"> />',
    ":neutral_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/neutral_face.png"> />',
    ":no_mouth:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/no_mouth.png"> />',
    ":innocent:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/innocent.png"> />',
    ":alien:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/alien.png"> />',
    ":yellow_heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/yellow_heart.png"> />',
    ":blue_heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/blue_heart.png"> />',
    ":purple_heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/purple_heart.png"> />',
    ":heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heart.png"> />',
    ":green_heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/green_heart.png"> />',
    ":broken_heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/broken_heart.png"> />',
    ":heartbeat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heartbeat.png"> />',
    ":heartpulse:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heartpulse.png"> />',
    ":two_hearts:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/two_hearts.png"> />',
    ":revolving_hearts:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/revolving_hearts.png"> />',
    ":cupid:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cupid.png"> />',
    ":sparkling_heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sparkling_heart.png"> />',
    ":sparkles:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sparkles.png"> />',
    ":star:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/star.png"> />',
    ":star2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/star2.png"> />',
    ":dizzy:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dizzy.png"> />',
    ":boom:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/boom.png"> />',
    ":collision:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/collision.png"> />',
    ":anger:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/anger.png"> />',
    ":exclamation:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/exclamation.png"> />',
    ":question:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/question.png"> />',
    ":grey_exclamation:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/grey_exclamation.png"> />',
    ":grey_question:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/grey_question.png"> />',
    ":zzz:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/zzz.png"> />',
    ":dash:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dash.png"> />',
    ":sweat_drops:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sweat_drops.png"> />',
    ":notes:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/notes.png"> />',
    ":musical_note:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/musical_note.png"> />',
    ":fire:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fire.png"> />',
    ":hankey:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hankey.png"> />',
    ":poop:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/poop.png"> />',
    ":shit:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/shit.png"> />',
    ":+1:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/plus1.png"> />',
    ":thumbsup:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/thumbsup.png"> />',
    ":-1:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/-1.png"> />',
    ":thumbsdown:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/thumbsdown.png"> />',
    ":ok_hand:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ok_hand.png"> />',
    ":punch:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/punch.png"> />',
    ":facepunch:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/facepunch.png"> />',
    ":fist:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fist.png"> />',
    ":v:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/v.png"> />',
    ":wave:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wave.png"> />',
    ":hand:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hand.png"> />',
    ":raised_hand:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/raised_hand.png"> />',
    ":open_hands:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/open_hands.png"> />',
    ":point_up:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/point_up.png"> />',
    ":point_down:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/point_down.png"> />',
    ":point_left:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/point_left.png"> />',
    ":point_right:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/point_right.png"> />',
    ":raised_hands:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/raised_hands.png"> />',
    ":pray:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pray.png"> />',
    ":point_up_2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/point_up_2.png"> />',
    ":clap:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clap.png"> />',
    ":muscle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/muscle.png"> />',
    ":metal:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/metal.png"> />',
    ":fu:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fu.png"> />',
    ":runner:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/runner.png"> />',
    ":running:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/running.png"> />',
    ":couple:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/couple.png"> />',
    ":family:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/family.png"> />',
    ":two_men_holding_hands:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/two_men_holding_hands.png"> />',
    ":two_women_holding_hands:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/two_women_holding_hands.png"> />',
    ":dancer:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dancer.png"> />',
    ":dancers:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dancers.png"> />',
    ":ok_woman:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ok_woman.png"> />',
    ":no_good:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/no_good.png"> />',
    ":information_desk_person:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/information_desk_person.png"> />',
    ":raising_hand:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/raising_hand.png"> />',
    ":bride_with_veil:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bride_with_veil.png"> />',
    ":person_with_pouting_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/person_with_pouting_face.png"> />',
    ":person_frowning:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/person_frowning.png"> />',
    ":bow:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bow.png"> />',
    ":couplekiss:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/couplekiss.png"> />',
    ":couple_with_heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/couple_with_heart.png"> />',
    ":massage:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/massage.png"> />',
    ":haircut:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/haircut.png"> />',
    ":nail_care:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/nail_care.png"> />',
    ":boy:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/boy.png"> />',
    ":girl:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/girl.png"> />',
    ":woman:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/woman.png"> />',
    ":man:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/man.png"> />',
    ":baby:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/baby.png"> />',
    ":older_woman:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/older_woman.png"> />',
    ":older_man:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/older_man.png"> />',
    ":person_with_blond_hair:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/person_with_blond_hair.png"> />',
    ":man_with_gua_pi_mao:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/man_with_gua_pi_mao.png"> />',
    ":man_with_turban:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/man_with_turban.png"> />',
    ":construction_worker:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/construction_worker.png"> />',
    ":cop:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cop.png"> />',
    ":angel:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/angel.png"> />',
    ":princess:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/princess.png"> />',
    ":smiley_cat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/smiley_cat.png"> />',
    ":smile_cat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/smile_cat.png"> />',
    ":heart_eyes_cat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heart_eyes_cat.png"> />',
    ":kissing_cat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/kissing_cat.png"> />',
    ":smirk_cat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/smirk_cat.png"> />',
    ":scream_cat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/scream_cat.png"> />',
    ":crying_cat_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/crying_cat_face.png"> />',
    ":joy_cat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/joy_cat.png"> />',
    ":pouting_cat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pouting_cat.png"> />',
    ":japanese_ogre:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/japanese_ogre.png"> />',
    ":japanese_goblin:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/japanese_goblin.png"> />',
    ":see_no_evil:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/see_no_evil.png"> />',
    ":hear_no_evil:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hear_no_evil.png"> />',
    ":speak_no_evil:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/speak_no_evil.png"> />',
    ":guardsman:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/guardsman.png"> />',
    ":skull:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/skull.png"> />',
    ":feet:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/feet.png"> />',
    ":lips:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/lips.png"> />',
    ":kiss:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/kiss.png"> />',
    ":droplet:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/droplet.png"> />',
    ":ear:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ear.png"> />',
    ":eyes:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/eyes.png"> />',
    ":nose:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/nose.png"> />',
    ":tongue:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tongue.png"> />',
    ":love_letter:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/love_letter.png"> />',
    ":bust_in_silhouette:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bust_in_silhouette.png"> />',
    ":busts_in_silhouette:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/busts_in_silhouette.png"> />',
    ":speech_balloon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/speech_balloon.png"> />',
    ":thought_balloon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/thought_balloon.png"> />',
    ":feelsgood:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/feelsgood.png"> />',
    ":finnadie:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/finnadie.png"> />',
    ":goberserk:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/goberserk.png"> />',
    ":godmode:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/godmode.png"> />',
    ":hurtrealbad:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hurtrealbad.png"> />',
    ":rage1:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rage1.png"> />',
    ":rage2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rage2.png"> />',
    ":rage3:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rage3.png"> />',
    ":rage4:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rage4.png"> />',
    ":suspect:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/suspect.png"> />',
    ":trollface:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/trollface.png"> />',
    ":sunny:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sunny.png"> />',
    ":umbrella:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/umbrella.png"> />',
    ":cloud:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cloud.png"> />',
    ":snowflake:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/snowflake.png"> />',
    ":snowman:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/snowman.png"> />',
    ":zap:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/zap.png"> />',
    ":cyclone:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cyclone.png"> />',
    ":foggy:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/foggy.png"> />',
    ":ocean:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ocean.png"> />',
    ":cat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cat.png"> />',
    ":dog:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dog.png"> />',
    ":mouse:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mouse.png"> />',
    ":hamster:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hamster.png"> />',
    ":rabbit:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rabbit.png"> />',
    ":wolf:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wolf.png"> />',
    ":frog:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/frog.png"> />',
    ":tiger:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tiger.png"> />',
    ":koala:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/koala.png"> />',
    ":bear:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bear.png"> />',
    ":pig:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pig.png"> />',
    ":pig_nose:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pig_nose.png"> />',
    ":cow:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cow.png"> />',
    ":boar:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/boar.png"> />',
    ":monkey_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/monkey_face.png"> />',
    ":monkey:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/monkey.png"> />',
    ":horse:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/horse.png"> />',
    ":racehorse:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/racehorse.png"> />',
    ":camel:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/camel.png"> />',
    ":sheep:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sheep.png"> />',
    ":elephant:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/elephant.png"> />',
    ":panda_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/panda_face.png"> />',
    ":snake:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/snake.png"> />',
    ":bird:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bird.png"> />',
    ":baby_chick:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/baby_chick.png"> />',
    ":hatched_chick:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hatched_chick.png"> />',
    ":hatching_chick:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hatching_chick.png"> />',
    ":chicken:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/chicken.png"> />',
    ":penguin:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/penguin.png"> />',
    ":turtle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/turtle.png"> />',
    ":bug:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bug.png"> />',
    ":honeybee:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/honeybee.png"> />',
    ":ant:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ant.png"> />',
    ":beetle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/beetle.png"> />',
    ":snail:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/snail.png"> />',
    ":octopus:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/octopus.png"> />',
    ":tropical_fish:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tropical_fish.png"> />',
    ":fish:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fish.png"> />',
    ":whale:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/whale.png"> />',
    ":whale2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/whale2.png"> />',
    ":dolphin:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dolphin.png"> />',
    ":cow2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cow2.png"> />',
    ":ram:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ram.png"> />',
    ":rat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rat.png"> />',
    ":water_buffalo:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/water_buffalo.png"> />',
    ":tiger2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tiger2.png"> />',
    ":rabbit2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rabbit2.png"> />',
    ":dragon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dragon.png"> />',
    ":goat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/goat.png"> />',
    ":rooster:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rooster.png"> />',
    ":dog2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dog2.png"> />',
    ":pig2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pig2.png"> />',
    ":mouse2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mouse2.png"> />',
    ":ox:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ox.png"> />',
    ":dragon_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dragon_face.png"> />',
    ":blowfish:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/blowfish.png"> />',
    ":crocodile:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/crocodile.png"> />',
    ":dromedary_camel:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dromedary_camel.png"> />',
    ":leopard:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/leopard.png"> />',
    ":cat2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cat2.png"> />',
    ":poodle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/poodle.png"> />',
    ":paw_prints:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/paw_prints.png"> />',
    ":bouquet:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bouquet.png"> />',
    ":cherry_blossom:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cherry_blossom.png"> />',
    ":tulip:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tulip.png"> />',
    ":four_leaf_clover:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/four_leaf_clover.png"> />',
    ":rose:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rose.png"> />',
    ":sunflower:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sunflower.png"> />',
    ":hibiscus:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hibiscus.png"> />',
    ":maple_leaf:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/maple_leaf.png"> />',
    ":leaves:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/leaves.png"> />',
    ":fallen_leaf:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fallen_leaf.png"> />',
    ":herb:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/herb.png"> />',
    ":mushroom:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mushroom.png"> />',
    ":cactus:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cactus.png"> />',
    ":palm_tree:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/palm_tree.png"> />',
    ":evergreen_tree:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/evergreen_tree.png"> />',
    ":deciduous_tree:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/deciduous_tree.png"> />',
    ":chestnut:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/chestnut.png"> />',
    ":seedling:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/seedling.png"> />',
    ":blossom:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/blossom.png"> />',
    ":ear_of_rice:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ear_of_rice.png"> />',
    ":shell:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/shell.png"> />',
    ":globe_with_meridians:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/globe_with_meridians.png"> />',
    ":sun_with_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sun_with_face.png"> />',
    ":full_moon_with_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/full_moon_with_face.png"> />',
    ":new_moon_with_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/new_moon_with_face.png"> />',
    ":new_moon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/new_moon.png"> />',
    ":waxing_crescent_moon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/waxing_crescent_moon.png"> />',
    ":first_quarter_moon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/first_quarter_moon.png"> />',
    ":waxing_gibbous_moon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/waxing_gibbous_moon.png"> />',
    ":full_moon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/full_moon.png"> />',
    ":waning_gibbous_moon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/waning_gibbous_moon.png"> />',
    ":last_quarter_moon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/last_quarter_moon.png"> />',
    ":waning_crescent_moon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/waning_crescent_moon.png"> />',
    ":last_quarter_moon_with_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/last_quarter_moon_with_face.png"> />',
    ":first_quarter_moon_with_face:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/first_quarter_moon_with_face.png"> />',
    ":crescent_moon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/crescent_moon.png"> />',
    ":earth_africa:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/earth_africa.png"> />',
    ":earth_americas:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/earth_americas.png"> />',
    ":earth_asia:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/earth_asia.png"> />',
    ":volcano:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/volcano.png"> />',
    ":milky_way:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/milky_way.png"> />',
    ":partly_sunny:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/partly_sunny.png"> />',
    ":octocat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/octocat.png"> />',
    ":squirrel:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/squirrel.png"> />',
    ":bamboo:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bamboo.png"> />',
    ":gift_heart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/gift_heart.png"> />',
    ":dolls:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dolls.png"> />',
    ":school_satchel:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/school_satchel.png"> />',
    ":mortar_board:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mortar_board.png"> />',
    ":flags:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/flags.png"> />',
    ":fireworks:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fireworks.png"> />',
    ":sparkler:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sparkler.png"> />',
    ":wind_chime:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wind_chime.png"> />',
    ":rice_scene:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rice_scene.png"> />',
    ":jack_o_lantern:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/jack_o_lantern.png"> />',
    ":ghost:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ghost.png"> />',
    ":santa:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/santa.png"> />',
    ":christmas_tree:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/christmas_tree.png"> />',
    ":gift:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/gift.png"> />',
    ":bell:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bell.png"> />',
    ":no_bell:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/no_bell.png"> />',
    ":tanabata_tree:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tanabata_tree.png"> />',
    ":tada:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tada.png"> />',
    ":confetti_ball:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/confetti_ball.png"> />',
    ":balloon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/balloon.png"> />',
    ":crystal_ball:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/crystal_ball.png"> />',
    ":cd:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cd.png"> />',
    ":dvd:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dvd.png"> />',
    ":floppy_disk:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/floppy_disk.png"> />',
    ":camera:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/camera.png"> />',
    ":video_camera:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/video_camera.png"> />',
    ":movie_camera:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/movie_camera.png"> />',
    ":computer:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/computer.png"> />',
    ":tv:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tv.png"> />',
    ":iphone:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/iphone.png"> />',
    ":phone:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/phone.png"> />',
    ":telephone:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/telephone.png"> />',
    ":telephone_receiver:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/telephone_receiver.png"> />',
    ":pager:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pager.png"> />',
    ":fax:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fax.png"> />',
    ":minidisc:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/minidisc.png"> />',
    ":vhs:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/vhs.png"> />',
    ":sound:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sound.png"> />',
    ":speaker:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/speaker.png"> />',
    ":mute:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mute.png"> />',
    ":loudspeaker:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/loudspeaker.png"> />',
    ":mega:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mega.png"> />',
    ":hourglass:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hourglass.png"> />',
    ":hourglass_flowing_sand:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hourglass_flowing_sand.png"> />',
    ":alarm_clock:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/alarm_clock.png"> />',
    ":watch:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/watch.png"> />',
    ":radio:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/radio.png"> />',
    ":satellite:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/satellite.png"> />',
    ":loop:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/loop.png"> />',
    ":mag:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mag.png"> />',
    ":mag_right:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mag_right.png"> />',
    ":unlock:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/unlock.png"> />',
    ":lock:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/lock.png"> />',
    ":lock_with_ink_pen:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/lock_with_ink_pen.png"> />',
    ":closed_lock_with_key:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/closed_lock_with_key.png"> />',
    ":key:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/key.png"> />',
    ":bulb:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bulb.png"> />',
    ":flashlight:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/flashlight.png"> />',
    ":high_brightness:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/high_brightness.png"> />',
    ":low_brightness:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/low_brightness.png"> />',
    ":electric_plug:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/electric_plug.png"> />',
    ":battery:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/battery.png"> />',
    ":calling:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/calling.png"> />',
    ":email:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/email.png"> />',
    ":mailbox:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mailbox.png"> />',
    ":postbox:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/postbox.png"> />',
    ":bath:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bath.png"> />',
    ":bathtub:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bathtub.png"> />',
    ":shower:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/shower.png"> />',
    ":toilet:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/toilet.png"> />',
    ":wrench:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wrench.png"> />',
    ":nut_and_bolt:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/nut_and_bolt.png"> />',
    ":hammer:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hammer.png"> />',
    ":seat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/seat.png"> />',
    ":moneybag:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/moneybag.png"> />',
    ":yen:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/yen.png"> />',
    ":dollar:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dollar.png"> />',
    ":pound:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pound.png"> />',
    ":euro:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/euro.png"> />',
    ":credit_card:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/credit_card.png"> />',
    ":money_with_wings:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/money_with_wings.png"> />',
    ":e-mail:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/e-mail.png"> />',
    ":inbox_tray:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/inbox_tray.png"> />',
    ":outbox_tray:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/outbox_tray.png"> />',
    ":envelope:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/envelope.png"> />',
    ":incoming_envelope:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/incoming_envelope.png"> />',
    ":postal_horn:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/postal_horn.png"> />',
    ":mailbox_closed:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mailbox_closed.png"> />',
    ":mailbox_with_mail:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mailbox_with_mail.png"> />',
    ":mailbox_with_no_mail:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mailbox_with_no_mail.png"> />',
    ":package:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/package.png"> />',
    ":door:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/door.png"> />',
    ":smoking:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/smoking.png"> />',
    ":bomb:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bomb.png"> />',
    ":gun:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/gun.png"> />',
    ":hocho:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hocho.png"> />',
    ":pill:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pill.png"> />',
    ":syringe:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/syringe.png"> />',
    ":page_facing_up:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/page_facing_up.png"> />',
    ":page_with_curl:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/page_with_curl.png"> />',
    ":bookmark_tabs:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bookmark_tabs.png"> />',
    ":bar_chart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bar_chart.png"> />',
    ":chart_with_upwards_trend:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/chart_with_upwards_trend.png"> />',
    ":chart_with_downwards_trend:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/chart_with_downwards_trend.png"> />',
    ":scroll:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/scroll.png"> />',
    ":clipboard:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clipboard.png"> />',
    ":calendar:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/calendar.png"> />',
    ":date:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/date.png"> />',
    ":card_index:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/card_index.png"> />',
    ":file_folder:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/file_folder.png"> />',
    ":open_file_folder:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/open_file_folder.png"> />',
    ":scissors:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/scissors.png"> />',
    ":pushpin:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pushpin.png"> />',
    ":paperclip:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/paperclip.png"> />',
    ":black_nib:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/black_nib.png"> />',
    ":pencil2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pencil2.png"> />',
    ":straight_ruler:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/straight_ruler.png"> />',
    ":triangular_ruler:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/triangular_ruler.png"> />',
    ":closed_book:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/closed_book.png"> />',
    ":green_book:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/green_book.png"> />',
    ":blue_book:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/blue_book.png"> />',
    ":orange_book:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/orange_book.png"> />',
    ":notebook:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/notebook.png"> />',
    ":notebook_with_decorative_cover:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/notebook_with_decorative_cover.png"> />',
    ":ledger:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ledger.png"> />',
    ":books:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/books.png"> />',
    ":bookmark:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bookmark.png"> />',
    ":name_badge:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/name_badge.png"> />',
    ":microscope:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/microscope.png"> />',
    ":telescope:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/telescope.png"> />',
    ":newspaper:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/newspaper.png"> />',
    ":football:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/football.png"> />',
    ":basketball:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/basketball.png"> />',
    ":soccer:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/soccer.png"> />',
    ":baseball:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/baseball.png"> />',
    ":tennis:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tennis.png"> />',
    ":8ball:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/8ball.png"> />',
    ":rugby_football:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rugby_football.png"> />',
    ":bowling:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bowling.png"> />',
    ":golf:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/golf.png"> />',
    ":mountain_bicyclist:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mountain_bicyclist.png"> />',
    ":bicyclist:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bicyclist.png"> />',
    ":horse_racing:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/horse_racing.png"> />',
    ":snowboarder:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/snowboarder.png"> />',
    ":swimmer:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/swimmer.png"> />',
    ":surfer:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/surfer.png"> />',
    ":ski:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ski.png"> />',
    ":spades:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/spades.png"> />',
    ":hearts:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hearts.png"> />',
    ":clubs:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clubs.png"> />',
    ":diamonds:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/diamonds.png"> />',
    ":gem:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/gem.png"> />',
    ":ring:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ring.png"> />',
    ":trophy:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/trophy.png"> />',
    ":musical_score:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/musical_score.png"> />',
    ":musical_keyboard:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/musical_keyboard.png"> />',
    ":violin:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/violin.png"> />',
    ":space_invader:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/space_invader.png"> />',
    ":video_game:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/video_game.png"> />',
    ":black_joker:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/black_joker.png"> />',
    ":flower_playing_cards:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/flower_playing_cards.png"> />',
    ":game_die:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/game_die.png"> />',
    ":dart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dart.png"> />',
    ":mahjong:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mahjong.png"> />',
    ":clapper:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clapper.png"> />',
    ":memo:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/memo.png"> />',
    ":pencil:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pencil.png"> />',
    ":book:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/book.png"> />',
    ":art:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/art.png"> />',
    ":microphone:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/microphone.png"> />',
    ":headphones:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/headphones.png"> />',
    ":trumpet:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/trumpet.png"> />',
    ":saxophone:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/saxophone.png"> />',
    ":guitar:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/guitar.png"> />',
    ":shoe:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/shoe.png"> />',
    ":sandal:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sandal.png"> />',
    ":high_heel:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/high_heel.png"> />',
    ":lipstick:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/lipstick.png"> />',
    ":boot:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/boot.png"> />',
    ":shirt:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/shirt.png"> />',
    ":tshirt:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tshirt.png"> />',
    ":necktie:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/necktie.png"> />',
    ":womans_clothes:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/womans_clothes.png"> />',
    ":dress:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dress.png"> />',
    ":running_shirt_with_sash:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/running_shirt_with_sash.png"> />',
    ":jeans:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/jeans.png"> />',
    ":kimono:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/kimono.png"> />',
    ":bikini:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bikini.png"> />',
    ":ribbon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ribbon.png"> />',
    ":tophat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tophat.png"> />',
    ":crown:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/crown.png"> />',
    ":womans_hat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/womans_hat.png"> />',
    ":mans_shoe:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mans_shoe.png"> />',
    ":closed_umbrella:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/closed_umbrella.png"> />',
    ":briefcase:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/briefcase.png"> />',
    ":handbag:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/handbag.png"> />',
    ":pouch:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pouch.png"> />',
    ":purse:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/purse.png"> />',
    ":eyeglasses:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/eyeglasses.png"> />',
    ":fishing_pole_and_fish:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fishing_pole_and_fish.png"> />',
    ":coffee:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/coffee.png"> />',
    ":tea:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tea.png"> />',
    ":sake:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sake.png"> />',
    ":baby_bottle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/baby_bottle.png"> />',
    ":beer:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/beer.png"> />',
    ":beers:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/beers.png"> />',
    ":cocktail:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cocktail.png"> />',
    ":tropical_drink:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tropical_drink.png"> />',
    ":wine_glass:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wine_glass.png"> />',
    ":fork_and_knife:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fork_and_knife.png"> />',
    ":pizza:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pizza.png"> />',
    ":hamburger:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hamburger.png"> />',
    ":fries:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fries.png"> />',
    ":poultry_leg:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/poultry_leg.png"> />',
    ":meat_on_bone:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/meat_on_bone.png"> />',
    ":spaghetti:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/spaghetti.png"> />',
    ":curry:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/curry.png"> />',
    ":fried_shrimp:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fried_shrimp.png"> />',
    ":bento:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bento.png"> />',
    ":sushi:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sushi.png"> />',
    ":fish_cake:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fish_cake.png"> />',
    ":rice_ball:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rice_ball.png"> />',
    ":rice_cracker:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rice_cracker.png"> />',
    ":rice:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rice.png"> />',
    ":ramen:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ramen.png"> />',
    ":stew:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/stew.png"> />',
    ":oden:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/oden.png"> />',
    ":dango:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/dango.png"> />',
    ":egg:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/egg.png"> />',
    ":bread:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bread.png"> />',
    ":doughnut:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/doughnut.png"> />',
    ":custard:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/custard.png"> />',
    ":icecream:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/icecream.png"> />',
    ":ice_cream:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ice_cream.png"> />',
    ":shaved_ice:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/shaved_ice.png"> />',
    ":birthday:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/birthday.png"> />',
    ":cake:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cake.png"> />',
    ":cookie:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cookie.png"> />',
    ":chocolate_bar:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/chocolate_bar.png"> />',
    ":candy:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/candy.png"> />',
    ":lollipop:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/lollipop.png"> />',
    ":honey_pot:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/honey_pot.png"> />',
    ":apple:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/apple.png"> />',
    ":green_apple:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/green_apple.png"> />',
    ":tangerine:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tangerine.png"> />',
    ":lemon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/lemon.png"> />',
    ":cherries:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cherries.png"> />',
    ":grapes:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/grapes.png"> />',
    ":watermelon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/watermelon.png"> />',
    ":strawberry:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/strawberry.png"> />',
    ":peach:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/peach.png"> />',
    ":melon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/melon.png"> />',
    ":banana:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/banana.png"> />',
    ":pear:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pear.png"> />',
    ":pineapple:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pineapple.png"> />',
    ":sweet_potato:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sweet_potato.png"> />',
    ":eggplant:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/eggplant.png"> />',
    ":tomato:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tomato.png"> />',
    ":corn:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/corn.png"> />',
    ":house:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/house.png"> />',
    ":house_with_garden:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/house_with_garden.png"> />',
    ":school:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/school.png"> />',
    ":office:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/office.png"> />',
    ":post_office:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/post_office.png"> />',
    ":hospital:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hospital.png"> />',
    ":bank:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bank.png"> />',
    ":convenience_store:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/convenience_store.png"> />',
    ":love_hotel:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/love_hotel.png"> />',
    ":hotel:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hotel.png"> />',
    ":wedding:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wedding.png"> />',
    ":church:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/church.png"> />',
    ":department_store:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/department_store.png"> />',
    ":european_post_office:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/european_post_office.png"> />',
    ":city_sunrise:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/city_sunrise.png"> />',
    ":city_sunset:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/city_sunset.png"> />',
    ":japanese_castle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/japanese_castle.png"> />',
    ":european_castle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/european_castle.png"> />',
    ":tent:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tent.png"> />',
    ":factory:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/factory.png"> />',
    ":tokyo_tower:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tokyo_tower.png"> />',
    ":japan:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/japan.png"> />',
    ":mount_fuji:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mount_fuji.png"> />',
    ":sunrise_over_mountains:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sunrise_over_mountains.png"> />',
    ":sunrise:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sunrise.png"> />',
    ":stars:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/stars.png"> />',
    ":statue_of_liberty:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/statue_of_liberty.png"> />',
    ":bridge_at_night:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bridge_at_night.png"> />',
    ":carousel_horse:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/carousel_horse.png"> />',
    ":rainbow:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rainbow.png"> />',
    ":ferris_wheel:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ferris_wheel.png"> />',
    ":fountain:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fountain.png"> />',
    ":roller_coaster:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/roller_coaster.png"> />',
    ":ship:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ship.png"> />',
    ":speedboat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/speedboat.png"> />',
    ":boat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/boat.png"> />',
    ":sailboat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sailboat.png"> />',
    ":rowboat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rowboat.png"> />',
    ":anchor:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/anchor.png"> />',
    ":rocket:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rocket.png"> />',
    ":airplane:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/airplane.png"> />',
    ":helicopter:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/helicopter.png"> />',
    ":steam_locomotive:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/steam_locomotive.png"> />',
    ":tram:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tram.png"> />',
    ":mountain_railway:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mountain_railway.png"> />',
    ":bike:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bike.png"> />',
    ":aerial_tramway:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/aerial_tramway.png"> />',
    ":suspension_railway:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/suspension_railway.png"> />',
    ":mountain_cableway:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mountain_cableway.png"> />',
    ":tractor:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tractor.png"> />',
    ":blue_car:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/blue_car.png"> />',
    ":oncoming_automobile:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/oncoming_automobile.png"> />',
    ":car:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/car.png"> />',
    ":red_car:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/red_car.png"> />',
    ":taxi:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/taxi.png"> />',
    ":oncoming_taxi:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/oncoming_taxi.png"> />',
    ":articulated_lorry:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/articulated_lorry.png"> />',
    ":bus:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bus.png"> />',
    ":oncoming_bus:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/oncoming_bus.png"> />',
    ":rotating_light:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rotating_light.png"> />',
    ":police_car:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/police_car.png"> />',
    ":oncoming_police_car:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/oncoming_police_car.png"> />',
    ":fire_engine:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fire_engine.png"> />',
    ":ambulance:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ambulance.png"> />',
    ":minibus:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/minibus.png"> />',
    ":truck:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/truck.png"> />',
    ":train:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/train.png"> />',
    ":station:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/station.png"> />',
    ":train2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/train2.png"> />',
    ":bullettrain_front:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bullettrain_front.png"> />',
    ":bullettrain_side:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bullettrain_side.png"> />',
    ":light_rail:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/light_rail.png"> />',
    ":monorail:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/monorail.png"> />',
    ":railway_car:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/railway_car.png"> />',
    ":trolleybus:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/trolleybus.png"> />',
    ":ticket:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ticket.png"> />',
    ":fuelpump:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fuelpump.png"> />',
    ":vertical_traffic_light:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/vertical_traffic_light.png"> />',
    ":traffic_light:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/traffic_light.png"> />',
    ":warning:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/warning.png"> />',
    ":construction:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/construction.png"> />',
    ":beginner:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/beginner.png"> />',
    ":atm:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/atm.png"> />',
    ":slot_machine:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/slot_machine.png"> />',
    ":busstop:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/busstop.png"> />',
    ":barber:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/barber.png"> />',
    ":hotsprings:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hotsprings.png"> />',
    ":checkered_flag:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/checkered_flag.png"> />',
    ":crossed_flags:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/crossed_flags.png"> />',
    ":izakaya_lantern:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/izakaya_lantern.png"> />',
    ":moyai:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/moyai.png"> />',
    ":circus_tent:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/circus_tent.png"> />',
    ":performing_arts:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/performing_arts.png"> />',
    ":round_pushpin:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/round_pushpin.png"> />',
    ":triangular_flag_on_post:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/triangular_flag_on_post.png"> />',
    ":jp:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/jp.png"> />',
    ":kr:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/kr.png"> />',
    ":cn:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cn.png"> />',
    ":us:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/us.png"> />',
    ":fr:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fr.png"> />',
    ":es:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/es.png"> />',
    ":it:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/it.png"> />',
    ":ru:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ru.png"> />',
    ":gb:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/gb.png"> />',
    ":uk:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/uk.png"> />',
    ":de:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/de.png"> />',
    ":one:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/one.png"> />',
    ":two:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/two.png"> />',
    ":three:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/three.png"> />',
    ":four:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/four.png"> />',
    ":five:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/five.png"> />',
    ":six:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/six.png"> />',
    ":seven:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/seven.png"> />',
    ":eight:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/eight.png"> />',
    ":nine:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/nine.png"> />',
    ":keycap_ten:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/keycap_ten.png"> />',
    ":1234:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/1234.png"> />',
    ":zero:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/zero.png"> />',
    ":hash:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/hash.png"> />',
    ":symbols:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/symbols.png"> />',
    ":arrow_backward:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_backward.png"> />',
    ":arrow_down:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_down.png"> />',
    ":arrow_forward:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_forward.png"> />',
    ":arrow_left:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_left.png"> />',
    ":capital_abcd:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/capital_abcd.png"> />',
    ":abcd:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/abcd.png"> />',
    ":abc:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/abc.png"> />',
    ":arrow_lower_left:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_lower_left.png"> />',
    ":arrow_lower_right:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_lower_right.png"> />',
    ":arrow_right:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_right.png"> />',
    ":arrow_up:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_up.png"> />',
    ":arrow_upper_left:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_upper_left.png"> />',
    ":arrow_upper_right:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_upper_right.png"> />',
    ":arrow_double_down:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_double_down.png"> />',
    ":arrow_double_up:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_double_up.png"> />',
    ":arrow_down_small:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_down_small.png"> />',
    ":arrow_heading_down:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_heading_down.png"> />',
    ":arrow_heading_up:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_heading_up.png"> />',
    ":leftwards_arrow_with_hook:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/leftwards_arrow_with_hook.png"> />',
    ":arrow_right_hook:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_right_hook.png"> />',
    ":left_right_arrow:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/left_right_arrow.png"> />',
    ":arrow_up_down:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_up_down.png"> />',
    ":arrow_up_small:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrow_up_small.png"> />',
    ":arrows_clockwise:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrows_clockwise.png"> />',
    ":arrows_counterclockwise:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/arrows_counterclockwise.png"> />',
    ":rewind:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/rewind.png"> />',
    ":fast_forward:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/fast_forward.png"> />',
    ":information_source:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/information_source.png"> />',
    ":ok:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ok.png"> />',
    ":twisted_rightwards_arrows:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/twisted_rightwards_arrows.png"> />',
    ":repeat:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/repeat.png"> />',
    ":repeat_one:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/repeat_one.png"> />',
    ":new:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/new.png"> />',
    ":top:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/top.png"> />',
    ":up:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/up.png"> />',
    ":cool:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cool.png"> />',
    ":free:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/free.png"> />',
    ":ng:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ng.png"> />',
    ":cinema:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cinema.png"> />',
    ":koko:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/koko.png"> />',
    ":signal_strength:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/signal_strength.png"> />',
    ":u5272:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u5272.png"> />',
    ":u5408:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u5408.png"> />',
    ":u55b6:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u55b6.png"> />',
    ":u6307:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u6307.png"> />',
    ":u6708:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u6708.png"> />',
    ":u6709:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u6709.png"> />',
    ":u6e80:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u6e80.png"> />',
    ":u7121:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u7121.png"> />',
    ":u7533:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u7533.png"> />',
    ":u7a7a:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u7a7a.png"> />',
    ":u7981:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/u7981.png"> />',
    ":sa:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sa.png"> />',
    ":restroom:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/restroom.png"> />',
    ":mens:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mens.png"> />',
    ":womens:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/womens.png"> />',
    ":baby_symbol:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/baby_symbol.png"> />',
    ":no_smoking:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/no_smoking.png"> />',
    ":parking:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/parking.png"> />',
    ":wheelchair:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wheelchair.png"> />',
    ":metro:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/metro.png"> />',
    ":baggage_claim:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/baggage_claim.png"> />',
    ":accept:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/accept.png"> />',
    ":wc:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wc.png"> />',
    ":potable_water:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/potable_water.png"> />',
    ":put_litter_in_its_place:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/put_litter_in_its_place.png"> />',
    ":secret:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/secret.png"> />',
    ":congratulations:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/congratulations.png"> />',
    ":m:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/m.png"> />',
    ":passport_control:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/passport_control.png"> />',
    ":left_luggage:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/left_luggage.png"> />',
    ":customs:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/customs.png"> />',
    ":ideograph_advantage:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ideograph_advantage.png"> />',
    ":cl:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cl.png"> />',
    ":sos:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sos.png"> />',
    ":id:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/id.png"> />',
    ":no_entry_sign:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/no_entry_sign.png"> />',
    ":underage:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/underage.png"> />',
    ":no_mobile_phones:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/no_mobile_phones.png"> />',
    ":do_not_litter:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/do_not_litter.png"> />',
    ":non-potable_water:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/non-potable_water.png"> />',
    ":no_bicycles:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/no_bicycles.png"> />',
    ":no_pedestrians:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/no_pedestrians.png"> />',
    ":children_crossing:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/children_crossing.png"> />',
    ":no_entry:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/no_entry.png"> />',
    ":eight_spoked_asterisk:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/eight_spoked_asterisk.png"> />',
    ":sparkle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sparkle.png"> />',
    ":eight_pointed_black_star:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/eight_pointed_black_star.png"> />',
    ":heart_decoration:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heart_decoration.png"> />',
    ":vs:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/vs.png"> />',
    ":vibration_mode:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/vibration_mode.png"> />',
    ":mobile_phone_off:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/mobile_phone_off.png"> />',
    ":chart:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/chart.png"> />',
    ":currency_exchange:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/currency_exchange.png"> />',
    ":aries:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/aries.png"> />',
    ":taurus:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/taurus.png"> />',
    ":gemini:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/gemini.png"> />',
    ":cancer:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/cancer.png"> />',
    ":leo:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/leo.png"> />',
    ":virgo:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/virgo.png"> />',
    ":libra:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/libra.png"> />',
    ":scorpius:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/scorpius.png"> />',
    ":sagittarius:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/sagittarius.png"> />',
    ":capricorn:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/capricorn.png"> />',
    ":aquarius:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/aquarius.png"> />',
    ":pisces:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/pisces.png"> />',
    ":ophiuchus:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ophiuchus.png"> />',
    ":six_pointed_star:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/six_pointed_star.png"> />',
    ":negative_squared_cross_mark:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/negative_squared_cross_mark.png"> />',
    ":a:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/a.png"> />',
    ":b:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/b.png"> />',
    ":ab:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ab.png"> />',
    ":o2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/o2.png"> />',
    ":diamond_shape_with_a_dot_inside:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/diamond_shape_with_a_dot_inside.png"> />',
    ":recycle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/recycle.png"> />',
    ":end:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/end.png"> />',
    ":back:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/back.png"> />',
    ":on:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/on.png"> />',
    ":soon:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/soon.png"> />',
    ":clock1:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock1.png"> />',
    ":clock130:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock130.png"> />',
    ":clock10:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock10.png"> />',
    ":clock1030:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock1030.png"> />',
    ":clock11:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock11.png"> />',
    ":clock1130:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock1130.png"> />',
    ":clock12:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock12.png"> />',
    ":clock1230:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock1230.png"> />',
    ":clock2:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock2.png"> />',
    ":clock230:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock230.png"> />',
    ":clock3:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock3.png"> />',
    ":clock330:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock330.png"> />',
    ":clock4:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock4.png"> />',
    ":clock430:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock430.png"> />',
    ":clock5:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock5.png"> />',
    ":clock530:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock530.png"> />',
    ":clock6:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock6.png"> />',
    ":clock630:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock630.png"> />',
    ":clock7:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock7.png"> />',
    ":clock730:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock730.png"> />',
    ":clock8:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock8.png"> />',
    ":clock830:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock830.png"> />',
    ":clock9:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock9.png"> />',
    ":clock930:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/clock930.png"> />',
    ":heavy_dollar_sign:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heavy_dollar_sign.png"> />',
    ":copyright:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/copyright.png"> />',
    ":registered:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/registered.png"> />',
    ":tm:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/tm.png"> />',
    ":x:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/x.png"> />',
    ":heavy_exclamation_mark:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heavy_exclamation_mark.png"> />',
    ":bangbang:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/bangbang.png"> />',
    ":interrobang:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/interrobang.png"> />',
    ":o:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/o.png"> />',
    ":heavy_multiplication_x:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heavy_multiplication_x.png"> />',
    ":heavy_plus_sign:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heavy_plus_sign.png"> />',
    ":heavy_minus_sign:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heavy_minus_sign.png"> />',
    ":heavy_division_sign:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heavy_division_sign.png"> />',
    ":white_flower:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/white_flower.png"> />',
    ":100:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/100.png"> />',
    ":heavy_check_mark:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/heavy_check_mark.png"> />',
    ":ballot_box_with_check:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/ballot_box_with_check.png"> />',
    ":radio_button:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/radio_button.png"> />',
    ":link:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/link.png"> />',
    ":curly_loop:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/curly_loop.png"> />',
    ":wavy_dash:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/wavy_dash.png"> />',
    ":part_alternation_mark:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/part_alternation_mark.png"> />',
    ":trident:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/trident.png"> />',
    ":black_small_square:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/black_small_square.png"> />',
    ":white_small_square:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/white_small_square.png"> />',
    ":black_medium_small_square:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/black_medium_small_square.png"> />',
    ":white_medium_small_square:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/white_medium_small_square.png"> />',
    ":black_medium_square:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/black_medium_square.png"> />',
    ":white_medium_square:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/white_medium_square.png"> />',
    ":black_large_square:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/black_square.png"> />',
    ":white_large_square:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/white_large_square.png"> />',
    ":white_check_mark:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/white_check_mark.png"> />',
    ":black_square_button:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/black_square_button.png"> />',
    ":white_square_button:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/white_square_button.png"> />',
    ":black_circle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/black_circle.png"> />',
    ":white_circle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/white_circle.png"> />',
    ":red_circle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/red_circle.png"> />',
    ":large_blue_circle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/large_blue_circle.png"> />',
    ":large_blue_diamond:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/large_blue_diamond.png"> />',
    ":large_orange_diamond:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/large_orange_diamond.png"> />',
    ":small_blue_diamond:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/small_blue_diamond.png"> />',
    ":small_orange_diamond:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/small_orange_diamond.png"> />',
    ":small_red_triangle:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/small_red_triangle.png"> />',
    ":small_red_triangle_down:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/small_red_triangle_down.png"> />',
    ":shipit:" =>
        '<img class="emoji" alt="" src="http://www.emoji-cheat-sheet.com/graphics/emojis/shipit.png"> />'
) ;



my $smiles = join( '|', map { quotemeta($_) } keys %smilies ) ;
# my $smiles = join( '|', map { quotemeta($_) } keys %emoji_cheatsheet ) ;

# ----------------------------------------------------------------------------
# we want some CSS
my $default_css = <<END_CSS;
    /* -------------- ConvertText2.pm css -------------- */

    img {max-width: 100%;}
    /* setup for print */
    \@media print {
        /* this is the normal page style */
        \@page {
            size: %PAGE_SIZE%  %ORIENTATION% ;
            margin: 60pt 30pt 40pt 30pt ;
        }
    }

    /* setup for web */
    \@media screen {
        #toc a {
            text-decoration: none ;
            font-weight: normal;
        }
    }            

    table { page-break-inside: auto ;}
    table { page-break-inside: avoid ;}
    tr    { page-break-inside:avoid; page-break-after:auto }
    thead { display:table-header-group }
    tfoot { display:table-footer-group }

    /* toc */
    .toc {
        padding: 0.4em;
        page-break-after: always;
    }
    .toc p {
        font-size: 24;
    }
    .toc h3 { text-align: center }
    .toc ul {
        columns: 1;
    }
    .toc ul, .toc li {
        list-style: none;
        margin: 0;
        padding: 0;
        padding-left: 10px ;
    }
    .toc a::after {
        content: leader('.') target-counter(attr(href), page);
        font-style: normal;
    }
    .toc a {
        text-decoration: none ;
        font-weight: normal;
        color: black;
    }

    /* using pygments style */
    div.sourceCode {
        border: solid 1px #d0d0d0;
        background-color: #f8f8f8 ; 
        border-radius: 5px;
        overflow-x: auto;
    }
    table.sourceCode, tr.sourceCode, td.lineNumbers, td.sourceCode {
        margin: 0; padding: 0; vertical-align: baseline; border: none; 
    }
    table.sourceCode { width: 100%; line-height: 100%; }
    td.lineNumbers { text-align: right; padding-right: 4px; padding-left: 4px; color: #aaaaaa; border-right: 1px solid #aaaaaa; }
    td.sourceCode { padding-left: 5px; }
    code > span.kw { color: #007020; font-weight: bold; } /* Keyword */
    code > span.dt { color: #902000; } /* DataType */
    code > span.dv { color: #40a070; } /* DecVal */
    code > span.bn { color: #40a070; } /* BaseN */
    code > span.fl { color: #40a070; } /* Float */
    code > span.ch { color: #4070a0; } /* Char */
    code > span.st { color: #4070a0; } /* String */
    code > span.co { color: #60a0b0; font-style: italic; } /* Comment */
    code > span.ot { color: #007020; } /* Other */
    code > span.al { color: #ff0000; font-weight: bold; } /* Alert */
    code > span.fu { color: #06287e; } /* Function */
    code > span.er { color: #ff0000; font-weight: bold; } /* Error */
    code > span.wa { color: #60a0b0; font-weight: bold; font-style: italic; } /* Warning */
    code > span.cn { color: #880000; } /* Constant */
    code > span.sc { color: #4070a0; } /* SpecialChar */
    code > span.vs { color: #4070a0; } /* VerbatimString */
    code > span.ss { color: #bb6688; } /* SpecialString */
    code > span.im { } /* Import */
    code > span.va { color: #19177c; } /* Variable */
    code > span.cf { color: #007020; font-weight: bold; } /* ControlFlow */
    code > span.op { color: #666666; } /* Operator */
    code > span.bu { } /* BuiltIn */
    code > span.ex { } /* Extension */
    code > span.pp { color: #bc7a00; } /* Preprocessor */
    code > span.at { color: #7d9029; } /* Attribute */
    code > span.do { color: #ba2121; font-style: italic; font-weight: lighter;} /* Documentation */
    code > span.an { color: #60a0b0; font-weight: bold; font-style: italic; } /* Annotation */
    code > span.cv { color: #60a0b0; font-weight: bold; font-style: italic; } /* CommentVar */
    code > span.in { color: #60a0b0; font-weight: bold; font-style: italic; } /* Information */

    \@page landscape {
        prince-rotate-body: 270deg;
    }
    .landscape {
        page: landscape;
    }

    body {
        font-family: sans-serif;
    }
    code {
        font-family: monospace;
    }

    /* we do not want these, headings start from h2 onwards */
    h1 {
        display: none;
    }

    li {
        padding-left: 0px;
        margin-left: -2em ;
    }

    /* enable tooltips on 'title' attributes when using PrinceXML */
    *[title] { prince-tooltip: attr(title) }

    .rotate-90 {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=1);
      -webkit-transform: rotate(90deg);
      -ms-transform: rotate(90deg);
      transform: rotate(90deg);
    }
    .rotate-180 {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=2);
      -webkit-transform: rotate(180deg);
      -ms-transform: rotate(180deg);
      transform: rotate(180deg);
    }
    .rotate-270 {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=3);
      -webkit-transform: rotate(270deg);
      -ms-transform: rotate(270deg);
      transform: rotate(270deg);
    }
    .flip-horizontal {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=0, mirror=1);
      -webkit-transform: scale(-1, 1);
      -ms-transform: scale(-1, 1);
      transform: scale(-1, 1);
    }
    .flip-vertical {
      filter: progid:DXImageTransform.Microsoft.BasicImage(rotation=2, mirror=1);
      -webkit-transform: scale(1, -1);
      -ms-transform: scale(1, -1);
      transform: scale(1, -1);
    }

    .border-grey {
        border-style: solid;
        border-width: 1px;
        border-color: grey300;
        box-shadow:inset 0px 0px 85px rgba(0,0,0,.5);
        -webkit-box-shadow:inset 0px 0px 85px rgba(0,0,0,.5);
        -moz-box-shadow:inset 0px 0px 85px rgba(0,0,0,.5);        
        box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.5);        
    }

    .border-inset-grey {
        border: 1px solid #666666;
        -webkit-box-shadow: inset 3px 3px 3px #AAAAAA;
        border-radius: 3px;
    }

    .border-shadow-grey {
        -moz-box-shadow: 3px 3px 4px #444;
        -webkit-box-shadow: 3px 3px 4px #444;
        box-shadow: 3px 3px 4px #444;
        -ms-filter: "progid:DXImageTransform.Microsoft.Shadow(Strength=4, Direction=135, Color='#444444')";
        filter: progid:DXImageTransform.Microsoft.Shadow(Strength=4, Direction=135, Color='#444444');    
    }

    .emoji {
      float:left;
      margin-right:.5em;
      width:22px;
      height:22px
    }
    .emoji-2x {
      float:left;
      margin-right:.5em;
      width:44px;
      height:44px
    }

    .material-icons {
        vertical-align: middle ;
    }

END_CSS

# The full set of sourceCode highlight css classes
# div.sourceCode {    }
# table.sourceCode, tr.sourceCode, td.lineNumbers, td.sourceCode {  }
# table.sourceCode {  }
# td.lineNumbers { }
# td.sourceCode {  }
# pre, code {  }
# code > span.kw {  } /* Keyword */
# code > span.dt {  } /* DataType */
# code > span.dv {  } /* DecVal */
# code > span.bn {  } /* BaseN */
# code > span.fl {  } /* Float */
# code > span.ch {  } /* Char */
# code > span.st {  } /* String */
# code > span.co {  } /* Comment */
# code > span.ot {  } /* Other */
# code > span.al {  } /* Alert */
# code > span.fu {  } /* Function */
# code > span.er {  } /* Error */
# code > span.wa {  } /* Warning */
# code > span.cn {  } /* Constant */
# code > span.sc {  } /* SpecialChar */
# code > span.vs {  } /* VerbatimString */
# code > span.ss {  } /* SpecialString */
# code > span.im { } /* Import */
# code > span.va { } /* Variable */
# code > span.cf {  } /* ControlFlow */
# code > span.op {  } /* Operator */
# code > span.bu { } /* BuiltIn */
# code > span.ex { } /* Extension */
# code > span.pp {  } /* Preprocessor */
# code > span.at { } /* Attribute */
# code > span.do {  } /* Documentation */
# code > span.an {  } /* Annotation */
# code > span.cv {  } /* CommentVar */
# code > span.in {  } /* Information */

# ----------------------------------------------------------------------------

my $TITLE = "%TITLE%" ;

# ----------------------------------------------------------------------------

has 'name'    => ( is => 'ro', ) ;
has 'basedir' => ( is => 'ro', ) ;

has 'use_cache' => ( is => 'rw', default => sub { 0 ; } ) ;

has 'cache_dir' => (
    is      => 'ro',
    default => sub {
        my $self = shift ;
        # return "/tmp/" . get_program() . "/cache/" ;
        return "$ENV{HOME}/.cache/" ;
    },
    writer => "_set_cache_dir"
) ;

has 'template' => (
    is      => 'rw',
    default => sub {
        "<!DOCTYPE html'>
<html>
    <head>
        <title>$TITLE</title>
        %JAVASCRIPT%
        <style type='text/css'>
            \@page { size: A4 }
            %CSS%
        </style>
    </head>
    <body>
        <h1>%TITLE%</h1>

        %_CONTENTS_%
    </body>
</html>\n" ;
    },
) ;

has 'replace' => (
    is      => 'ro',
    default => sub { {} },
) ;

has 'verbose' => (
    is      => 'ro',
    default => sub {0},
) ;

has '_output' => (
    is       => 'ro',
    default  => sub {""},
    init_arg => 0
) ;

has '_input' => (
    is       => 'ro',
    writer   => '_set_input',
    default  => sub {""},
    init_arg => 0
) ;

has '_md5id' => (
    is       => 'ro',
    writer   => '_set_md5id',
    default  => sub {""},
    init_arg => 0
) ;

# ----------------------------------------------------------------------------

=item new

Create a new instance of a of a data formating object

B<Parameters>  passed in a HASH
    name        - name of this formatting action - required
    basedir     - root directory of document being processed
    cache_dir   - place to store cache files - optional
    use_cache   - decide if you want to use a cache or not
    template    - HTML template to use, must contain %_CONTENTS_%
    replace     - hashref of extra keywords to use as replaceable variables
    verbose     - be verbose

=cut

sub BUILD
{
    my $self = shift ;

    die "No name provided" if ( !$self->name() ) ;

    if ( $self->use_cache() ) {

        # need to add the name to the cache dirname to make it distinct
        $self->_set_cache_dir(
            fix_filename( $self->cache_dir() . "/" . $self->name() ) ) ;

        if ( !-d $self->cache_dir() ) {

            # create the cache dir if needed
            try {
                path( $self->cache_dir() )->mkpath ;
            }
            catch {} ;
            die "Could not create cache dir " . $self->cache_dir()
                if ( !-d $self->cache_dir() ) ;
        }
    }

    # work out what plugins do what
    foreach my $plug ( $self->plugins() ) {
        my $obj = $plug->new() ;
        if ( !$obj ) {
            warn "Plugin $plug does not instantiate" ;
            next ;
        }

        # the process method does the work for all the tag handlers
        if ( !$obj->can('process') ) {
            warn "Plugin $plug does not provide a process method" ;
            next ;
        }
        foreach my $h ( @{ $obj->handles } ) {
            $h = lc($h) ;
            if ( $h eq 'buffer' ) {
                die
                    "Plugin $plug cannot provide a handler for $h, as this is already provided for internally"
                    ;
            }
            if ( has_block($h) ) {
                die
                    "Plugin $plug cannot provide a handler for $h, as this has already been provided by another plugin"
                    ;
            }

            # all handlers are lower case
            add_block( $h, $obj ) ;
        }
    }

    # buffer is a special internal handler
    add_block( 'buffer', 1 ) ;
}

# ----------------------------------------------------------------------------

sub _append_output
{
    my $self = shift ;
    my $str  = shift ;

    $self->{output} .= $str if ($str) ;
}

# ----------------------------------------------------------------------------
# store a file to the cache
# if the contents are empty then any existing cache file will be removed
sub _store_cache
{
    my $self = shift ;
    my ( $filename, $contents, $utf8 ) = @_ ;

    # don't do any cleanup if we are not using a cache
    return if ( !$self->use_cache() ) ;

    # for some reason sometimes the full cache dir is not created or
    # something deletes part of it, cannot figure it out
    path( $self->cache_dir() )->mkpath if ( !-d $self->cache_dir() ) ;

    # make sure we are working in the right dir
    my $f = $self->cache_dir() . "/" . path($filename)->basename ;

    if ( !$contents && -f $f ) {
        unlink($f) ;
    } else {
        if ($utf8) {
            path($f)->spew_utf8($contents) ;
        } else {
            path($f)->spew_raw($contents) ;
        }
    }
}

# ----------------------------------------------------------------------------
# get a file from the cache
sub _get_cache
{
    my $self = shift ;
    my ( $filename, $utf8 ) = @_ ;

    # don't do any cleanup if we are not using a cache
    return if ( !$self->use_cache() ) ;

    # make sure we are working in the right dir
    my $f = $self->cache_dir() . "/" . path($filename)->basename ;

    my $result ;
    if ( -f $f ) {
        if ($utf8) {
            $result = path($f)->slurp_utf8 ;
        } else {
            $result = path($f)->slurp_raw ;
        }
    }

    return $result ;
}

# ----------------------------------------------------------------------------

=item clean_cache

Remove all files from the cache

=cut

sub clean_cache
{
    my $self = shift ;

    # don't do any cleanup if we are not using a cache
    return if ( !$self->use_cache() ) ;

    # try { path( $self->cache_dir() )->remove_tree } catch {} ;

    # # and make it fresh again
    # path( $self->cache_dir() )->mkpath() ;
    system( "rm -rf '" . $self->cache_dir() . "'/* 2>/dev/null" ) ;
}

# ----------------------------------------------------------------------------
# _extract_args
# get key=value data from a passed string
sub _extract_args
{
    my $buf = shift ;
    my ( %attr, $eaten ) ;
    return \%attr if ( !$buf ) ;

    while ( $buf =~ s|^\s?(([a-zA-Z][a-zA-Z0-9\.\-_]*)\s*)|| ) {
        $eaten .= $1 ;
        my $attr = lc $2 ;
        my $val ;

        # The attribute might take an optional value (first we
        # check for an unquoted value)
        if ( $buf =~ s|(^=\s*([^\"\'>\s][^>\s]*)\s*)|| ) {
            $eaten .= $1 ;
            $val = $2 ;

            # or quoted by " or '
        } elsif ( $buf =~ s|(^=\s*([\"\'])(.*?)\2\s*)||s ) {
            $eaten .= $1 ;
            $val = $3 ;

            # truncated just after the '=' or inside the attribute
        } elsif ( $buf =~ m|^(=\s*)$|
            or $buf =~ m|^(=\s*[\"\'].*)|s ) {
            $buf = "$eaten$1" ;
            last ;
        } else {
            # assume attribute with implicit value
            $val = $attr ;
        }
        $attr{$attr} = $val ;
    }

    return \%attr ;
}

# ----------------------------------------------------------------------------
# add/append into the replacements list
sub _add_replace
{
    my $self = shift ;
    my ( $key, $val, $append ) = @_ ;

    if ($append) {
        $self->{replace}->{ uc($key) } .= "$val\n" ;
    } else {
        $self->{replace}->{ uc($key) } = $val ;
    }
}

# ----------------------------------------------------------------------------
sub _do_replacements
{
    my $self = shift ;
    my ($content) = @_ ;

    if ($content) {
        foreach my $k ( keys %{ $self->replace() } ) {
            next if ( !$self->{replace}->{$k} ) ;

            # in the text the variables to be replaced are surrounded by %
            # zero width look behind to make sure the variable name has
            # not been escaped _%VARIABLE% should be left alone
            $content =~ s/(?<!_)%$k%/$self->{replace}->{$k}/gsm ;
        }
    }

    return $content ;
}

# ----------------------------------------------------------------------------
sub _call_function
{
    my $self = shift ;
    my ( $block, $params, $content, $linepos ) = @_ ;
    my $out ;

    if ( !has_block($block) ) {
        debug( "ERROR:", "no valid handler for $block" ) ;
    } else {
        try {

         # buffer is a special construct to allow us to hold output of content
         # for later, allows multiple use of content or adding things to
         # markdown tables that otherwise we could not do

            # over-ride content with buffered content
            my $from = $params->{from} || $params->{from_buffer} ;
            if ($from) {
                $content = $self->{replace}->{ uc($from) } ;
            }

            # get the content from the args, useful for short blocks
            if ( $params->{content} ) {
                $content = $params->{content} ;
            }
            if ( $params->{file} ) {
                $content = _include_file("file='$params->{file}'") ;
            }

            my $to = $params->{to} || $params->{to_buffer} ;

            if ( $block eq 'buffer' ) {
                if ($to) {
                    # we could be appending to a named buffer also
                    $self->_add_replace( $to, $content, $params->{add} ) ;
                }
            } else {
                # do any replacements we know about in the content block
                $content = $self->_do_replacements($content) ;

                # run the plugin with the data we have
                $out = run_block( $block, $content, $params,
                    $self->cache_dir() ) ;

                if ( !$out ) {

       # if we could not generate any output, lets put the block back together
                    $out .= "~~~~{.$block "
                        . join( " ",
                        map {"$_='$params->{$_}'"} keys %{$params} )
                        . " }\n"
                        . "~~~~\n" ;
                } elsif ($to) {

                    # do we want to buffer the output?
                    $self->_add_replace( $to, $out ) ;

                    # option not to show the output
                    $out = "" if ( $params->{no_output} ) ;
                }
            }
            # $self->_append_output("$out\n") if ( defined $out ) ;
        }
        catch {
            debug( "ERROR",
                "failed processing $block near line $linepos, $_" ) ;
            warn "Issue processing $block around line $linepos" ;
            $out
                = "~~~~{.$block "
                . join( " ", map {"$_='$params->{$_}'"} keys %{$params} )
                . " }\n"
                . "~~~~\n" ;
            # $self->_append_output($out) ;
        } ;
    }
    return $out ;
}

# ----------------------------------------------------------------------------
# handle any {{.tag args='11'}} type things in given text

sub _rewrite_short_block
{
    my $self = shift ;
    my ( $block, $attributes ) = @_ ;
    my $out ;
    my $params = _extract_args($attributes) ;

    if ( has_block($block) ) {
        return $self->_call_function( $block, $params, $params->{content},
            0 ) ;
    } else {
        # build the short block back together, if we do not have a match
        $out = "{{.block $attributes}}" ;
    }
    return $out ;
}

# ----------------------------------------------------------------------------
### _parse_lines
# parse the passed data
sub _parse_lines
{
    my $self      = shift ;
    my $lines     = shift ;
    my $count     = 0 ;
    my $curr_line = "" ;

    return if ( !$lines ) ;

    my ( $class, $block, $content, $attributes ) ;
    my ( $buildline, $simple ) ;
    try {
        foreach my $line ( @{$lines} ) {
            $curr_line = $line ;
            $count++ ;

            # header lines may have been removed
            if ( !defined $line ) {
           # we may want a blank line to space out things like indented blocks
                $self->_append_output("\n") ;
                next ;
            }

         # a short block is {{.tag arguments}}
         # or {{.tag}}
         # can have multiple ones on a single line like {{.tag1}} {{.tag_two}}
         # short tags cannot have the form
         # {{.class .tag args=123}}
         # replace all tags on this line
            $line
                =~ s/\{\{\.(\w+)(\b.*?)\}\}/$self->_rewrite_short_block( $1, $2)/egs
                ;

            if ( defined $simple ) {
                if ( $line =~ /^~{4,}\s?$/ ) {
                    $self->_append_output("~~~~\n$simple\n~~~~\n") ;
                    $simple = undef ;
                } else {
                    $simple .= "$line\n" ;
                }

                next ;
            }

# we may need to add successive lines together to get a completed fenced code block
            if ( !$block && $buildline ) {
                $buildline .= " $line" ;
                if ( $line =~ /\}\s*$/ ) {
                    $line = $buildline ;

                    # make sure to clear the builder
                    $buildline = undef ;
                } else {
                    # continue to build the line
                    next ;
                }
            }

            # a simple block does not have an identifying {.tag}
            if ( $line =~ /^~{4,}\s?$/ && !$block ) {
                $simple = "" ;
                next ;
            }

            if ( $line =~ /^~{4,}/ ) {

                # does the fenced line wrap before its ended
                if ( !$block && $line !~ /\}\s*$/ ) {

                    # we need to start adding lines till its completed
                    $buildline = $line ;
                    next ;
                }

                if ( $line =~ /\{(.*?)\.(\w+)\s*(.*?)\}\s*$/ ) {
                    $class      = $1 ;
                    $block      = lc($2) ;
                    $attributes = $3 ;
                } elsif ( $line =~ /\{\.(\w+)\s?\}\s*$/ ) {
                    $block      = lc($1) ;
                    $attributes = {} ;
                } else {
                    my $params = _extract_args($attributes) ;

                    # must have reached the end of a block
                    if ( has_block($block) ) {
                        chomp $content if ($content) ;
                        my $out = $self->_call_function( $block, $params,
                            $content, $count ) ;
                        # not all blocks output things, eg buffer operations
                        if ($out) {
       # add extra line to make sure things are spaced away from other content
                            $self->_append_output("$out\n\n") ;
                        }
                    } else {
                        if ( !$block ) {

                            # put it back
                            $content ||= "" ;
                            $self->_append_output(
                                "~~~~\n$content\n~~~~\n\n") ;

                        } else {
                            $content    ||= "" ;
                            $attributes ||= "" ;
                            $block      ||= "" ;

                            # put it back
                            $self->_append_output(
                                "~~~~{ $class .$block $attributes}\n$content\n~~~~\n\n"
                            ) ;
                        }
                    }
                    $content    = "" ;
                    $attributes = "" ;
                    $block      = "" ;
                }
            } else {
                if ($block) {
                    $content .= "$line\n" ;
                } else {
                    $self->_append_output("$line\n") ;
                }
            }
        }
    }
    catch {
        die "Issue at line $count $_ ($curr_line)" ;
    } ;
}

# ----------------------------------------------------------------------------
# fetch any img references and copy into the cache, if the image is already
# in the cache then nothing will happen, will rewrite other img uri's
sub _rewrite_imgsrc
{
    my $self = shift ;
    my ( $pre, $img, $post, $want_size ) = @_ ;
    my $ext ;
    if ( $img =~ /\.(\w+)$/ ) {
        $ext = $1 ;
    }

    if ($ext) {    # potentially image is already an embedded image
        if ( $img !~ /base64,/ && $img !~ /\.svg$/i ) {
            # if ( $img !~ /base64,/ ) {

            # if its an image we have generated then it may already be here
            # check to see if we have this in the cache
            my $cachefile = cachefile( $self->cache_dir, $img ) ;
            $cachefile =~ s/\n//g ;
            if ( !-f $cachefile ) {
                my $id = md5_hex($img) ;
                $id .= ".$ext" ;

                # this is what it will be named in the cache
                $cachefile = cachefile( $self->cache_dir, $id ) ;

                # not in the cache , fetch it and store it local to the cache
                # if we are a local file
                if ( $img !~ m|^\w+://| || $img =~ m|^file://| ) {
                    $img =~ s|^file://|| ;
                    $img = fix_filename($img) ;

                    if ( $img !~ m|/| ) {

                        # if file is relative, then we need to add the basedir
                        $img = $self->basedir . "/$img" ;
                    }

                    # copy it to the cache location
                    try {
                        path($img)->copy($cachefile) ;
                    }
                    catch {
                        debug( "ERROR",
                            "failed to copy $img to $cachefile" ) ;
                    } ;

                    $img = $cachefile if ( -f $cachefile ) ;
                } else {
                    if ( $img =~ m|^(\w+)://(.*)| ) {

                        my $furl = Furl->new(
                            agent   => get_program(),
                            timeout => 0.2,
                        ) ;

                        my $res = $furl->get($img) ;
                        if ( $res->is_success ) {
                            path($cachefile)->spew_raw( $res->content ) ;
                            $img = $cachefile ;
                        } else {
                            debug( "ERROR", "unknown could not fetch $img" ) ;
                        }
                    } else {
                        debug( "ERROR", "unknown protocol for $img" ) ;
                    }
                }
            } else {
                $img = $cachefile ;
            }

            # make sure we add the image size if its not already there
            if (   $want_size
                && $pre !~ /width=|height=/i
                && $post !~ /width=|height=/i ) {
                my $image = GD::Image->new($img) ;
                if ($image) {
                    $post =~ s/\/>$// ;
                    $post
                        .= " height='"
                        . $image->height()
                        . "' width='"
                        . $image->width()
                        . "' />" ;
                }
            }

 # do we need to embed the images, if we do this then libreoffice may be pants
 # however 'prince' is happy

# we encode the image as base64 so that the HTML document can be moved with all images
# intact
            my $base64 = MIME::Base64::encode( path($img)->slurp_raw ) ;
            $img = "data:image/$ext;base64,$base64" ;
        }

    }
    return $pre . $img . $post ;
}



# ----------------------------------------------------------------------------
# fetch any img references and copy into the cache, if the image is already
# in the cache then nothing will happen, will rewrite other img uri's
sub _rewrite_imgsrc_local
{
    my $self = shift ;
    my ( $pre, $img, $post ) = @_ ;
    my $ext = "default" ;
    if ( $img =~ /\.(\w+)$/ ) {
        $ext = $1 ;
    }

    # potentially image is already an embedded image or SVG
    if ( $img !~ /base64,/ && $img !~ /\.svg$/i ) {
        # if we are a local file
        if ( $img !~ m|^\w+://| || $img =~ m|^file://| ) {
            $img =~ s|^file://|| ;
            $img = fix_filename($img) ;

            if ( $img !~ m|/| ) {
                # if file is relative, then we need to add the basedir
                $img = $self->basedir . "/$img" ;
            }
            # make sure its local then
            $img = "file://$img" ;
        }
    }
    return $pre . $img . $post ;
}

# ----------------------------------------------------------------------------
# grab all the h2/h3 elements and make them toc items

sub _build_toc
{
    my $html = shift ;

# find any header elements that do not have toc_skip in them
# removing toc_skip for now as it does not seem to work properly
# $html =~ m|<h([23456])(?!.*?(toc_skip|skiptoc).*?).*?><a name=['"](.*?)['"]>(.*?)</a></h\1>|gsmi ;

    # we grab 3 items per header
    my @items = ( $html
            =~ m|<h([23456]).*?><a name=['"](.*?)['"]>(.*?)</a></h\1>|gsmi ) ;

    my $toc = "<p>Contents</p>\n<ul>\n" ;
    for ( my $i = 0; $i < scalar(@items); $i += 3 ) {
        my $ref = $items[ $i + 1 ] ;

        my $h = $items[ $i + 2 ] ;

        # remove any href inside the header title
        $h =~ s/<\/?a.*?>//g ;

        if ( $h =~ /^(\d+\..*?) / ) {
            # indent depending on number of header
            my @a = split( /\./, $1 ) ;
            $h = ( "&nbsp;&nbsp;&nbsp;" x scalar(@a) ) . $h ;
        }

        # make sure reference is in lower case
        $toc .= "  <li><a href='#$ref'>$h</a></li>\n" ;
    }

    $toc .= "</ul>\n" ;

    return $toc ;
}

# ----------------------------------------------------------------------------
# rewrite the headers so that they are nice for the TOC
sub _rewrite_hdrs
{
    state $counters = { 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0 } ;
    state $last_lvl = 0 ;

    my ( $head, $txt, $tail ) = @_ ;
    my $pre ;

    my ($lvl) = ( $head =~ /<h(\d)/i ) ;
    my $ref = $txt ;

    if ( $lvl < $last_lvl ) {
        debug( "ERROR", "something odd happening in _rewrite_hdrs" ) ;
    } elsif ( $lvl > $last_lvl ) {

  # if we are stepping back up a level then we need to reset the counter below
  # if ( $lvl == 4 ) {
  #     $counters->{5} = 0;
  # }
  # elsif ( $lvl == 3 ) {
  #     $counters->{4} = 0;
  # }
  # elsif ( $lvl == 2 ) {
  #     map { $counters->{$_} = 0 ;} (3..6) ;
  # }

        if ( $lvl == 2 ) {
            map { $counters->{$_} = 0 ; } ( 3 .. 6 ) ;
        } else {
            $counters->{ $lvl + 1 } = 0 ;
        }
    }
    $counters->{$lvl}++ ;

    if    ( $lvl == 2 ) { $pre = "$counters->{2}" ; }
    elsif ( $lvl == 3 ) { $pre = "$counters->{2}.$counters->{3}" ; }
    elsif ( $lvl == 4 ) {
        $pre = "$counters->{2}.$counters->{3}.$counters->{4}" ;
    } elsif ( $lvl == 5 ) {
        $pre = "$counters->{2}.$counters->{3}.$counters->{4}.$counters->{5}" ;
    } elsif ( $lvl == 6 ) {
        $pre
            = "$counters->{2}.$counters->{3}.$counters->{4}.$counters->{5}.$counters->{6}"
            ;
    }

    $ref =~ s/\s/_/gsm ;

    # remove things we don't like from the reference
    $ref =~ s/[\s'"\(\)\[\]<>]//g ;

    my $out = "$head<a name='$pre" . "_" . lc($ref) . "'>$pre $txt</a>$tail" ;
    return $out ;
}

# ----------------------------------------------------------------------------
# use pandoc to parse markdown into nice HTML
# pandoc has extra features over and above markdown, eg syntax highlighting
# and tables
# pandoc must be in user path

sub _pandoc_html
{
    my ( $input, $commonmark ) = @_ ;

    my $paninput  = Path::Tiny->tempfile("pandoc.in.XXXX") ;
    my $panoutput = Path::Tiny->tempfile("pandoc.out.XXXX") ;
    path($paninput)->spew_utf8($input) ;
    # my $debug_file = "/tmp/pandoc.$$.md" ;
    # path( $debug_file)->spew_utf8($input) ;

    my $command
        = PANDOC
        . " --ascii --email-obfuscation=none -S -R --normalize -t html5 "
        . " --highlight-style='kate' "
        . " '$paninput' -o '$panoutput'" ;

    my $resp = execute_cmd(
        command => $command,
        timeout => 30,
    ) ;

    my $html ;

    if ( !$commonmark ) {
        debug( "Pandoc: " . $resp->{stderr} ) if ( $resp->{stderr} ) ;
        if ( !$resp->{exit_code} ) {
            $html = path($panoutput)->slurp_utf8() ;

            # path( "/tmp/pandoc.html")->spew_utf8($html) ;

            # this will have html headers and footers, we need to dump these
            $html =~ s/<!DOCTYPE.*?<body>//gsm ;
            $html =~ s/^<\/body>\n<\/html>//gsm ;
            # remove any footnotes hr
            $html
                =~ s/(<section class="footnotes">)\n<hr \/>/<h2>Footnotes<\/h2>\n$1/gsm
                ;
        } else {
            my $err = $resp->{stderr} || "" ;
            chomp $err ;
            # debug( "INFO", "cmd [$command]") ;
            debug( "ERROR",
                "Could not parse with pandoc, using Markdown, $err" ) ;
            warn "Could not parse with pandoc, using Markdown "
                . $resp->{stderr} ;
        }
    }
    if ( $commonmark || !$html ) {
        # markdown would prefer this for fenced code blocks
        $input =~ s/^~~~~.*$/\`\`\`\`/gm ;

        $html = convert_md($input) ;
        # do markdown in HTML elements too
        # $html = CommonMark->markdown_to_html($input) ;
    }

    # strip out any HTML comments that may have come in from template
    $html =~ s/<!--.*?-->//gsm ;

    return $html ;
}

# ----------------------------------------------------------------------------
# use pandoc to convert HTML into another format
# pandoc must be in user path

sub _pandoc_format
{
    my ( $input, $output ) = @_ ;
    my $status = 1 ;

    my $resp = execute_cmd(

        command => PANDOC . " '$input' -o '$output'",
        timeout => 30,
    ) ;

    debug( "Pandoc: " . $resp->{stderr} ) if ( $resp->{stderr} ) ;
    if ( !$resp->{exit_code} ) {
        $status = 0 ;
    } else {
        debug( "ERROR", "Could not parse with pandoc" ) ;
        $status = 1 ;
    }

    return $status ;
}

# ----------------------------------------------------------------------------
# convert_file
# convert the file to a different format from HTML
#  parameters
#     file    - file to re-convert
#     format  - format to convert to
#     pdfconvertor  - use prince/wkhtmltopdf rather than pandoc to convert to PDF

sub _convert_file
{
    my $self = shift ;
    my ( $file, $format, $pdfconvertor ) = @_ ;

    # we work on the is that pandoc should be in your PATH
    my $fmt_str = $format ;
    my ( $outfile, $exit ) ;

    $outfile = $file ;
    $outfile =~ s/\.(\w+)$/.pdf/ ;

# we can use prince to do PDF conversion, its faster and better, but not free for commercial use
# you would have to ignore the P symbol on the resultant document
    if ( $format =~ /pdf/i && $pdfconvertor ) {
        my $cmd ;

        if ( $pdfconvertor =~ /^prince/i ) {
            $cmd = PRINCE
                . " --javascript --input=html5 "
                ;    # so we can do some clever things if needed
            $cmd .= "--pdf-title='$self->{replace}->{TITLE}' "
                if ( $self->{replace}->{TITLE} ) ;
            my $subj = $self->{replace}->{SUBJECT}
                || $self->{replace}->{SUBTITLE} ;
            $cmd .= "--pdf-subject='$subj' "
                if ($subj) ;
            $cmd .= "--pdf-creator='" . get_program() . "' " ;
            $cmd .= "--pdf-author='$self->{replace}->{AUTHOR}' "
                if ( $self->{replace}->{AUTHOR} ) ;
            $cmd .= "--pdf-keywords='$self->{replace}->{KEYWORDS}' "
                if ( $self->{replace}->{KEYWORDS} ) ;
# seems to create smaller files if we embed fonts!
# $cmd .= " --no-embed-fonts --no-subset-fonts --media=print $file -o $outfile" ;
# $cmd .= "  --no-artificial-fonts --no-embed-fonts " ;
            $cmd .= " --media=print '$file' -o '$outfile'" ;
        } elsif ( $pdfconvertor =~ /^wkhtmltopdf/i ) {
            $cmd = WKHTML . " -q --print-media-type " ;
            $cmd .= "--title '$self->{replace}->{TITLE}' "
                if ( $self->{replace}->{TITLE} ) ;

            # do we want to specify the size
            $cmd .= "--page-size $self->{replace}->{PAGE_SIZE} "
                if ( $self->{replace}->{PAGE_SIZE} ) ;
            $cmd .= "'$file' '$outfile'" ;
        } else {
            warn "Unknown PDF converter ($pdfconvertor), using pandoc" ;

           # otherwise lets use pandoc to create the file in the other formats
            $exit = _pandoc_format( $file, $outfile ) ;
        }
        if ($cmd) {
            my ( $out, $err ) ;
            try {
                # say "$cmd" ;
                ( $exit, $out, $err ) = run_cmd($cmd) ;
            }
            catch {
                $err  = "run_cmd($cmd) died - $_" ;
                $exit = 1 ;
            } ;

            debug( "ERROR", $err )
                if ($err) ;    # only debug if return code is not 0
        }
    } else {
        # otherwise lets use pandoc to create the file in the other formats
        $exit = _pandoc_format( $file, $outfile ) ;
    }

    # if we failed to convert, then clear the filename
    return $exit == 0 ? $outfile : undef ;
}

# ----------------------------------------------------------------------------
# convert Admonition paragraphs to tagged blocks
sub _rewrite_admonitions
{
    my ( $tag, $content ) = @_ ;
    $content =~ s/^\s+|\s+$//gsm ;

    my $out = "\n~~~~{." . lc($tag) . " icon=1}\n$content\n~~~~\n\n" ;

    return $out ;
}

# ----------------------------------------------------------------------------
# convert things to fontawesome icons, can do most things except stacking fonts
sub _fontawesome
{
    my ( $demo, $icon, $class ) = @_ ;
    my $out ;

    $icon =~ s/^fa-// if ($icon) ;
    if ( !$demo ) {
        my $style = "" ;
        my @colors ;
        if ($class) {
            $class =~ s/^\[|\]$//g ;
            $class =~ s/\b(fw|lg|border)\b/fa-$1/ ;
            $class =~ s/\b([2345]x)\b/fa-$1/ ;
            $class =~ s/\b(90|180|270)\b/fa-rotate-$1/ ;
            $class =~ s/\bflipv\b/fa-flip-vertical/ ;
            $class =~ s/\bfliph\b/fa-flip-horizontal/ ;

            if ( $class =~ s/#((\w+)?\.?(\w+)?)// ) {
                my ( $fg, $bg ) = ( $2, $3 ) ;
                $style .= "color:" . to_hex_color($fg) . ";" if ($fg) ;
                $style .= "background-color:" . to_hex_color($bg) . ";"
                    if ($bg) ;
            }
        # things changed and anything left in class must be a real class thing
            $class =~ s/^\s+|\s+$//g ;
        } else {
            $class = "" ;
        }
        $out = "<i class='fa fa-$icon $class'"
            . ( $style ? " style='$style'" : "" ) ;
        $out .= "></i>" ;
    } else {
        if ( $icon eq '\\' ) {
            ( $icon, $class ) = @_[ 2 .. 3 ] ;
            $icon =~ s/^fa-// if ($icon) ;
        }
        $class =~ s/^\[|\]$//g if ($class) ;
        $out = ":fa:$icon" ;
        $out .= ":[$class]" if ($class) ;
    }

    return $out ;
}

# ----------------------------------------------------------------------------
# convert things to google material icons
sub _fontmaterial
{
    my ( $demo, $icon, $class ) = @_ ;
    my $out ;

    $icon =~ s/^mi-// if ($icon) ;
    if ( !$demo ) {
        my $style = "" ;
        my @colors ;
        if ($class) {
            $class =~ s/^\[|\]$//g ;
            # $class =~ s/\b(fw|lg|border)\b/mi-$1/ ;
            if ( $class =~ /\blg\b/ ) {
                $style .= "font-size:1.75em;" ;
                $class =~ s/\blg\b// ;
            } elsif ( $class =~ /\b([2345])x\b/ ) {
                $style .= "font-size:$1" . "em;" ;
                $class =~ s/\b[2345]x\b// ;
            }
            $class =~ s/\b(90|180|270)\b/rotate-$1/ ;
            $class =~ s/\bflipv\b/flip-vertical/ ;
            $class =~ s/\bfliph\b/flip-horizontal/ ;

            if ( $class =~ s/#((\w+)?\.?(\w+)?)// ) {
                my ( $fg, $bg ) = ( $2, $3 ) ;
                $style .= "color:" . to_hex_color($fg) . ";" if ($fg) ;
                $style .= "background-color:" . to_hex_color($bg) . ";"
                    if ($bg) ;
            }
        # things changed and anything left in class must be a real class thing
            $class =~ s/^\s+|\s+$//g ;
        } else {
            $class = "" ;
        }
        # names are actually underscore spaced
        $icon =~ s/[-| ]/_/g ;
        $out = "<i class='material-icons $class'"
            . ( $style ? " style='$style'" : "" ) ;
        $out .= ">$icon</i>" ;
    } else {
        if ( $icon eq '\\' ) {
            ( $icon, $class ) = @_[ 2 .. 3 ] ;
            $icon =~ s/^mi-// if ($icon) ;
        }
        $class =~ s/^\[|\]$//g if ($class) ;
        $out = ":mi:$icon" ;
        $out .= ":[$class]" if ($class) ;
    }

    return $out ;
}

# ----------------------------------------------------------------------------
# handle all font replacers
sub _icon_replace
{
    my ( $demo, $type, $icon, $class ) = @_ ;

    if ( $type eq 'mi' ) {
        return _fontmaterial( $demo, $icon, $class ) ;
    } elsif ( $type eq 'fa' ) {
        return _fontawesome( $demo, $icon, $class ) ;
    }

    # its not a font we support yet, so rebuild the line
    my $out = "" ;
    $out .= $demo       if ($demo) ;
    $out .= ":$type:$icon" ;
    $out .= ":[$class]" if ($class) ;

    return $out ;
}

# ----------------------------------------------------------------------------
# do some private stuff
{
    my $_yaml_counter = 0 ;

    sub _reset_yaml_counter
    {
        $_yaml_counter = 0 ;
    }

   # remove the first yaml from the first 20 lines, pass anything else through
    sub _remove_yaml
    {
        my ( $line, $count ) = @_ ;

        $count ||= 20 ;
        if ( ++$_yaml_counter < $count ) {
            $line =~ s/^\w+:.*// ;
        }

        return $line ;
    }
}

# ----------------------------------------------------------------------------
# grab external files
# param is filename followed by any arguments

# parameters

#  file - name of file to import
#  markdown - show input is markdown and may need some tidy ups
#  headings - in markdown add this many '#' heading to the start of headers
#  class - optional class to wrap around import
#  style - optional style to wrap around import
#  date  - optional note the date of the imported file

sub _include_file
{
    my ($attributes) = @_ ;
    my $out = "" ;

    my $params = _extract_args($attributes) ;

    $params->{file} = fix_filename( $params->{file} ) ;
    if ( -f $params->{file}
        && ( $out = path( $params->{file} )->slurp_utf8() ) ) {
        if ( $params->{markdown} ) {
            # if we are importing markdown we may want to fix things up a bit
            # first off remove any yaml head matter from first 20 lines
            $out =~ s/^(.*)?$/_remove_yaml($1,20)/egm ;

            # then any version table
            $out =~ s/^~~~~\{.version.*?^~~~~//gsm ;

            # expand any headings if required
            if ( $params->{headings} ) {
                my $str = "#" x int( $params->{headings} ) ;
                $out =~ s/^#/#$str/gsm ;
            }
        }

        if ( $params->{date} ) {
            $out .= "\n\n*Updated: " ;
            my $st = path( $params->{file} )->stat ;
            $out .= strftime( "%Y-%m-%d %H:%M:%S", localtime( $st->mtime ) ) ;
            $out .= "*\n" ;
        }
        my $div = "<div" ;
        $div .= " class='$params->{class}'" if ( $params->{class} ) ;
        $div .= " style='$params->{style}'" if ( $params->{style} ) ;
  # make sure we have some space before we add stuff to the end - just in case
  # it ends with ~~~~ etc
        $out = "$div>$out\n</div>" ;
    }
    return $out ;
}

# ----------------------------------------------------------------------------
sub _replace_material
{
    my ( $operator, $value ) = @_ ;
    my $quote = "" ;
    if ( $value =~ /^(["'"])/ ) {
        $quote = $1 ;
        $value =~ s/^["'"]// ;
    }

    return "color" . $operator . $quote . to_hex_color($value) ;
}

# ----------------------------------------------------------------------------
sub _replace_material_bg
{
    my ( $operator, $value ) = @_ ;
    my $quote = "" ;
    if ( $value =~ /^(["'"])/ ) {
        $quote = $1 ;
        $value =~ s/^["'"]// ;
    }

    return "background" . $operator . $quote . to_hex_color($value) ;
}

# ----------------------------------------------------------------------------
sub _replace_colors
{
    my ( $demo, $color, $string ) = @_ ;
    my $out ;

    # force some whitespace to make the colors look nice if needs be
    $string =~ s/^(\s+)|(\s+)$/&nbsp;/g ;

    if ( !$demo ) {
        my ( $fg, $bg ) = split_colors($color) ;
        $out = "<span style='" ;
        $out .= "color:$fg;"            if ($fg) ;
        $out .= "background-color:$bg;" if ($bg) ;
        $out .= "'>$string</span>" ;
    } else {
        $out .= "<c:$color>$string</c>" ;
    }

    return $out ;
}

# ----------------------------------------------------------------------------

=item parse

parse the markup into HTML and return it, HTML is also stored internally

B<Parameter>
    markdown text

=cut

sub parse
{
    my $self = shift ;
    my ($data) = @_ ;

    die "Nothing to parse" if ( !$data ) ;

    # big cheat to get this link in ahead of the main CSS
    add_javascript( '<link rel="stylesheet" type="text/css" '
            . ' href="https://maxcdn.bootstrapcdn.com/font-awesome/4.4.0/css/font-awesome.min.css">'
    ) ;

    add_javascript(
        '<link href="https://fonts.googleapis.com/icon?family=Material+Icons"
      rel="stylesheet">'
    ) ;

    # add in our basic CSS
    add_css($default_css) ;

    my $id = md5_hex( encode_utf8($data) ) ;

    # my $id = md5_hex( $data );
    $self->_set_md5id($id) ;
    $self->_set_input($data) ;

    my $cachefile = cachefile( $self->cache_dir, "$id.html" ) ;
    # because we now have an import option, we cannot use a cached HTML file
    # as the imported may have changed and the cache file will not have
    # possible in the future that we could additionally check for the
    # existance of .import or filename= in some of the fenced code blocks
    # but probably not worth the effort over regeneration
    # if ( -f $cachefile ) {
    if (0) {
        my $cache = path($cachefile)->slurp_utf8 ;
        $self->{output} = $cache ;    # put cached item into output
    } else {
        $self->{output} = "" ;        # blank the output

        # replace Admonition paragraphs with a proper block
        $data
            =~ s/^(NOTE|INFO|TIP|IMPORTANT|CAUTION|WARNING|DANGER|TODO|ASIDE):(.*?)\n\n/_rewrite_admonitions( $1, $2)/egsm
            ;

        $data =~ s/\{\{.(include|import)\s+(.*?)\}\}/_include_file($2)/iesgm ;
        $data
            =~ s/^~~~~\{.(include|import)\s+(.*?)\}.*?~~~~/_include_file($2)/iesgm
            ;

        my @lines = split( /\n/, $data ) ;

        # process top 20 lines for keywords
        # maybe replace this with some YAML processor?
        for ( my $i = 0; $i < 20; $i++ ) {
            ## if there is no keyword separator then we must have done the keywords
            last if ( $lines[$i] !~ /:/ ) ;

            # allow keywords to be :keyword or keyword:
            my ( $k, $v ) = ( $lines[$i] =~ /^:?(\w+):?\s+(.*?)\s?$/ ) ;
            next if ( !$k ) ;

            # date/DATE is a special one as it may be that they want to use
            # the current date so we will ignore it
            if ( !( $k eq 'date' && $v eq '%DATE%' ) ) {
                $self->_add_replace( $k, $v ) ;
            }
            $lines[$i] = undef ;    # essentially remove the line
        }

        # parse the data find all fenced blocks we can handle
        $self->_parse_lines( \@lines ) ;

        # store the markdown before parsing
        # $self->_store_cache( $self->cache_dir() . "/$id.md",
        #     encode_utf8( $self->{output} ), 1 ) ;
        $self->_store_cache( $self->cache_dir() . "/$id.md",
            $self->{output}, 1 ) ;

        # we have a special replace for '---' alone on a line which is used to
        # signifiy a page break

        $self->{output}
            =~ s|^-{3,}\s?$|<div style='page-break-before: always;'></div>\n\n|gsm
            ;

      # this allows us to put short blocks as output of other blocks or inline
      # with things that might otherwise not allow them
      # we use the single line parse version too
      # short tags cannot have the form
      # {{.class .tag args=123}}

        $self->{output}
            =~ s/\{\{\.(\w+)(\b.*?)\}\}/$self->_rewrite_short_block( $1, $2)/egs
            ;

        # add in some smilies
        $self->{output} =~ s/(?<!\w)($smiles)(?!\w)/$smilies{$1}/g ;

        # do the font replacements, awesome or material
        # :fa:icon,  :mi:icon,
        $self->{output}
            =~ s/(\\)?:(\w{2}):([\w|-]+):?(\[(.*?)\])?/_icon_replace( $1, $2, $3, $4)/egsi
            ;

        $self->{output}
            =~ s/<c(\\)?:+(.*?)>(.*?)<\/c>/_replace_colors( $1, $2, $3)/egsi ;

        # we have created something so we can cache it, if use_cache is off
        # then this will not happen lower down
        # now we convert the parsed output into HTML
        my $pan = _pandoc_html( $self->{output} ) ;

        # add the converted markdown into the template
        my $html = $self->template ;
        # lets do the includes in the templates to, gives us some flexibility
        $html =~ s/\{\{.include file=(.*?)\}\}/_include_file($1)/esgm ;
        $html
            =~ s/^~~~~\{.include file=(.*?)\}.*?~~~~/_include_file($1)/esgm ;

        my $program = get_program() ;
        $html
            =~ s/(<head.*?>)/$1\n<meta name="generator" content="$program" \/>/i
            ;

        my $rep = "%" . CONTENTS . "%" ;
        $html =~ s/$rep/$pan/gsm ;

        # if the user has not used title: grab from the page so far
        if ( !$self->{replace}->{TITLE} ) {
            my (@h1) = ( $html =~ m|<h1.*?>(.*?)</h1>|gsmi ) ;

            # find the first header that does not contain %TITLE%
            # I failed to get the zero width look-behind working
            # my ($h) = ( $html =~ m|<h1.*?>.*?(?<!%TITLE%)(.*?)</h1>|gsmi );
            foreach my $h (@h1) {
                if ( $h !~ /%TITLE/ ) {
                    $self->{replace}->{TITLE} = $h ;
                    last ;
                }
            }
        }

        # do we need to add a table of contents
        if ( $html =~ /%TOC%/ ) {
            $html
                =~ s|(<h([23456]).*?>)(.*?)(</h\2>)|_rewrite_hdrs( $1, $3, $4)|egsi
                ;
            $self->{replace}->{TOC}
                = "<div class='toc'>" . _build_toc($html) . "</div>" ;
        }

        $self->{replace}->{CSS}        = get_css() ;
        $self->{replace}->{JAVASCRIPT} = get_javascript() ;

        # replace things we have saved
        $html = $self->_do_replacements($html) ;

    # # this allows us to put short blocks as output of other blocks or inline
    # # with things that might otherwise not allow them
    # # we use the single line parse version too
    # # short tags cannot have the form
    # # {{.class .tag args=123}}

#   $html
#       =~ s/\{\{\.(\w+)(\b.*?)\}\}/$self->_rewrite_short_block( $1, $2)/egs
#       ;
# and without arguments
# $html =~ s/\{\{\.(\w+)\s?\}\}/$self->_rewrite_short_block( '', $1, {})/egs ;

        # and remove any uppercased %word% things that are not processed
        $html =~ s/(?<!_)%[A-Z-_]+\%//gsm ;
        $html =~ s/_(%.*?%)/$1/gsm ;

# fetch any images and store to the cache, make sure they have sizes too
# $html
#     =~ s/(<img.*?src=['"])(.*?)(['"].*?>)/$self->_rewrite_imgsrc_local( $1, $2, $3)/egs
#     ;

# # write any css url images and store to the cache
# $html
#     =~ s/(url\s*\(['"]?)(.*?)(['"]?\))/$self->_rewrite_imgsrc_local( $1, $2, $3)/egs
#     ;

        $html
            =~ s/(<img.*?src=['"])(.*?)(['"].*?>)/$self->_rewrite_imgsrc( $1, $2, $3, 1)/egs
            ;

        # write any css url images and store to the cache
        $html
            =~ s/(url\s*\(['"]?)(.*?)(['"]?\))/$self->_rewrite_imgsrc( $1, $2, $3, 0)/egs
            ;

# replace any escaped \{ braces when needing to explain short code blocks in examples
        $html =~ s/\\\{/{/gsm ;

# we should have everything here, so lets do any final replacements for material colors
        $html
            =~ s/color(=|:)\s?(["']?\w+[50]0\b)/_replace_material( $1,$2)/egsm
            ;
        $html
            =~ s/background(=|:)\s?(["']?\w+[50]0\b)/_replace_material_bg( $1,$2)/egsm
            ;

        $self->{output} = $html ;
        # no longer cache the HTML as it may no longer be useful
        # $self->_store_cache( $cachefile, $html, 1 ) ;
    }
    return $self->{output} ;
}

# ----------------------------------------------------------------------------

=item save_to_file

save the created html to a named file

B<Parameters>
    filename    filename to store/convert stored HTML into
    pdfconvertor   indicate that we should use prince or wkhtmltopdf to create PDF

=cut

sub save_to_file
{
    state $counter = 0 ;
    my $self = shift ;
    my ( $filename, $pdfconvertor ) = @_ ;
    my ($format) = ( $filename =~ /\.(\w+)$/ ) ;  # get last thing after a '.'
    if ( !$format ) {
        warn "Could not determine output file format, using PDF" ;
        $format = '.pdf' ;
    }

    my $f = $self->_md5id() . ".html" ;

    # have we got the parsed data
    my $cf = cachefile( $self->cache_dir, $f ) ;
    if ( !$self->{output} ) {
        die "parse has not been run yet" ;
    }

    # if ( !-f $cf ) {
    if (1) {    # always save the HTML
        if ( !$self->use_cache() ) {

            # create a file name to store the output to
            $cf = "/tmp/" . get_program() . "$$." . $counter++ ;
        }

        # either update the cache, or create temp file
        # path($cf)->spew_utf8( encode_utf8( $self->{output} ) ) ;
        path($cf)->spew_utf8( $self->{output} ) ;
    }

    my $outfile = $cf ;
    $outfile =~ s/\.html$/.$format/i ;

    # if the marked-up file is more recent than the converted one
    # then we need to convert it again
    if ( $format !~ /html?/i ) {

        # as we can generate PDF using a number of convertors we should
        # always regenerate PDF output incase the convertor used is different
        if (   !-f $outfile
            || $format =~ /pdf/i
            || ( ( stat($cf) )[9] > ( stat($outfile) )[9] ) ) {
            $outfile = $self->_convert_file( $cf, $format, $pdfconvertor ) ;

            # if we failed to convert, then clear the filename
            if ( !$outfile || !-f $outfile ) {
                $outfile = undef ;
                debug( "ERROR",
                    "failed to create output file from cached file $cf" ) ;
            }
        }
    }

    my $status = 0 ;

    # now lets copy it to its final resting place
    if ($outfile) {
        try {
            $status = path($outfile)->copy($filename) ;
        }
        catch {
            say STDERR "$_ " ;
            debug( "ERROR", "failed to copy $outfile to $filename" ) ;
        } ;
    }
    return $status ;
}

=back

=cut

# ----------------------------------------------------------------------------

1 ;

__END__
