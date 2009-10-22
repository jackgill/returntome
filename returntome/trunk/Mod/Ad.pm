package Mod::Ad;

use 5.010;

use strict;
use warnings;

use Exporter;

use LWP::Simple;

our @ISA = qw(Exporter);
our @EXPORT = qw(&getAd);

sub getAd {

    my $url = "http://pcas.szabgab.com/ads/direct_link.js";
    my $content = get($url);
    if ($content =~ /write\("(.*)"\);/) {
	return $1;
    }
    
}

1;
