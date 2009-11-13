package Mod::Ad;

use 5.010;

use strict;
use warnings;

use Exporter;

use LWP::Simple;

our @ISA = qw(Exporter);
our @EXPORT = qw(&getHTMLAd &getPlainAd);

sub getHTMLAd {

    my $ad = "Your html ad here.";
    eval {
	my $js = get("http://pcas.szabgab.com/ads/direct_link.js");
	if ($js =~ /write\("(.*)"\);/) {
	    $ad = $1;
	} 
    };
    return $ad;
}

sub getPlainAd {
    return "Your plain text ad here.";
}
1;
