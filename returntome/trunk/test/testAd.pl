#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::Ad;

my $html_ad = &getHTMLAd;
print "HTML Ad:\n$html_ad\n";

print "\n";

my $plain_ad = &getPlainAd;
print "Plain Ad:\n$plain_ad\n";
