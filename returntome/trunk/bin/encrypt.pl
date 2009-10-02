#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::Crypt;


#User input:
die "Usage: $0 file\n" unless (@ARGV == 1);
my $file = $ARGV[0];
my $key = &getKey;

#Encrypt the file:
open(my $in, "<$file") or die "Couldn't open $file: $!\n";
open(my $out, ">$file.crypt") or die "Couldn't open $file.crypt: $!\n";

my @slurp = <$in>;
my $plain_text = join("", @slurp);
my $encrypted = &encrypt($key, $plain_text);
print $out $encrypted;

close $in;
close $out;
