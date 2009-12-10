#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 4;

use_ok('Mod::Crypt') or exit;


open(STDIN,'echo foo |') or BAIL_OUT("Couldn't open STDIN: $!");
#my $key = getCheckedKey('conf/key_digest.conf');
my $key = getKey();
close STDIN;

my $plain_text = "This is some plain text.";
my $encrypted = encrypt($key, $plain_text);
my $decrypted = decrypt($key, $encrypted);

is($key, 'foo', 'Key');
like($encrypted, qr/Salted_.*/, 'Encrypted');
is($decrypted, $plain_text, 'Decrypted');


