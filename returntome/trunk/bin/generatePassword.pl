#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

die "Usage: $0 (password length)\n" unless (@ARGV == 1);
my $length = $ARGV[0];
my @chars = qw(a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9 / ! @ $ % ^ & * - _ );
my $password;
my $nChars = @chars;
for (my $i = 0; $i < $length; $i++) {
    $password .= $chars[int(rand($nChars))];
}

print "$password\n";

