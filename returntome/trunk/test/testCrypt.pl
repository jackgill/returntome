#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::Crypt;

main();

sub main {
    my $key = &getCheckedKey('conf/key_digest');
    my $plain_text = "This is some plain text.";
    my $encrypted = &encrypt($key, $plain_text);
    my $decrypted = &decrypt($key, $encrypted);
    print "key: $key\n";
    print "plain text: $plain_text\n";
    print "encrypted : $encrypted\n";
    print "decrypted : $decrypted\n";
}

