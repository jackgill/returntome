package R2M::Crypt;

use strict;
use warnings;

use Exporter;
use Crypt::CBC;
use Term::ReadKey;
use Digest::SHA qw(sha1_base64);

our @ISA = qw(Exporter);
our @EXPORT = qw(encrypt decrypt get_checked_key get_key);

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

sub get_checked_key {
    my $file = shift;

    #Read in digest from file:
    open(my $in, '<', $file) or die "Couldn't open $file: $!\n";
    my @lines = <$in>;
    close $in;
    my $file_digest = $lines[0];

    #Get key from user
    my $key = get_key();

    #Calculate key digest
    my $key_digest = sha1_base64($key);

    #Compare key digest to digest from file:
    if ($file_digest eq $key_digest) {
	return $key;
    } else {
	die "Invalid encryption key.\n";
    }
}

sub get_key {
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

R2M::Crypt -- Encryption and decryption routines.

=head1 SYNOPSIS

C<my $key = get_checked_key($key_digest_file);>
C<my $crypt_test = encrypt($key, $plain_text);>
C<my $plain_test = encrypt($key, $crypt_text);>

=head1 DESCRIPTION

This module provides encryption and decryption using AES. It also provides subroutines to prompt the user for an encryption key, and compare it to a digest in a file.

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

B<get_checked_key>

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

B<get_key>

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
