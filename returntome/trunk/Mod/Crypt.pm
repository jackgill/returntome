package Mod::Crypt;

use 5.010;

use strict;
use warnings;

use Exporter;
use Crypt::CBC;
use Term::ReadKey;
use Carp;
use Digest::SHA qw(sha1_base64);

our @ISA = qw(Exporter);
our @EXPORT = qw(encrypt decrypt getCheckedKey getKey);

sub encrypt {
    my ($key, $plain_text) = @_;

    my $cipher = Crypt::CBC->new( -key => $key, -cipher => 'Rijndael');
    my $encrypted = $cipher->encrypt($plain_text);
    return $encrypted;
}

sub decrypt {
    my ($key, $encrypted) = @_;

    my $cipher = Crypt::CBC->new( -key => $key, -cipher => 'Rijndael');
    my $plain_text = $cipher->decrypt($encrypted);
    return $plain_text;
}

sub getCheckedKey {
    my $file = shift;

    #Read in digest from file:
    open(my $in, '<', $file) or croak "Couldn't open $file: $!\n";
    my @lines = <$in>;
    close $in;
    my $file_digest = $lines[0];

    #Get key from user
    my $key = getKey();

    #Calculate key digest
    my $key_digest = sha1_base64($key);

    #Compare key digest to digest from file:
    if ($file_digest eq $key_digest) {
	return $key;
    } else {
	croak "Invalid encryption key.\n";
    }
}

sub getKey {
    #Display prompt
    print "Enter encryption key:\n";

    #Set terminal to not echo input
    ReadMode('noecho');

    #Read input
    my $key = ReadLine(0);
    chomp $key;

    #Set terminal to echo input
    ReadMode('normal');

    return $key;
}

1;

=head1 NAME

Mod::Crypt

=head1 SYNOPSIS

=head1 DESCRIPTION

This module provides encryption and decryption using AES.

=head1 SUBROUTINES

=over

=item *

B<encrypt>

I<Arguments:>

=over

=item *

key

=item *

plain text

=back

I<Returns:>

=over

=item *

encrypted text

=back

=item *

B<decrypt>

I<Arguments:>

=over

=item *

key

=item *

encrypted text

=back

I<Returns:>

=over

=item *

plain text

=back

=item *

B<getCheckedKey>

Get an encryption key from the user, and compare its SHA1 digest to a digest given in a file.

I<Arguments:>

=over

=item *

File containing key digest. Only the first line of the file is read.

=back

I<Returns:>

=over

=item *

Encryption key.

=back

=item *

B<getKey>

Get an encryption key from the user.

I<Arguments:> None.

I<Returns:>

=over

=item *

Encryption key.

=back

=back

=head1 DEPENDENCIES

=over

=item *

Crypt::CBC

=item *

Term::ReadKey

=item *

Digest::SHA

=back
