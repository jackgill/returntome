#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

 use MIME::Decoder;

my $decoder = new MIME::Decoder 'quoted-printable' or die "unsupported";
$decoder->decode(\*STDIN, \*STDOUT);
