#!/usr/bin/perl

use strict;
use warnings;

#use Crypt::Rijndael;
use Crypt::CBC;


# keysize() is 32, but 24 and 16 are also possible
# blocksize() is 16

#my $iv = Crypt::CBC->random_bytes(16);
my $key = Crypt::CBC->random_bytes(32);
#my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC() );
my  $cipher = Crypt::CBC->new( -key    => $key,
			       -cipher => 'Rijndael'
			       );
#$cipher->set_iv($iv);
my $start = "Hello Cryptography.";
my $crypted = $cipher->encrypt($start);
my $end = $cipher->decrypt($crypted);
print "Key: $key\n";
#print "iv:  $iv\n";
print "Start message: $start\n";
print "Crypt message: $crypted\n";
print "End   message: $end\n";
