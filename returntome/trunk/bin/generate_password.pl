#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

#User input:
if (@ARGV != 1) {
    die "Usage: $0 (password length)\n";
}
my $length = $ARGV[0];

#Allowed characters:
my @chars = qw(a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9 / ! @ $ % ^ & * - _ );
my $nChars = scalar @chars;

#Build the password:
my $password;
for (my $i = 0; $i < $length; $i++) {
    my $random_number = int( rand($nChars) ); #generate random number
    $password .= $chars[$random_number]; #pick a random character
}

print "$password\n";

__END__

=head1 NAME

generatePassword.pl

=head1 USAGE

C<generatePassword.pl (password length)>

=head1 DESCRIPTION

Generate a random password of the specified length.

=head1 DEPENDENCIES

None.
