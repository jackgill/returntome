#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Digest::SHA qw(sha1_base64);

use R2M::Crypt;

#User input:
if (@ARGV != 1) {
    die "Usage: $0 filename\n" ;
}
my $file = $ARGV[0];

#Prompt for encryption key
my $key = get_key();

#Calculate digest:
my $digest = &sha1_base64($key);

#Write digest to file:
open(my $out, '>', $file) or die "Couldn't open $file: $!\n";
print $out $digest;
close $out;

__END__

=head1 NAME

makeDigest.pl

=head1 USAGE

C<makeDigest.pl (file to write digest to)>

=head1 DESCRIPTION

Calculate the SHA1 digest of a given encryption key.

=head1 DEPENDENCIES

=over

=item *

R2M::Crypt

=back
