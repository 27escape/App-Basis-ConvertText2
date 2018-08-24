=head1 NAME

App::Basis::ConvertText2

=head1 SYNOPSIS

To be used in conjuction with the supplied ct2 script, which is part of this distribution.
Not really to be used on its own.

=head1 DESCRIPTION

This is a perl module and a script that makes use of fTITLE%

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
use utf8 ;

# ----------------------------------------------------------------------------
# this contents string is to be replaced with the body of the markdown file
# when it has been converted
use constant CONTENTS => '_CONTENTS_' ;
use constant PANDOC   => 'pandoc' ;
use constant PRINCE   => 'prince' ;
use constant WKHTML   => 'wkhtmltopdf' ;

my $BUILT_IN_BLOCKS = "(^buffer\$|^include\$|^ifand\$|^if\$)" ;
my $FONT_AWESOME_URL =
    "https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css" ;
my $GOOGLE_ICONS_URL = "https://fonts.googleapis.com/icon?family=Material+Icons" ;

# my $EMOJI_WEBSITE = http://www.emoji-cheat-sheet.com/graphics/emojis ;
my $EMOJI_WEBSITE = "https://www.webpagefx.com/tools/emoji-cheat-sheet/graphics/emojis" ;
# ----------------------------------------------------------------------------

# http://www.fileformat.info/info/unicode/category/So/list.htm
# not great matches in all cases but best that can be done when there is no support
# for emoji's
# smiles are the things that are emojis without enclosing ':'
my %smilies = (
    '<3'   => ":heart:",           # :fa:heart",      # heart
    '</3'  => ":broken_heart:",    # :fa:heart",      # heart
    ':)'   => ":smile:",           # :fa:smile-o",    # smile
    ':D'   => "\x{1f601}",         # grin
    '8-)'  => "\x{1f60e}",         # 😎, cool
    ':P'   => "\x{1f61b}",         # pull tounge
    ":'("  => "\x{1f62d}",         # cry
    ':('   => ":frowning:",        # ":fa:frown-o",    # sad
    ";)"   => "\x{1f609}",         # wink
    "(c)"  => "\x{a9}",            # copyright
    "(r)"  => "\x{ae}",            # registered
    "(tm)" => "\x{99}",            # trademark
    "+/-"  => "\x{00b1}",          # +-
) ;
# replace unicodes with imgs sugegsted by https://apps.timwhitlock.info/emoji/tables/unicode
# so in this case twitter ones
my %unicode_emoji = (
    "😀" => "1f600",
    "😁" => "1f601",
    "😂" => "1f602",
    "😃" => "1f603",
    "😄" => "1f604",
    "😅" => "1f605",
    "😆" => "1f606",
    "😇" => "1f607",
    "😈" => "1f608",
    "😉" => "1f609",
    "😊" => "1f60a",
    "😋" => "1f60b",
    "😌" => "1f60c",
    "😍" => "1f60d",
    "😎" => "1f60e",
    "😏" => "1f60f",

    "😐" => "1f610",
    "😑" => "1f611",
    "😒" => "1f612",
    "😓" => "1f613",
    "😔" => "1f614",
    "😕" => "1f615",
    "😖" => "1f616",
    "😗" => "1f617",
    "😘" => "1f618",
    "😙" => "1f619",
    "😚" => "1f61a",
    "😛" => "1f61b",
    "😜" => "1f61c",
    "😝" => "1f61d",
    "😞" => "1f61e",
    "😟" => "1f61f",

    "😠" => "1f620",
    "😡" => "1f621",
    "😢" => "1f622",
    "😣" => "1f623",
    "😤" => "1f624",
    "😥" => "1f625",
    "😦" => "1f626",
    "😧" => "1f627",
    "😨" => "1f628",
    "😩" => "1f629",
    "😪" => "1f62a",
    "😫" => "1f62b",
    "😬" => "1f62c",
    "😭" => "1f62d",
    "😮" => "1f62e",
    "😯" => "1f62f",

    "😰" => "1f630",
    "😱" => "1f631",
    "😲" => "1f632",
    "😳" => "1f633",
    "😴" => "1f634",
    "😵" => "1f635",
    "😶" => "1f636",
    "😷" => "1f637",
    "😸" => "1f638",
    "😹" => "1f639",
    "😺" => "1f63a",
    "😻" => "1f63b",
    "😼" => "1f63c",
    "😽" => "1f63d",
    "😾" => "1f63e",
    "😿" => "1f63f",

    "🙀" => "1f640",
    "🙁" => "1f641",
    "🙂" => "1f642",
    "🙃" => "1f643",
    "🙄" => "1f644",
    "🙅" => "1f645",
    "🙆" => "1f646",
    "🙇" => "1f647",
    "🙈" => "1f648",
    "🙉" => "1f649",
    "🙊" => "1f64a",
    "🙋" => "1f64b",
    "🙌" => "1f64c",
    "🙍" => "1f64d",
    "🙎" => "1f64e",
    "🙏" => "1f64f",
) ;

# some replacements are shortcuts to the emoji cheatsheet
my %emoji = (
    # snowman    => "\x{2603}",
    # heart      => ":fa:heart",                # heart
    # smile      => ":fa:smile-o",              # smile
    sad        => "disappointed",    # sad :fa:frown-o
    sleep      => ":fa:bed",         # sleep
                                     # zzz        => ":mi:snooze",               # snooze
    snooze     => ":mi:snooze",      # snooze
    halo       => "\x{1f607}",       # halo
    devil      => "\x{1f608}",       # 😈, devil
    horns      => "\x{1f608}",       # devil
    fear       => "\x{1f631}",       # fear
    c          => "\x{a9}",          # copyright
                                     # copyright  => "\x{a9}",            # copyright
    r          => "\x{ae}",          # registered
                                     # registered => "\x{ae}",            # registered
    tm         => "\x{99}",          # trademark
                                     # trademark  => "\x{99}",            # trademark
                                     # email      => ":fa:envelope-o",           # email
    yes        => "\x{2714}",        # tick / check
    no         => "\x{2718}",        # cross
                                     # beer       => ":fa:beer:[fliph]",             # beer
    wine       => "wine_glass",      # wine :fa:glass
    glass      => "wine_glass",      # wine
                                     # cake       => ":fa:birthday-cake",            # cake
                                     # star       => ":fa:star-o",               # star
    ok         => "ok_hand",         # ok = thumbsup :fa:thumbs-o-up:[fliph]
    thumbsup   => "thumbsup",        # thumbsup :fa:thumbs-o-up:[fliph]
    thumbsdown => "thumbsdown",      # thumbsdown :fa:thumbs-o-down:[fliph]
    bad        => "thumbsdown",      # bad = thumbsdown :fa:thumbs-o-down:[fliph]
    time       => "watch",           # time, watch face :fa:clock-o
    clock      => "clock2",          # time, watch face :fa:clock-o
                                     # hourglass  => ":fa:hourglass-o",              # hourglass
    dm =>
#        "<img class='emoji' src='http://icons.iconseeker.com/png/fullsize/danger-mouse/danger-mouse-logo.png' alt='' />",
        "<img class='emoji' src='http://i2.manchestereveningnews.co.uk/incoming/article7166481.ece/ALTERNATES/s1227b/danger-mouse-cover.jpg' alt='' />",
# "<img class='emoji' src='http://3hky4v206jda3tityl3u622q.wpengine.netdna-cdn.com/wp-content/uploads/2015/09/Danger-Mouse-download.jpg' alt='' />",
) ;

# _replace_emojis uses these
# these all come from http://www.emoji-cheat-sheet.com
# now http://www.webpagefx.com/tools/emoji-cheat-sheet/
my %emoji_cheatsheet = (
    bowtie                          => 1,
    smile                           => 1,
    laughing                        => 1,
    blush                           => 1,
    smiley                          => 1,
    relaxed                         => 1,
    smirk                           => 1,
    heart_eyes                      => 1,
    kissing_heart                   => 1,
    kissing_closed_eyes             => 1,
    flushed                         => 1,
    relieved                        => 1,
    satisfied                       => 1,
    grin                            => 1,
    wink                            => 1,
    stuck_out_tongue_winking_eye    => 1,
    stuck_out_tongue_closed_eyes    => 1,
    grinning                        => 1,
    kissing                         => 1,
    kissing_smiling_eyes            => 1,
    stuck_out_tongue                => 1,
    sleeping                        => 1,
    worried                         => 1,
    frowning                        => 1,
    anguished                       => 1,
    open_mouth                      => 1,
    grimacing                       => 1,
    confused                        => 1,
    hushed                          => 1,
    expressionless                  => 1,
    unamused                        => 1,
    sweat_smile                     => 1,
    sweat                           => 1,
    disappointed_relieved           => 1,
    weary                           => 1,
    pensive                         => 1,
    disappointed                    => 1,
    confounded                      => 1,
    fearful                         => 1,
    cold_sweat                      => 1,
    persevere                       => 1,
    cry                             => 1,
    sob                             => 1,
    joy                             => 1,
    astonished                      => 1,
    scream                          => 1,
    neckbeard                       => 1,
    tired_face                      => 1,
    angry                           => 1,
    rage                            => 1,
    triumph                         => 1,
    sleepy                          => 1,
    yum                             => 1,
    mask                            => 1,
    sunglasses                      => 1,
    dizzy_face                      => 1,
    imp                             => 1,
    smiling_imp                     => 1,
    neutral_face                    => 1,
    no_mouth                        => 1,
    innocent                        => 1,
    alien                           => 1,
    yellow_heart                    => 1,
    blue_heart                      => 1,
    purple_heart                    => 1,
    heart                           => 1,
    green_heart                     => 1,
    broken_heart                    => 1,
    heartbeat                       => 1,
    heartpulse                      => 1,
    two_hearts                      => 1,
    revolving_hearts                => 1,
    cupid                           => 1,
    sparkling_heart                 => 1,
    sparkles                        => 1,
    star                            => 1,
    star2                           => 1,
    dizzy                           => 1,
    boom                            => 1,
    collision                       => 1,
    anger                           => 1,
    exclamation                     => 1,
    question                        => 1,
    grey_exclamation                => 1,
    grey_question                   => 1,
    zzz                             => 1,
    dash                            => 1,
    sweat_drops                     => 1,
    notes                           => 1,
    musical_note                    => 1,
    fire                            => 1,
    hankey                          => 1,
    poop                            => 1,
    shit                            => 1,
    '+1'                            => 1,
    thumbsup                        => 1,
    '-1'                            => 1,
    thumbsdown                      => 1,
    ok_hand                         => 1,
    punch                           => 1,
    facepunch                       => 1,
    fist                            => 1,
    v                               => 1,
    wave                            => 1,
    hand                            => 1,
    raised_hand                     => 1,
    open_hands                      => 1,
    point_up                        => 1,
    point_down                      => 1,
    point_left                      => 1,
    point_right                     => 1,
    raised_hands                    => 1,
    pray                            => 1,
    point_up_2                      => 1,
    clap                            => 1,
    muscle                          => 1,
    metal                           => 1,
    fu                              => 1,
    runner                          => 1,
    running                         => 1,
    couple                          => 1,
    family                          => 1,
    two_men_holding_hands           => 1,
    two_women_holding_hands         => 1,
    dancer                          => 1,
    dancers                         => 1,
    ok_woman                        => 1,
    no_good                         => 1,
    information_desk_person         => 1,
    raising_hand                    => 1,
    bride_with_veil                 => 1,
    person_with_pouting_face        => 1,
    person_frowning                 => 1,
    bow                             => 1,
    couplekiss                      => 1,
    couple_with_heart               => 1,
    massage                         => 1,
    haircut                         => 1,
    nail_care                       => 1,
    boy                             => 1,
    girl                            => 1,
    woman                           => 1,
    man                             => 1,
    baby                            => 1,
    older_woman                     => 1,
    older_man                       => 1,
    person_with_blond_hair          => 1,
    man_with_gua_pi_mao             => 1,
    man_with_turban                 => 1,
    construction_worker             => 1,
    cop                             => 1,
    angel                           => 1,
    princess                        => 1,
    smiley_cat                      => 1,
    smile_cat                       => 1,
    heart_eyes_cat                  => 1,
    kissing_cat                     => 1,
    smirk_cat                       => 1,
    scream_cat                      => 1,
    crying_cat_face                 => 1,
    joy_cat                         => 1,
    pouting_cat                     => 1,
    japanese_ogre                   => 1,
    japanese_goblin                 => 1,
    see_no_evil                     => 1,
    hear_no_evil                    => 1,
    speak_no_evil                   => 1,
    guardsman                       => 1,
    skull                           => 1,
    feet                            => 1,
    lips                            => 1,
    kiss                            => 1,
    droplet                         => 1,
    ear                             => 1,
    eyes                            => 1,
    nose                            => 1,
    tongue                          => 1,
    love_letter                     => 1,
    bust_in_silhouette              => 1,
    busts_in_silhouette             => 1,
    speech_balloon                  => 1,
    thought_balloon                 => 1,
    feelsgood                       => 1,
    finnadie                        => 1,
    goberserk                       => 1,
    godmode                         => 1,
    hurtrealbad                     => 1,
    rage1                           => 1,
    rage2                           => 1,
    rage3                           => 1,
    rage4                           => 1,
    suspect                         => 1,
    trollface                       => 1,
    sunny                           => 1,
    umbrella                        => 1,
    cloud                           => 1,
    snowflake                       => 1,
    snowman                         => 1,
    zap                             => 1,
    cyclone                         => 1,
    foggy                           => 1,
    ocean                           => 1,
    cat                             => 1,
    dog                             => 1,
    mouse                           => 1,
    hamster                         => 1,
    rabbit                          => 1,
    wolf                            => 1,
    frog                            => 1,
    tiger                           => 1,
    koala                           => 1,
    bear                            => 1,
    pig                             => 1,
    pig_nose                        => 1,
    cow                             => 1,
    boar                            => 1,
    monkey_face                     => 1,
    monkey                          => 1,
    horse                           => 1,
    racehorse                       => 1,
    camel                           => 1,
    sheep                           => 1,
    elephant                        => 1,
    panda_face                      => 1,
    snake                           => 1,
    bird                            => 1,
    baby_chick                      => 1,
    hatched_chick                   => 1,
    hatching_chick                  => 1,
    chicken                         => 1,
    penguin                         => 1,
    turtle                          => 1,
    bug                             => 1,
    honeybee                        => 1,
    ant                             => 1,
    beetle                          => 1,
    snail                           => 1,
    octopus                         => 1,
    tropical_fish                   => 1,
    fish                            => 1,
    whale                           => 1,
    whale2                          => 1,
    dolphin                         => 1,
    cow2                            => 1,
    ram                             => 1,
    rat                             => 1,
    water_buffalo                   => 1,
    tiger2                          => 1,
    rabbit2                         => 1,
    dragon                          => 1,
    goat                            => 1,
    rooster                         => 1,
    dog2                            => 1,
    pig2                            => 1,
    mouse2                          => 1,
    ox                              => 1,
    dragon_face                     => 1,
    blowfish                        => 1,
    crocodile                       => 1,
    dromedary_camel                 => 1,
    leopard                         => 1,
    cat2                            => 1,
    poodle                          => 1,
    paw_prints                      => 1,
    bouquet                         => 1,
    cherry_blossom                  => 1,
    tulip                           => 1,
    four_leaf_clover                => 1,
    rose                            => 1,
    sunflower                       => 1,
    hibiscus                        => 1,
    maple_leaf                      => 1,
    leaves                          => 1,
    fallen_leaf                     => 1,
    herb                            => 1,
    mushroom                        => 1,
    cactus                          => 1,
    palm_tree                       => 1,
    evergreen_tree                  => 1,
    deciduous_tree                  => 1,
    chestnut                        => 1,
    seedling                        => 1,
    blossom                         => 1,
    ear_of_rice                     => 1,
    shell                           => 1,
    globe_with_meridians            => 1,
    sun_with_face                   => 1,
    full_moon_with_face             => 1,
    new_moon_with_face              => 1,
    new_moon                        => 1,
    waxing_crescent_moon            => 1,
    first_quarter_moon              => 1,
    waxing_gibbous_moon             => 1,
    full_moon                       => 1,
    waning_gibbous_moon             => 1,
    last_quarter_moon               => 1,
    waning_crescent_moon            => 1,
    last_quarter_moon_with_face     => 1,
    first_quarter_moon_with_face    => 1,
    crescent_moon                   => 1,
    earth_africa                    => 1,
    earth_americas                  => 1,
    earth_asia                      => 1,
    volcano                         => 1,
    milky_way                       => 1,
    partly_sunny                    => 1,
    octocat                         => 1,
    squirrel                        => 1,
    bamboo                          => 1,
    gift_heart                      => 1,
    dolls                           => 1,
    school_satchel                  => 1,
    mortar_board                    => 1,
    flags                           => 1,
    fireworks                       => 1,
    sparkler                        => 1,
    wind_chime                      => 1,
    rice_scene                      => 1,
    jack_o_lantern                  => 1,
    ghost                           => 1,
    santa                           => 1,
    christmas_tree                  => 1,
    gift                            => 1,
    bell                            => 1,
    no_bell                         => 1,
    tanabata_tree                   => 1,
    tada                            => 1,
    confetti_ball                   => 1,
    balloon                         => 1,
    crystal_ball                    => 1,
    cd                              => 1,
    dvd                             => 1,
    floppy_disk                     => 1,
    camera                          => 1,
    video_camera                    => 1,
    movie_camera                    => 1,
    computer                        => 1,
    tv                              => 1,
    iphone                          => 1,
    phone                           => 1,
    telephone                       => 1,
    telephone_receiver              => 1,
    pager                           => 1,
    fax                             => 1,
    minidisc                        => 1,
    vhs                             => 1,
    sound                           => 1,
    speaker                         => 1,
    mute                            => 1,
    loudspeaker                     => 1,
    mega                            => 1,
    hourglass                       => 1,
    hourglass_flowing_sand          => 1,
    alarm_clock                     => 1,
    watch                           => 1,
    radio                           => 1,
    satellite                       => 1,
    loop                            => 1,
    mag                             => 1,
    mag_right                       => 1,
    unlock                          => 1,
    lock                            => 1,
    lock_with_ink_pen               => 1,
    closed_lock_with_key            => 1,
    key                             => 1,
    bulb                            => 1,
    flashlight                      => 1,
    high_brightness                 => 1,
    low_brightness                  => 1,
    electric_plug                   => 1,
    battery                         => 1,
    calling                         => 1,
    email                           => 1,
    mailbox                         => 1,
    postbox                         => 1,
    bath                            => 1,
    bathtub                         => 1,
    shower                          => 1,
    toilet                          => 1,
    wrench                          => 1,
    nut_and_bolt                    => 1,
    hammer                          => 1,
    seat                            => 1,
    moneybag                        => 1,
    yen                             => 1,
    dollar                          => 1,
    pound                           => 1,
    euro                            => 1,
    credit_card                     => 1,
    money_with_wings                => 1,
    'e-mail'                        => 1,
    inbox_tray                      => 1,
    outbox_tray                     => 1,
    envelope                        => 1,
    incoming_envelope               => 1,
    postal_horn                     => 1,
    mailbox_closed                  => 1,
    mailbox_with_mail               => 1,
    mailbox_with_no_mail            => 1,
    package                         => 1,
    door                            => 1,
    smoking                         => 1,
    bomb                            => 1,
    gun                             => 1,
    hocho                           => 1,
    pill                            => 1,
    syringe                         => 1,
    page_facing_up                  => 1,
    page_with_curl                  => 1,
    bookmark_tabs                   => 1,
    bar_chart                       => 1,
    chart_with_upwards_trend        => 1,
    chart_with_downwards_trend      => 1,
    scroll                          => 1,
    clipboard                       => 1,
    calendar                        => 1,
    date                            => 1,
    card_index                      => 1,
    file_folder                     => 1,
    open_file_folder                => 1,
    scissors                        => 1,
    pushpin                         => 1,
    paperclip                       => 1,
    black_nib                       => 1,
    pencil2                         => 1,
    straight_ruler                  => 1,
    triangular_ruler                => 1,
    closed_book                     => 1,
    green_book                      => 1,
    blue_book                       => 1,
    orange_book                     => 1,
    notebook                        => 1,
    notebook_with_decorative_cover  => 1,
    ledger                          => 1,
    books                           => 1,
    bookmark                        => 1,
    name_badge                      => 1,
    microscope                      => 1,
    telescope                       => 1,
    newspaper                       => 1,
    football                        => 1,
    basketball                      => 1,
    soccer                          => 1,
    baseball                        => 1,
    tennis                          => 1,
    '8ball'                         => 1,
    rugby_football                  => 1,
    bowling                         => 1,
    golf                            => 1,
    mountain_bicyclist              => 1,
    bicyclist                       => 1,
    horse_racing                    => 1,
    snowboarder                     => 1,
    swimmer                         => 1,
    surfer                          => 1,
    ski                             => 1,
    spades                          => 1,
    hearts                          => 1,
    clubs                           => 1,
    diamonds                        => 1,
    gem                             => 1,
    ring                            => 1,
    trophy                          => 1,
    musical_score                   => 1,
    musical_keyboard                => 1,
    violin                          => 1,
    space_invader                   => 1,
    video_game                      => 1,
    black_joker                     => 1,
    flower_playing_cards            => 1,
    game_die                        => 1,
    dart                            => 1,
    mahjong                         => 1,
    clapper                         => 1,
    memo                            => 1,
    pencil                          => 1,
    book                            => 1,
    art                             => 1,
    microphone                      => 1,
    headphones                      => 1,
    trumpet                         => 1,
    saxophone                       => 1,
    guitar                          => 1,
    shoe                            => 1,
    sandal                          => 1,
    high_heel                       => 1,
    lipstick                        => 1,
    boot                            => 1,
    shirt                           => 1,
    tshirt                          => 1,
    necktie                         => 1,
    womans_clothes                  => 1,
    dress                           => 1,
    running_shirt_with_sash         => 1,
    jeans                           => 1,
    kimono                          => 1,
    bikini                          => 1,
    ribbon                          => 1,
    tophat                          => 1,
    crown                           => 1,
    womans_hat                      => 1,
    mans_shoe                       => 1,
    closed_umbrella                 => 1,
    briefcase                       => 1,
    handbag                         => 1,
    pouch                           => 1,
    purse                           => 1,
    eyeglasses                      => 1,
    fishing_pole_and_fish           => 1,
    coffee                          => 1,
    tea                             => 1,
    sake                            => 1,
    baby_bottle                     => 1,
    beer                            => 1,
    beers                           => 1,
    cocktail                        => 1,
    tropical_drink                  => 1,
    wine_glass                      => 1,
    fork_and_knife                  => 1,
    pizza                           => 1,
    hamburger                       => 1,
    fries                           => 1,
    poultry_leg                     => 1,
    meat_on_bone                    => 1,
    spaghetti                       => 1,
    curry                           => 1,
    fried_shrimp                    => 1,
    bento                           => 1,
    sushi                           => 1,
    fish_cake                       => 1,
    rice_ball                       => 1,
    rice_cracker                    => 1,
    rice                            => 1,
    ramen                           => 1,
    stew                            => 1,
    oden                            => 1,
    dango                           => 1,
    egg                             => 1,
    bread                           => 1,
    doughnut                        => 1,
    custard                         => 1,
    icecream                        => 1,
    ice_cream                       => 1,
    shaved_ice                      => 1,
    birthday                        => 1,
    cake                            => 1,
    cookie                          => 1,
    chocolate_bar                   => 1,
    candy                           => 1,
    lollipop                        => 1,
    honey_pot                       => 1,
    apple                           => 1,
    green_apple                     => 1,
    tangerine                       => 1,
    lemon                           => 1,
    cherries                        => 1,
    grapes                          => 1,
    watermelon                      => 1,
    strawberry                      => 1,
    peach                           => 1,
    melon                           => 1,
    banana                          => 1,
    pear                            => 1,
    pineapple                       => 1,
    sweet_potato                    => 1,
    eggplant                        => 1,
    tomato                          => 1,
    corn                            => 1,
    house                           => 1,
    house_with_garden               => 1,
    school                          => 1,
    office                          => 1,
    post_office                     => 1,
    hospital                        => 1,
    bank                            => 1,
    convenience_store               => 1,
    love_hotel                      => 1,
    hotel                           => 1,
    wedding                         => 1,
    church                          => 1,
    department_store                => 1,
    european_post_office            => 1,
    city_sunrise                    => 1,
    city_sunset                     => 1,
    japanese_castle                 => 1,
    european_castle                 => 1,
    tent                            => 1,
    factory                         => 1,
    tokyo_tower                     => 1,
    japan                           => 1,
    mount_fuji                      => 1,
    sunrise_over_mountains          => 1,
    sunrise                         => 1,
    stars                           => 1,
    statue_of_liberty               => 1,
    bridge_at_night                 => 1,
    carousel_horse                  => 1,
    rainbow                         => 1,
    ferris_wheel                    => 1,
    fountain                        => 1,
    roller_coaster                  => 1,
    ship                            => 1,
    speedboat                       => 1,
    boat                            => 1,
    sailboat                        => 1,
    rowboat                         => 1,
    anchor                          => 1,
    rocket                          => 1,
    airplane                        => 1,
    helicopter                      => 1,
    steam_locomotive                => 1,
    tram                            => 1,
    mountain_railway                => 1,
    bike                            => 1,
    aerial_tramway                  => 1,
    suspension_railway              => 1,
    mountain_cableway               => 1,
    tractor                         => 1,
    blue_car                        => 1,
    oncoming_automobile             => 1,
    car                             => 1,
    red_car                         => 1,
    taxi                            => 1,
    oncoming_taxi                   => 1,
    articulated_lorry               => 1,
    bus                             => 1,
    oncoming_bus                    => 1,
    rotating_light                  => 1,
    police_car                      => 1,
    oncoming_police_car             => 1,
    fire_engine                     => 1,
    ambulance                       => 1,
    minibus                         => 1,
    truck                           => 1,
    train                           => 1,
    station                         => 1,
    train2                          => 1,
    bullettrain_front               => 1,
    bullettrain_side                => 1,
    light_rail                      => 1,
    monorail                        => 1,
    railway_car                     => 1,
    trolleybus                      => 1,
    ticket                          => 1,
    fuelpump                        => 1,
    vertical_traffic_light          => 1,
    traffic_light                   => 1,
    warning                         => 1,
    construction                    => 1,
    beginner                        => 1,
    atm                             => 1,
    slot_machine                    => 1,
    busstop                         => 1,
    barber                          => 1,
    hotsprings                      => 1,
    checkered_flag                  => 1,
    crossed_flags                   => 1,
    izakaya_lantern                 => 1,
    moyai                           => 1,
    circus_tent                     => 1,
    performing_arts                 => 1,
    round_pushpin                   => 1,
    triangular_flag_on_post         => 1,
    jp                              => 1,
    kr                              => 1,
    cn                              => 1,
    us                              => 1,
    fr                              => 1,
    es                              => 1,
    it                              => 1,
    ru                              => 1,
    gb                              => 1,
    uk                              => 1,
    de                              => 1,
    one                             => 1,
    two                             => 1,
    three                           => 1,
    four                            => 1,
    five                            => 1,
    six                             => 1,
    seven                           => 1,
    eight                           => 1,
    nine                            => 1,
    keycap_ten                      => 1,
    1234                            => 1,
    zero                            => 1,
    hash                            => 1,
    symbols                         => 1,
    arrow_backward                  => 1,
    arrow_down                      => 1,
    arrow_forward                   => 1,
    arrow_left                      => 1,
    capital_abcd                    => 1,
    abcd                            => 1,
    abc                             => 1,
    arrow_lower_left                => 1,
    arrow_lower_right               => 1,
    arrow_right                     => 1,
    arrow_up                        => 1,
    arrow_upper_left                => 1,
    arrow_upper_right               => 1,
    arrow_double_down               => 1,
    arrow_double_up                 => 1,
    arrow_down_small                => 1,
    arrow_heading_down              => 1,
    arrow_heading_up                => 1,
    leftwards_arrow_with_hook       => 1,
    arrow_right_hook                => 1,
    left_right_arrow                => 1,
    arrow_up_down                   => 1,
    arrow_up_small                  => 1,
    arrows_clockwise                => 1,
    arrows_counterclockwise         => 1,
    rewind                          => 1,
    fast_forward                    => 1,
    information_source              => 1,
    ok                              => 1,
    twisted_rightwards_arrows       => 1,
    repeat                          => 1,
    repeat_one                      => 1,
    new                             => 1,
    top                             => 1,
    up                              => 1,
    cool                            => 1,
    free                            => 1,
    ng                              => 1,
    cinema                          => 1,
    koko                            => 1,
    signal_strength                 => 1,
    u5272                           => 1,
    u5408                           => 1,
    u55b6                           => 1,
    u6307                           => 1,
    u6708                           => 1,
    u6709                           => 1,
    u6e80                           => 1,
    u7121                           => 1,
    u7533                           => 1,
    u7a7a                           => 1,
    u7981                           => 1,
    sa                              => 1,
    restroom                        => 1,
    mens                            => 1,
    womens                          => 1,
    baby_symbol                     => 1,
    no_smoking                      => 1,
    parking                         => 1,
    wheelchair                      => 1,
    metro                           => 1,
    baggage_claim                   => 1,
    accept                          => 1,
    wc                              => 1,
    potable_water                   => 1,
    put_litter_in_its_place         => 1,
    secret                          => 1,
    congratulations                 => 1,
    m                               => 1,
    passport_control                => 1,
    left_luggage                    => 1,
    customs                         => 1,
    ideograph_advantage             => 1,
    cl                              => 1,
    sos                             => 1,
    id                              => 1,
    no_entry_sign                   => 1,
    underage                        => 1,
    no_mobile_phones                => 1,
    do_not_litter                   => 1,
    'non-potable_water'             => 1,
    no_bicycles                     => 1,
    no_pedestrians                  => 1,
    children_crossing               => 1,
    no_entry                        => 1,
    eight_spoked_asterisk           => 1,
    sparkle                         => 1,
    eight_pointed_black_star        => 1,
    heart_decoration                => 1,
    vs                              => 1,
    vibration_mode                  => 1,
    mobile_phone_off                => 1,
    chart                           => 1,
    currency_exchange               => 1,
    aries                           => 1,
    taurus                          => 1,
    gemini                          => 1,
    cancer                          => 1,
    leo                             => 1,
    virgo                           => 1,
    libra                           => 1,
    scorpius                        => 1,
    sagittarius                     => 1,
    capricorn                       => 1,
    aquarius                        => 1,
    pisces                          => 1,
    ophiuchus                       => 1,
    six_pointed_star                => 1,
    negative_squared_cross_mark     => 1,
    a                               => 1,
    b                               => 1,
    ab                              => 1,
    o2                              => 1,
    diamond_shape_with_a_dot_inside => 1,
    recycle                         => 1,
    end                             => 1,
    back                            => 1,
    on                              => 1,
    soon                            => 1,
    clock1                          => 1,
    clock130                        => 1,
    clock10                         => 1,
    clock1030                       => 1,
    clock11                         => 1,
    clock1130                       => 1,
    clock12                         => 1,
    clock1230                       => 1,
    clock2                          => 1,
    clock230                        => 1,
    clock3                          => 1,
    clock330                        => 1,
    clock4                          => 1,
    clock430                        => 1,
    clock5                          => 1,
    clock530                        => 1,
    clock6                          => 1,
    clock630                        => 1,
    clock7                          => 1,
    clock730                        => 1,
    clock8                          => 1,
    clock830                        => 1,
    clock9                          => 1,
    clock930                        => 1,
    heavy_dollar_sign               => 1,
    copyright                       => 1,
    registered                      => 1,
    tm                              => 1,
    x                               => 1,
    heavy_exclamation_mark          => 1,
    bangbang                        => 1,
    interrobang                     => 1,
    o                               => 1,
    heavy_multiplication_x          => 1,
    heavy_plus_sign                 => 1,
    heavy_minus_sign                => 1,
    heavy_division_sign             => 1,
    white_flower                    => 1,
    100                             => 1,
    heavy_check_mark                => 1,
    ballot_box_with_check           => 1,
    radio_button                    => 1,
    link                            => 1,
    curly_loop                      => 1,
    wavy_dash                       => 1,
    part_alternation_mark           => 1,
    trident                         => 1,
    black_small_square              => 1,
    white_small_square              => 1,
    black_medium_small_square       => 1,
    white_medium_small_square       => 1,
    black_medium_square             => 1,
    white_medium_square             => 1,
    black_large_square              => 1,
    white_large_square              => 1,
    white_check_mark                => 1,
    black_square_button             => 1,
    white_square_button             => 1,
    black_circle                    => 1,
    white_circle                    => 1,
    red_circle                      => 1,
    large_blue_circle               => 1,
    large_blue_diamond              => 1,
    large_orange_diamond            => 1,
    small_blue_diamond              => 1,
    small_orange_diamond            => 1,
    small_red_triangle              => 1,
    small_red_triangle_down         => 1,
    shipit                          => 1
) ;

my $smiles   = join( '|', map { quotemeta($_) } keys %smilies ) ;
my $unicodes = join( '|', map { quotemeta($_) } keys %unicode_emoji ) ;

# ----------------------------------------------------------------------------

my $TITLE = "%TITLE%" ;

# ----------------------------------------------------------------------------

has 'name'     => ( is => 'ro', ) ;
has 'basedir'  => ( is => 'ro', ) ;
has 'filename' => ( is => 'ro', ) ;

has 'use_cache' => ( is => 'rw', default => sub { 0 ; } ) ;
has 'commoncss' => ( is => 'ro', ) ;

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

has 'commands' => (
    is      => 'ro',
    default => sub {""},
) ;
has '_commands' => (
    is       => 'ro',
    default  => sub { {} },
    init_arg => 0
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
    filename    - name of the file that would be processed
    basedir     - root directory of document being processed
    cache_dir   - place to store cache files - optional
    use_cache   - decide if you want to use a cache or not
    template    - HTML template to use, must contain %_CONTENTS_%
    commands    - path to find any script commands to run as blocks
    commoncss   - CSS to use for any template
    replace     - hashref of extra keywords to use as replaceable variables

=cut

sub BUILD
{
    my $self = shift ;

    die "No name provided" if ( !$self->name() ) ;

    if ( $self->use_cache() ) {

        # need to add the name to the cache dirname to make it distinct
        $self->_set_cache_dir( fix_filename( $self->cache_dir() . "/" . $self->name() ) ) ;

        if ( !-d $self->cache_dir() ) {

            # create the cache dir if needed
            try {
                path( $self->cache_dir() )->mkpath ;
            }
            catch { } ;
            die "Could not create cache dir " . $self->cache_dir()
                if ( !-d $self->cache_dir() ) ;
        }
    }

    # find any block commands that we can use
    if ( $self->{commands} && -d $self->{commands} ) {
        path( $self->{commands} )->visit(
            sub {
                my ( $path, $state ) = @_ ;
                # needs to be a file and executable
                return if ( !$path->is_file || !-x $path ) ;
                my $c = $path->basename ;
                # cannot use buffer or include as its a built in
                next if ( $c =~ /$BUILT_IN_BLOCKS/ ) ;
                $self->{_commands}->{$c} = $path->stringify ;
            },
            { recurse => 0, follow_symlinks => 1 },
        ) ;
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

            if ( $self->{_commands}->{$h} ) {
                warn
                    "Plugin $plug cannot provide a handler for $h, as a block command has been defined with the same name"
                    ;
                next ;
            }

            if ( $h =~ /(^buffer$|^include)$/ ) {
                warn
                    "Plugin $plug cannot provide a handler for $h, as this is already provided for internally"
                    ;
                next ;
            }

            if ( has_block($h) ) {
                warn
                    "Plugin $plug cannot provide a handler for $h, as this has already been provided by another plugin"
                    ;
                next ;
            }

            # all handlers are lower case
            add_block( $h, $obj ) ;
        }
    }

    # buffer is a special internal handler
    add_block( 'buffer',  1 ) ;
    add_block( 'include', 1 ) ;
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
    try {
        if ( -f $f ) {
            if ($utf8) {
                $result = path($f)->slurp_utf8 ;
            } else {
                $result = path($f)->slurp_raw ;
            }
        }
    } ;
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
# ifnot will only allow add to the buffer if the buffer is empty
sub _add_replace
{
    my $self = shift ;
    my ( $key, $val, $append, $ifnot ) = @_ ;

    if ($append) {
        $self->{replace}->{ uc($key) } .= "$val\n" ;
    } else {
        if ( !$ifnot || ( $ifnot && !$self->{replace}->{ uc($key) } ) ) {
            $self->{replace}->{ uc($key) } = $val ;
        }
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
            # not been escaped \%VARIABLE% should be left alone
            $content =~ s/(?<!\\)%$k%/$self->{replace}->{$k}/gsm ;
        }
    }

    return $content ;
}

# ----------------------------------------------------------------------------
# run the command associated with the block
# will return undef if there were issues, ideally write to STDOUT too
sub _pipe_command
{
    my $self = shift ;
    my ( $block, $content, $params, $linenum ) = @_ ;

    return undef
        if ( !$self->{_commands}->{$block}
        || !-f $self->{_commands}->{$block}
        || !-x $self->{_commands}->{$block} ) ;

    # remove some params that may already have been used
    map { delete $params->{$_} ; } qw{ from to from_buffer to_buffer file include} ;
    my $command = "$self->{_commands}->{$block} --linenum=$linenum" ;
    # pass in verbose option if needed, eg for testing commands
    $command .= ( is_verbose() ? " -v" : "" ) ;
    # add in the arguments, taken from the parameters
    foreach my $k ( keys %{$params} ) {
        my $c = " " ;
        $params->{$k} //= "" ;
        # assuming that single letter params are short args
        $params->{$k} =~ s/'/\'/g ;      # escape all double quotes
        $params->{$k} =~ s/\$'/\$/g ;    # escape dollar to ensure its not an environment variable
        if ( length($k) == 1 ) {
            $c .= "-$k '$params->{$k}'" ;
        } else {
            $c .= "--$k='$params->{$k}'" ;
        }
        $command .= "$c " ;
    }

    # so the child_stdin piping does not like LFs, it thinks its the end of the data
    # we need to escape it
    #$content =~ s/\n/\n/g ;
    # shell code blocks get replaces by our fenced ones
    #$content =~ s/^`{4}/~~~~/gsm ;
    if ($content) {
        $content =~ s/\n/\n/g ;
        # shell code blocks get replaces by our fenced ones
        $content =~ s/^`{4}/~~~~/gsm ;
        $command .= ' --has_content=1' ;
        $content .= "\n" ;                 # need to make sure of trailing LF
                                           # prep for printing
        utf8::encode($content) ;
    }
    # add in some useful things for the script
    $command
        .= " --doc_ref='" . $self->filename . "' " . "--cachedir='" . $self->cache_dir() . "' " ;
    # verbose("running $command") ;
    my ($resp) = execute_cmd(
        command     => $command,
        timeout     => 60,
        child_stdin => $content
    ) ;
    my $out ;
    if ( !$resp->{exit_code} ) {
        $out = $resp->{stdout} ;
        # remove trailing CR in case we are being used inline in something like a .table construct
        chomp $out ;
        # continue with the verbosity
        if ( is_verbose() && $resp->{stderr} ) {
            verbose( $resp->{stderr} ) ;
        }
    } else {
        warn "Issue runing $block: $resp->{stderr}" ;
        $out = $resp->{stderr} ;
    }

    return $out ;
}

# ----------------------------------------------------------------------------
sub _call_function
{
    my $self = shift ;
    my ( $block, $params, $content, $linenum ) = @_ ;
    my $out ;
    my $content_removed = 0 ;
    my $conditional     = 0 ;

    $content ||= "" ;

    if ( has_block($block) || $self->{_commands}->{$block} ) {
        try {

            # buffer is a special construct to allow us to hold output of content
            # for later, allows multiple use of content or adding things to
            # markdown tables that otherwise we could not do

            # we can use variables in the parameter values, lets find out
            foreach my $k ( keys %$params ) {
                $params->{$k} = $self->_do_replacements( $params->{$k} ) ;
            }

            # over-ride content with buffered content
            my $from = $params->{from} || $params->{from_buffer} ;
            if ($from) {
                $from = uc($from) ;
                # merge the content with things from a buffer
                if ( $params->{merge} ) {
                    if ( $params->{merge} eq 'before' ) {
                        $content .= "\n" . $self->{replace}->{$from} ;
                    } else {
                        $self->{replace}->{$from} ||= "" ;
                        $content = $self->{replace}->{$from} . ( $content ? "\n$content" : "" ) ;
                    }
                    # do not pass this on to other block handlers
                    delete $params->{merge} ;
                } else {
                    $content = $self->{replace}->{$from} ;
                }
            }

            # get the content from the args, useful for short blocks
            if ( $params->{content} ) {
                $content = $params->{content} ;
            }
            if ( $params->{file} ) {
                if ( $block eq 'include' ) {
                    my $pstr = join( " ", map { "$_='$params->{$_}'" ; } keys %$params ) ;
                    $out = $self->_include_file($pstr) ;
                } else {
                    $content = $self->_include_file("file='$params->{file}' nodiv=1") ;
                }
            }

            my $to = $params->{to} || $params->{to_buffer} ;

            if ( $block eq 'buffer' ) {
                if ($to) {
                    # we could be appending to a named buffer also
                    $self->_add_replace( $to, $content, $params->{add}, $params->{ifnot} ) ;
                }
            } elsif ( $block eq 'include' ) {
                # this has already been handled above, need to make sure nothing else going on too
            } else {
                # do any replacements we know about in the content block
                $content = $self->_do_replacements($content) ;

                # run the plugin with the data we have
                my $explain = $params->{explain} ;
                delete $params->{explain} ;

                # test if we have conditional display of the block
                my $before = $content ;
                for my $cond (qw/if ifand/) {
                    if ( $params->{$cond} ) {
                        $conditional++ ;
                        $content = $self->_conditional_text( $cond, $params->{$cond}, $content ) ;
                    }
                }
                if ( $content ne $before ) {
                    $content_removed = 1 ;
                }

                if ( !$content_removed ) {
                    if ( $self->{_commands}->{$block} ) {
                        # run the plugin with the data we have
                        $out = $self->_pipe_command( $block, $content, $params, $linenum ) ;
                    } else {
                        $out =
                            run_block( $block, $content, $params, $self->cache_dir(), $linenum ) ;
                    }
                }

                if ($explain) {
                    my $title = "Explain: $block" ;
                    if ( $explain ne '1' ) {
                        $title .= " $explain" ;
                    }
                    $explain = $content ;
                    $explain =~ s/^/ /gsm ;
                    my $pstring =
                        join( " ",
                        map { $params->{$_} ? "$_='$params->{$_}'" : "" } keys %$params ) ;
                    $pstring =~ s/\s*$// ;
                    $explain =
                          "<div class='ol_wrapper'><div class='ol_left'>&nbsp;$title</div>\n"
                        . "\n~~~~{.box}\n<pre> ~~~~{.$block $pstring}\n$explain\n ~~~~</pre>\n~~~~\n\n"
                        . "</div>\n\n" ;
                    # put explanation first
                    $out = "$explain\n\n$out" ;
                }

                if ( !$content_removed ) {
                    # we are only concerned about doing the right thing if there was content
                    if ( !defined $out ) {
                        # if we could not generate any output, lets put the block back together,
                        #make sure is on a clean line
                        $out .= "\n~~~~{.$block "
                            . join( " ",
                            map { $params->{$_} ||= "" ; "$_='$params->{$_}'" } keys %{$params} )
                            . " }\n"
                            . "~~~~\n" ;
                    } elsif ($to) {
                        # do we want to buffer the output?
                        $self->_add_replace( $to, $out ) ;

                        # option not to show the output
                        # $out = "" if ( $params->{no_output} ) ;
                        # now the default, if we are using to or to_buffer
                        # then there is no output
                        $out = "" ;
                    }
                } else {
                    $out = "" ;
                }
            }
            # $self->_append_output("$out\n") if ( defined $out ) ;
        }
        catch {
            debug( "ERROR", "failed processing $block near line $linenum, $_" ) ;
            warn "Issue processing $block around line $linenum ($_)" ;
# if we could not generate any output, lets put the block back together, make sure is on a clean line
            $out
                .= "\n~~~~{.$block "
                . join( " ", map { $params->{$_} ||= "" ; "$_='$params->{$_}'" } keys %{$params} )
                . " }\n"
                . "~~~~\n" ;
            # $self->_append_output($out) ;
        } ;
    } else {
        debug( "ERROR:", "no valid handler for $block" ) ;
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

    eval {
        if ( $self->{_commands}->{$block} || has_block($block) ) {
            $out = $self->_call_function( $block, $params, $params->{content}, 0 ) || "" ;
        } else {
            # build the short block back together, if we do not have a match
            $out = "{{.block $attributes}}" ;
        }
    } ;
    if ($@) {
        verbose("something died - $block") ;
    }
    return $out ;
}

# ----------------------------------------------------------------------------
### _parse_lines
# parse the passed data
sub _parse_lines
{
    my $self = shift ;
    my ( $data, $pass ) = @_ ;
    my $count     = 0 ;
    my $curr_line = "" ;

    return if ( !$data ) ;

    # replace Admonition paragraphs with a proper block
    $data
        =~ s/^(BOX|NOTE|INFO|TIP|IMPORTANT|CAUTION|WARN|WARNING|DANGER|TODO|ASIDE|QUESTION|FIXME|ERROR|READ|SAMPLE|CONSOLE)(\(\N*\))?:(.*?)\n\n/_rewrite_admonitions( $1, $2, $3)/egsm
        ;
    # need to do include replacements after any additional YAML header items are found
    $data =~ s/\{\{.(include|import)\s+(\N*?)\}\}/$self->_include_file($2)/iesgm ;
    $data =~ s/^~~~~\{.(include|import)\s+(\N*?)\}.*?~~~~/$self->_include_file($2)/iesgm ;

    # have conditional blocks like normal ones .if .ifand
    # $data =~ s/\{\{.(if|ifand)\s+(.*?)\}\}/$self->_conditional_text($1, $2)/iesgm ;
    # $data =~ s/^~~~~\{.(if|ifand)\s+(.*?)\}(.*?)~~~~/$self->_conditional_text($1, $2, $3)/iesgm ;
    # conditional blocks as  <if> <ifand> so we can inline ~~~~ blocks
    $data =~ s/^<(if|ifand)\s+(.*?)>(.*?)<\/\1>/$self->_conditional_text($1, $2, $3)/iesgm ;

    my ( $class, $block, $content, $attributes ) ;
    my ( $buildline, $simple ) ;
    try {
        foreach my $line ( split( /\n/, $data ) ) {
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
            $line =~ s/\{\{\.(\w+)(\b.*?)\}\}/$self->_rewrite_short_block( $1, $2)/egs ;

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

                    if ( $params->{unindent} ) {
                        $content =~ s/^\s{4}//gsm ;
                    }

                    # must have reached the end of a block
                    if ( $self->{_commands}->{$block} || has_block($block) ) {
                        chomp $content if ($content) ;
                        my $out = $self->_call_function( $block, $params, $content, $count ) ;
                        # not all blocks output things, eg buffer operations
                        if ($out) {
                            # add extra line to make sure things are spaced away from other content
                            $self->_append_output("$out\n\n") ;
                        }
                    } else {
                        if ( !$block ) {
                            # put it back, if not on second pass
                            $content ||= "" ;
                            if ( $pass <= 1 ) {
                                $self->_append_output("~~~~\n$content\n~~~~\n\n") ;
                            }
                        } else {
                            $content    ||= "" ;
                            $attributes ||= "" ;
                            $block      ||= "" ;

                            # only rebuild the block if it was not meant to be conditional
                            if ( !( $params->{if} || $params->{ifand} || $params->{ifnot} ) ) {
                                if ( $pass == 2 ) {
                           # nre pandoc builds codeblocks slightly differently so we need to wrap it
                                    $self->_append_output(
                                        "<div class='codeblock'>\n\n~~~~ {$class .$block $attributes}\n$content\n~~~~\n\n</div>\n\n"
                                    ) ;
                                } else {
                                    $self->_append_output(
                                        "~~~~{$class.$block $attributes}\n$content\n~~~~\n\n") ;
                                }
                            }
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

    # this allows us to put short blocks as output of other blocks or inline
    # with things that might otherwise not allow them
    # we use the single line parse version too
    # short tags cannot have the form
    # {{.class .tag args=123}}

    $self->{output} =~ s/\{\{\.(\w+)(\b.*?)\}\}/$self->_rewrite_short_block( $1, $2)/egs
        if ( $self->{output} ) ;
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
                        debug( "ERROR", "failed to copy $img to $cachefile" ) ;
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
                        .= " height='" . $image->height() . "' width='" . $image->width() . "' />" ;
                }
            }

            # do we need to embed the images, if we do this then libreoffice may be pants
            # however princexml is happy

            # we encode the image as base64 so that the HTML document can be moved with all images
            # intact
            # it is possible that we failed to download the file, double check the img URL
            if ( $img !~ m|\w+://| ) {
                # if the file does not exist we don't want to break badly
                try {
                    my $base64 = MIME::Base64::encode( path($img)->slurp_raw ) ;
                    $img = "data:image/$ext;base64,$base64" ;
                } ;    # ignore the catch, nothing is getting changed
            }
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
    my @items = ( $html =~ m|<h([23456]).*?><a name=['"](.*?)['"]>(.*?)</a></h\1>|gsmi ) ;

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
        $pre = "$counters->{2}.$counters->{3}.$counters->{4}.$counters->{5}.$counters->{6}" ;
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
    my ( $input, $highlite ) = @_ ;

    $highlite ||= 'kate' ;

    my $paninput  = Path::Tiny->tempfile("pandoc.in.XXXX") ;
    my $panoutput = Path::Tiny->tempfile("pandoc.out.XXXX") ;
    # new pandoc does nasty things with &nbsp; for some reason, better to replace them like this
    $input =~ s|&nbsp;|\\ |gsm ;
    path($paninput)->spew_utf8($input) ;
    # my $debug_file = "/tmp/pandoc.$$.md" ;
    # path( $debug_file)->spew_utf8($input) ;

    my $markdown_mode = "markdown" ;
    # make the mode do what we want markdown to be like

    # now add in nice extras we want
    $markdown_mode .= "+fancy_lists+example_lists+startnum+superscript+subscript+grid_tables" ;

    my $command =
          PANDOC
        . " -s --ascii --email-obfuscation=none"
        . " -f $markdown_mode"
        . " --strip-comments -t html5 "
        . " --highlight-style='$highlite' --mathml "
        . " '$paninput' -o '$panoutput'" ;

    verbose($command) ;

    my $resp = execute_cmd(
        command => $command,
        timeout => 30,
    ) ;

    my $html ;

    debug( "Pandoc: " . $resp->{stderr} ) if ( $resp->{stderr} ) ;
    if ( !$resp->{exit_code} ) {
        try {
            $html = path($panoutput)->slurp_utf8() ;
        } ;

        # path("/tmp/pandoc.html")->spew_utf8($html) ;

        # this will have html headers and footers, and style information, we need to dump these
        $html =~ s/(<!DOCTYPE.*?<body>)//gsm ;
        $html =~ s/^<\/body>\n<\/html>//gsm ;
        # remove any footnotes hr
        $html =~ s/(<section class="footnotes">)\n<hr \/>/<h2>Footnotes<\/h2>\n$1/gsm ;
    } else {
        my $err = $resp->{stderr} || "" ;
        chomp $err ;
        # debug( "INFO", "cmd [$command]") ;
        debug( "ERROR", "Could not parse with pandoc, using Markdown, $err" ) ;
        warn "Could not parse with pandoc, using Markdown " . $resp->{stderr} ;
    }

    # strip out any HTML comments that may have come in from templates etc
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
            # so we can do some clever things if needed
            # hopefully the user is only using serif, sans-serif and monotype fonts
            $cmd = PRINCE . " --no-embed-fonts --javascript --input=html5 " ;
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
    my ( $tag, $title, $content ) = @_ ;
    if ($title) {
        # remove brackets
        $title =~ s/^\(|\)//g ;
        $title = " title='$title' " ;
    } else {
        $title = "" ;
    }
    # say STDERR "title is $title, content is $content" ;

    $content =~ s/^\s+|\s+$//gsm ;

    # same same
    $tag = 'warning' if ( $tag eq 'WARN' ) ;

    my $out = "\n~~~~{." . lc($tag) . "$title icon=1}\n$content\n~~~~\n\n" ;

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

            if ( $class =~ s/#(([\w\-]+)?\.?([\w\-]+)?)// ) {
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
        $out = "<i class='fa fa-$icon $class'" . ( $style ? " style='$style'" : "" ) ;
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
    my $base_em = 0.7 ;

    $icon =~ s/^mi-// if ($icon) ;
    if ( !$demo ) {
        my $style = "" ;
        my @colors ;
        if ($class) {
            $class =~ s/^\[|\]$//g ;
            # $class =~ s/\b(fw|lg|border)\b/mi-$1/ ;
            if ( $class =~ /\blg\b/ ) {
                my $em = $base_em * 1.5 ;
                $style .= "font-size:$em" . "em;" ;
                $class =~ s/\blg\b// ;
            } elsif ( $class =~ /\b([2345])x\b/ ) {
                my $em = $base_em * $1 ;
                $style .= "font-size:$em" . "em;" ;
                $class =~ s/\b[2345]x\b// ;
            }
            $class =~ s/\b(90|180|270)\b/rotate-$1/ ;
            $class =~ s/\bflipv\b/flip-vertical/ ;
            $class =~ s/\bfliph\b/flip-horizontal/ ;

            if ( $class =~ s/#(([\w\-]+)?\.?([\w\-]+)?)// ) {
                my ( $fg, $bg ) = ( $2, $3 ) ;
                $style .= "color:" . to_hex_color($fg) . ";" if ($fg) ;
                $style .= "background-color:" . to_hex_color($bg) . ";"
                    if ($bg) ;
            }
            # things changed and anything left in class must be a real class thing
            $class =~ s/^\s+|\s+$//g ;
        } else {
            $class = "" ;
            $style .= "font-size:$base_em" . "em;" ;
        }
        # names are actually underscore spaced
        $icon =~ s/[-| ]/_/g ;
        $out = "<i class='material-icons $class'" . ( $style ? " style='$style'" : "" ) ;
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
# handle all replacers
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
# do some private stuff, shonky cos should be class variables
# TODO: make it so
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
            if ( $line eq "" ) {
                # blank line is the end of the yaml block
                $_yaml_counter = $count ;
            } else {
                $line =~ s/^\w+:.*// ;
            }
        }

        return $line ;
    }

    my $_ex_yaml_counter = 0 ;
    # -----------------------------------------------------------------------------
    # get any "key: value" item on a line, save it
    # remove from the line
    sub _extract_yaml
    {
        my $self = shift ;
        my ( $line, $count ) = @_ ;

        $count ||= 20 ;
        if ( ++$_ex_yaml_counter < $count ) {
            if ( !$line ) {
                # blank line is the end of the yaml block
                $_ex_yaml_counter = $count ;
            } else {
                my ( $k, $v ) = ( $line =~ /^(\w+):\s+(.*?)$/ ) ;
                if ($k) {
                    $line = "" ;    # do the remove
                    if ( !( $k eq 'date' && $v eq '%DATE%' ) ) {
                        $self->_add_replace( $k, $v ) ;
                    }
                }
            }
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
#  nodiv - do not wrap the output in a div

sub _include_file
{
    my $self         = shift ;
    my ($attributes) = @_ ;
    my $out          = "" ;

    my $params = _extract_args( $self->_do_replacements($attributes) ) ;
    $params->{file} = fix_filename( $params->{file} ) ;
    # if file is relative, add in basedir so we can process files in other directories
    if ( $params->{file} !~ /^\// ) {
        # TODO: fix with Path::Tiny
        $params->{file} = "$self->{basedir}/$params->{file}" ;
    }

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
        # make sure we have some space before we add stuff to the end
        # - just in case it ends with ~~~~ etc
        if ( !$params->{nodiv} ) {
            $out = "$div>$out\n</div>" ;
        }
    }
    return $out ;
}

# ----------------------------------------------------------------------------
# _check_conditionals
# test if ifand
# TODO: add ifnot

sub _check_conditionals
{
    my $self = shift ;
    my ( $block, $params ) = @_ ;
    my $matched = 0 ;
    my $passed  = 1 ;

    foreach my $k ( keys %$params ) {
        my $rep = $self->{replace}->{ uc($k) } ;
        if ( defined $rep && $rep eq $params->{$k} ) {
            $matched++ ;
        }
    }
    # and conditions requires all to match
    if ( !$matched || ( $block eq 'ifand' && $matched != scalar( keys %$params ) ) ) {
        $passed = 0 ;
    }

    return $passed ;
}

# ----------------------------------------------------------------------------
# _conditional_text
# include text if a condition or set of confitions is true

# parameters
# block - name of the calling block
# various key=value pairs

sub _conditional_text
{
    my $self = shift ;
    my ( $block, $attributes, $content ) = @_ ;
    my $params  = _extract_args( $self->_do_replacements($attributes) ) ;
    my $matched = 0 ;
    # inline content replaces
    if ( $params->{content} ) {
        $content = $params->{content} ;
        delete $params->{content} ;
    }

    foreach my $k ( keys %$params ) {
        my $rep = $self->{replace}->{ uc($k) } ;
        if ( defined $rep && $rep eq $params->{$k} ) {
            $matched++ ;
        }
    }
    # and conditions requires all to match
    if ( !$matched || ( $block eq 'ifand' && $matched != scalar( keys %$params ) ) ) {
        $content = "" ;
    }
    return $content ;
}

# ----------------------------------------------------------------------------
sub _replace_material
{
    my ( $type, $operator, $value ) = @_ ;
    my $quote = "" ;
    if ( $value =~ /^(["'"])/ ) {
        $quote = $1 ;
        $value =~ s/^["'"]// ;
    }

    return $type . $operator . $quote . to_hex_color($value) ;
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
# check on a smiley replace if we have it
# can do :emoji: and :emoji:[2x]

sub _replace_emojis
{
    my ( $smile, $size ) = @_ ;

    # do the font icon ones first then the emoji cheatsheet
    if ( $emoji{$smile} ) {
        $smile = $emoji{$smile} ;
    }
    # the emojio replacement may generate one from the cheatsheet
    if ( $emoji_cheatsheet{$smile} ) {
        $smile =~ s/://g ;
        # the URLs are quite specific and match the name, so we can contruct
        # the URL rather than keeping them in mapping
        # alternate suggestion http://emoji.fileformat.info/gemoji
        $smile =
            "<img class='emoji' alt='Emoji $smile' " . "src='$EMOJI_WEBSITE/$smile" . ".png' />" ;
    }

    # size is not working so ignoring it for now
    # if( $size) {
    #     $size =~ s/.*?(\d).*/$1/ ;
    #     $smile = "<span style='font-size:$size" . "em;'>$smile</span>" ;
    # }

    return $smile ;
}

# -----------------------------------------------------------------------------
sub _replace_unicodes
{
    my ($unicode) = @_ ;
    my $code      = $unicode_emoji{$unicode} ;
    my $size      = "16px" ;
    my $style     = "style='max-width:$size;max-height:$size;'" ;

    # class='emoji twitter'
    # "<img height='1em' width='1em' src='https://abs.twimg.com/emoji/v2/72x72/$code.png' />" ;
    my $img =
        "<img height='$size' width='$size' $style src='https://abs.twimg.com/emoji/v2/72x72/$code.png' />"
        ;
# "<img height='16px' width='16px' src='https://raw.githubusercontent.com/googlei18n/noto-emoji/f2a4f72bffe0212c72949a22698be235269bfab5/svg/emoji_u$code.svg' />" ;
# verbose("replacing $unicode - $code with $img") ;

    return $img ;
}


# -----------------------------------------------------------------------------
# give a @user a style
sub _addstyle
{
    my ( $element, $text, $class ) = @_ ;

    $text =~ s/^\s+|\s+$//gsm ;

    $text =~ s/(\@\w[-_\w\.]+)/<span class='atuser'>$1<\/span>/gsm ;

    return "<$element" . ( $class ? " class='$class'" : "" ) . ">$text</$element>" ;
}

sub _style_insdel
{
    my ( $ins, $del ) = @_ ;

    return _addstyle( 'del', $ins ) . _addstyle( 'ins', $del ) ;

}

# -----------------------------------------------------------------------------
#  critic markup  http://criticmarkup.com/spec.php
sub _critic_markup
{
    my ($text) = @_ ;

    # using \N to match any character that is NOT a linebreak
    # also cos CriticMarkup is not meant to span linebreaks
    # hilite {== ==}
    $text =~ s/\{(={2,2})(\N*?)\1\}/_addstyle('mark',$2)/egsm ;
    # addition / insert {++ ++}
    $text =~ s/\{(\+{2,2})(\N*?)\1\}/_addstyle('ins',$2)/egsm ;
    # substitution {~~ ~> ~~}
    $text =~ s/\{(~{2,2})(\N*?)~>(\N*?)\1\}/_style_insdel( $2, $3)/egsm ;
    # deletion {-- --}
    $text =~ s/\{(-{2,2})(\N*?)\1\}/_addstyle('del',$2)/egsm ;
    # special - grayed out
    $text =~ s/\{(:{2,2})(\N*?)\1\}/_addstyle('span',$2,'criticgrey')/egsm ;
    # special - questionbox
    $text =~ s/\{(\?{2,2})(\N*?)\1\}/_addstyle('span',$2,'criticquestion')/egsm ;

    # comment {>> <<} - text is removed
    $text =~ s/\{(>{2,2})(\N*?)<<\}//gsm ;

    # small
    $text =~ s/(\-{2,2})(\N*?)\1/_addstyle('small',$2)/egsm ;

    return $text ;
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
    add_javascript("<link rel=\"stylesheet\" type=\"text/css\" href=\"$FONT_AWESOME_URL\">") ;

    add_javascript("<link href=\"$GOOGLE_ICONS_URL\" rel=\"stylesheet\">") ;

    # add in our basic CSS
    add_css( $self->{commoncss} ) ;

    my $id ;
    if ( $self->{filename} ) {
        # base the hash on the filename as that will not change and
        # will overwrite previouse versions
        $id = md5_hex( $self->{filename} ) ;
    } else {
        # when building for test we may not have a filename, so do it the old way
        $id = md5_hex( encode_utf8($data) ) ;
    }

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

        # grab the yaml from the start of the document, first 20 lines
        $data =~ s/^(.*)?$/$self->_extract_yaml($1,20)/egm ;

        # parse the data find all fenced blocks we can handle
        $self->_parse_lines( $data, 1 ) ;

        # do a second pass to allow things that output fenced blocks etc
        # to have them processed too, lets start with admonitions, in case these have been added
        # help with debug as its a 2 pass process
        $self->_store_cache( $self->cache_dir() . "/$id.pass1.md", $self->{output}, 1 ) ;

        $data = $self->{output} ;
        # remove output as _parse_lines appends to it
        delete $self->{output} ;
        $self->_parse_lines( $data, 2 ) ;

        # store the markdown before parsing
        # $self->_store_cache( $self->cache_dir() . "/$id.md",
        #     encode_utf8( $self->{output} ), 1 ) ;
        $self->_store_cache( $self->cache_dir() . "/$id.md", $self->{output}, 1 ) ;

        $self->{output} //= "" ;
        # we have a special replace for '---' alone on a line which is used to
        # signifiy a page break

        $self->{output} =~ s|^-{3,}\s?$|<div style='page-break-before: always;'></div>\n\n|gsm ;

        # add in some smilies
        $self->{output} =~ s/(?<!\w)($smiles)(?!\w)/$smilies{$1}/g ;
        # and emojis
        $self->{output} =~ s/(?<!\w):(\w+):(\[[2345]x\])?(?!\w)/_replace_emojis( $1,$2)/egsi ;
        # and unicodes
        $self->{output} =~ s/(?<!\w)($unicodes)(?!\w)/_replace_unicodes( $1)/egsi ;

        # do the font replacements, awesome or material
        # :fa:icon,  :mi:icon,
        $self->{output}
            =~ s/(\\)?:(\w{2}):([\w|-]+):?(\[(\N*?)\])?/_icon_replace( $1, $2, $3, $4)/egsi ;

        $self->{output} =~ s/<c(\\)?:+(.*?)>(\N*?)<\/c>/_replace_colors( $1, $2, $3)/egsi ;

        $self->{output} = _critic_markup( $self->{output} ) ;

        # we have created something so we can cache it, if use_cache is off
        # then this will not happen lower down
        # now we convert the parsed output into HTML, use any highlighting that may be available
        my $pan = _pandoc_html( $self->{output},
            $self->{replace}->{HIGHLITE} || $self->{replace}->{HIGHLIGHT} ) ;

        # add the converted markdown into the template
        my $html = $self->template ;
        # lets do the includes in the templates to, gives us some flexibility
        $html =~ s/\{\{.include nodiv=1 file=(\N*?)\}\}/$self->_include_file($1)/esgm ;
        $html =~ s/^~~~~\{.include nodiv=1 file=(\N*?)\}.*?~~~~/$self->_include_file($1)/esgm ;

        my $program = get_program() ;
        $html =~ s/(<head.*?>)/$1\n<meta name="generator" content="$program" \/>/i ;

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
            $html =~ s|(<h([23456]).*?>)(.*?)(</h\2>)|_rewrite_hdrs( $1, $3, $4)|egsi ;
            $self->{replace}->{TOC} =
                "<div class='toc'>" . _build_toc($html) . "</div>" ;
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

        $html =~ s/(<img.*?src=['"])(.*?)(['"].*?>)/$self->_rewrite_imgsrc( $1, $2, $3, 1)/egs ;

        # write any css url images and store to the cache
        $html =~ s/(url\s*\(['"]?)(.*?)(['"]?\))/$self->_rewrite_imgsrc( $1, $2, $3, 0)/egs ;

        # replace any escaped \{ braces when needing to explain short code blocks in examples
        $html =~ s/\\\{/{/gsm ;

        # we should have everything here, so lets do any final replacements for material colors
        # specials for color and background eg: gray200, bluea100, green50
        $html
            =~ s/(color|background|background-color)(=|:)\s?(["']?\w+\d{2,3}\b)/_replace_material( $1, $2, $3)/egsm
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
    my ($format) = ( $filename =~ /\.(\w+)$/ ) ;    # get last thing after a '.'
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
                debug( "ERROR", "failed to create output file from cached file $cf" ) ;
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
