#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use R2M::Crypt;

if (scalar @ARGV != 1) {
    die "Usage: $0 file\n";
}
my $conf_file = $ARGV[0];
my $key = get_checked_key('conf/key_digest.conf');

#Read in encrypted conf file
my $conf_crypt = read_file($conf_file);

#Decrypt conf file
my $conf_plain = decrypt($key, $conf_crypt);

#Write decrypted conf file
my $plain_file = "$conf_file.decrypt";
write_file($plain_file, $conf_plain);

#Launch the text editor
system "pico $plain_file";

#Read in edited conf file
my $conf_edited = read_file($plain_file);
unlink($plain_file);

#Encrypt edited conf file
my $conf_re_crypt = encrypt($key, $conf_edited);

#Write out edited conf file
write_file($conf_file, $conf_re_crypt);

sub read_file {
    my $file_name = shift;

    open(my $in, '<', $file_name) or die "Couldn't open $file_name: $!\n";

    my $file = do {
        local $/;
        <$in>;
    };

    close $in;

    return $file;
}

sub write_file {
    my $file_name = shift;
    my $file = shift;
    open(my $out, '>', $file_name) or die "Couldn't open $file_name: $!\n";
    print $out $file;
    close $out;
}

=head1 NAME

edit_conf.pl -- Edit configuration files.

=head1 USAGE

C<edit_conf.pl conf/talaria.conf>

=head1 DESCRIPTION

Currently this program uses pico to edit a decrypted version of the conf file on disk. This a security risk, but doing everything in-memory is hard.

=head1 DEPENDENCIES

=over

=item *

R2M::Crypt

=back
