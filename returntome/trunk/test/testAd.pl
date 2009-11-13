#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::Ad;

my $html_ad = &getHTMLAd;
print "$html_ad\n";
my $plain_ad = &getPlainAd;
print "$plain_ad\n";
