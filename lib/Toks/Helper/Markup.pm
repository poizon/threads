package Toks::Helper::Markup;

use strict;
use warnings;

use parent 'Tu::Helper';

use Encode ();
use Digest::MD5 qw(md5_hex);

sub render {
    my $self = shift;
    my ($text) = @_;

    my %parts;

    my $save = sub {
        my ($capture, $tag) = @_;
        my $key = md5_hex(Encode::encode('UTf-8', $capture));
        $parts{$key} = $tag;
        "--#$key#--"
    };

    $text =~ s{<(https?://[^<"&\s]+)>}{$save->($1, qq{<a href="$1">$1</a>})}eg;

    $text =~ s{&}{&amp;}g;
    $text =~ s{>}{&gt;}g;
    $text =~ s{<}{&lt;}g;
    $text =~ s{"}{&quot;}g;

    $text =~ s{^```([a-z]+)?\s+(.*?)\s*^```}
        {my $lang = $1 || 'perl'; $save->("$lang:$2", qq{<pre class="$lang"><code>$2</code></pre>})}emsg;
    $text =~ s{`(.*?)`}{$save->($1, "<code>$1</code>")}eg;

    $text =~ s{_(.*?)_}{$save->($1, "<em>$1</em>")}eg;
    $text =~ s{\*\*(.*?)\*\*}{$save->($1, "<strong>$1</strong>")}eg;

    $text =~ s{\((.*?)\)\[(.*?)\]}{$save->("$1:$2", qq{<a href="$2">$1</a>})}eg;

    $text =~ s#(?:\r?\n){2,}#</p><p>#g;

    for my $key (keys %parts) {
        $text =~ s{--#$key#--}{$parts{$key}}g;
    }

    return '<p>' . $text . '</p>';
}

1;
