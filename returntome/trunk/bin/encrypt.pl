#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::Crypt;

#User input:
if(scalar @ARGV != 2) {
    die "Usage: $0 (file to be decrypted) (file containing key digest)\n"
}
my $file = $ARGV[0];
my $digest = $ARGV[1];
my $key = &getCheckedKey($digest);

#Encrypt the file:
open(my $in , '<', $file) or die "Couldn't open $file: $!\n";
open(my $out, '>', $file . 'crypt') or die "Couldn't open $file.crypt: $!\n";

my @slurp = <$in>;
my $plain_text = join("", @slurp);
my $encrypted = encrypt($key, $plain_text);
print $out $encrypted;

close $in;
close $out;

__END__

=head1 NAME

encrypt.pl

=head1 USAGE

C<bin/encrypt.pl (file to be encrypted) (file containing key digest)>

=head1 DESCRIPTION

The script will prompt for a encryption key, then encrypt the file specified by the first command line argument. It checks the given key against digest given in the file specified by the second command line argument.

=head1 DEPENDENCIES

=over

=item *

Mod::Crypt

=back
