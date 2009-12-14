#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 4;

use_ok('R2M::Crypt') or exit;

#Test get_key()
my $exp_key = 'foo';
open(STDIN, "echo $exp_key |") or die "Couldn't open STDIN: $!\n";
open(STDOUT, '>', '/dev/null') or die "Couldn't open STDOUT: $!\n";
my $got_key = get_key();
close STDIN;
close STDOUT;
is($got_key, $exp_key, 'get_key()');

#my $key = getCheckedKey('conf/key_digest.conf');

my $plain_text = 'This is some plain text.';

#Test encrypt()
my $encrypted = encrypt($exp_key, $plain_text);
like($encrypted, qr/Salted_.*/, 'encrypt()');

#Test decrypt()
my $decrypted = decrypt($exp_key, $encrypted);
is($decrypted, $plain_text, 'decrypt()');


