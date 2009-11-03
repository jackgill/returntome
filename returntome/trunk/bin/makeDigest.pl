#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Term::ReadKey;
use Digest::SHA qw(sha1_base64);

die "Usage: $0 filename\n" unless(@ARGV == 1);
my $file = $ARGV[0];
print "Enter encryption key:\n";
ReadMode('noecho');
my $key = ReadLine(0);
chomp $key;
ReadMode('normal');
my $digest = &sha1_base64($key);
open(my $out,">$file") or die "Couldn't open $file: $!\n";
print $out $digest;
close $out;
