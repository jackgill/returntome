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
our @EXPORT = qw(encrypt decrypt getCheckedKey getKey encryptMessages decryptMessages);

sub encrypt {
    my $key = shift;
    my $plain_text = shift;

    my $cipher = Crypt::CBC->new( -key => $key, -cipher => 'Rijndael');
    my $encrypted = $cipher->encrypt($plain_text);
    return $encrypted;
}

sub decrypt {
    my $key = shift;
    my $encrypted = shift;
    croak "Must supply encryption key and encrypted text" unless ($key && $encrypted);
    my $cipher = Crypt::CBC->new( -key => $key, -cipher => 'Rijndael');
    my $plain_text = $cipher->decrypt($encrypted);
    return $plain_text;
}

sub getCheckedKey {
    my $file = shift;
    open(my $in,"<$file") or croak "Couldn't open $file: $!\n";
    my @lines = <$in>;
    my $file_digest = $lines[0];
    my $key = &getKey;
    my $key_digest = &sha1_base64($key);
    if ($file_digest eq $key_digest) {
	return $key;
    } else {
	croak "Invalid encryption key.\n";
    }
}

sub getKey {
    print "Enter encryption key:\n";
    ReadMode('noecho');
    my $key = ReadLine(0);
    chomp $key;
    ReadMode('normal');
    return $key;
}

sub encryptMessages {
    my $key = shift;
    my @messages = @_;
    for (@messages) {
	my %message = %$_;
	$message{mail} = &encrypt($key, $message{mail});
	$_ = \%message;
    }
    return @messages;
}


sub decryptMessages {
    my $key = shift;
    my @messages = @_;
    for (@messages) {
	my %message = %$_;
	$message{mail} = &decrypt($key, $message{mail});
	$_ = \%message;
    }
    return @messages;
}
1;
