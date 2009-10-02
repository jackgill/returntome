#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::Crypt;

#User input:
die "Usage: $0 file\n" unless (@ARGV == 1);
my $file = $ARGV[0];
my $key = &getKey;

#Decrypt the file:
open(my $in, "<$file") or die "Couldn't open $file: $!\n";
open(my $out, ">$file.decrypt") or die "Couldn't open $file.decrypt: $!\n";

my @slurp = <$in>;
my $cipher_text = join("", @slurp);
my $plain_text = &decrypt($key, $cipher_text);
print $out $plain_text;

close $in;
close $out;


