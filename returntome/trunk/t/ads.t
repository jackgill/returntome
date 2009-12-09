#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 3;

use_ok('Mod::Ad') or exit;

#Get ads:
my $html_ad = &getHTMLAd;
my $plain_ad = &getPlainAd;

#Display ads:
#print "HTML Ad:\n$html_ad\n";
#print "\n";
#print "Plain Ad:\n$plain_ad\n\n";

#Test ads:
like($html_ad, qr{<a href=.*?>.*?</a>}, 'HTML Ad');
is($plain_ad, 'Your plain text ad here.', 'Plain text ad');
