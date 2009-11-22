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

=head1 NAME

Mod::Ad

=head1 SYNOPSIS

    my $plain_ad = getPlainAd;
    my $html_ad = getHTMLAd;

=head1 DESCRIPTION

This module provides ads.

=head1 SUBROUTINES

=over

=item *

getHTMLAd

Get an HTML ad. Currently this is subroutine contacts the Perl Community Ad server for an ad.

I<Arguments:> None.

I<Returns:>

=over

=item *

An HTML ad.

=back

=item *

getPlainAd

Get a plain text ad. Currently this is a dummy subroutine.

I<Arguments:> None.

I<Returns:>

=over

=item *

A plain text ad.

=back

=back

=head1 DEPENDENCIES

=over

=item *

LWP::Simple

=back
