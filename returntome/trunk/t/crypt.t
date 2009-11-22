#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 4;

BEGIN {
    use_ok('Mod::Crypt');
}

open(STDIN,'<t/password.txt') or BAIL_OUT("Couldn't open STDIN: $!");
my $key = &getCheckedKey('conf/key_digest.conf');
close STDIN;

my $plain_text = "This is some plain text.";
my $encrypted = &encrypt($key, $plain_text);
my $decrypted = &decrypt($key, $encrypted);

is($key, 'foo', 'Key');
like($encrypted, qr/Salted_.*/, 'Encrypted');
is($decrypted, 'This is some plain text.', 'Decrypted');


