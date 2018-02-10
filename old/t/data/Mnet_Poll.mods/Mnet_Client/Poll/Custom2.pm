# use config option --poll-mod-dir ./Mnet_Client
package Mnet_Client::Poll::Custom2;
use Mnet;
BEGIN {
    our $cfg = &Mnet::config({
        'custom2-arg'     => 1,
        'custom2-default' => 1,
    });
}
sub poll_mod {
    my $cfg = shift or die "poll_mod cfg arg missing";
    my $pn = shift or die "poll_mod pn arg missing";
    my $po = shift;
    $po = {} if ref $po ne "HASH";
    &dbg("poll_mod custom2 custom2-default = $cfg->{'custom2-default'}");
    &dbg("poll_mod custom2 custom2-arg = $cfg->{'custom2-arg'}");
    &dbg("poll_mod custom2 function finished");
}
1;

