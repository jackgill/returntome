package Mod::Conf;

use 5.010;

use strict;
use warnings;

use Exporter;

use Mod::Crypt;

our @ISA = qw(Exporter);
our @EXPORT = qw(getConf getCipherConf);

=head1 NAME

    Mod::Conf

=cut

=head1 SYNOPSIS

    my %conf = %{ &getConf("/some/conf.txt") };
    my %conf = %{ &getCipherConf("/some/conf.txt","password") };

=cut

=head1 DESCRIPTION

    A module for reading configuration files.

=cut

=head1 FUNCTIONS

=over 

=item getConf(file)

    Get the unencrypted configuration file.
    Arguments: The path to the unencrypted configuration file.
    Returns: A reference to hash containing the key,value pairs from the file.

=cut

sub getConf {
    my $file = shift;
    open(CONFIG,"<$file") or die "Couldn't open $file: $!\n";
    my @file = <CONFIG>;
    return &readConf(\@file);
}

=item getCipherConf(file, key)

    Get the encrypted configuration file.
    Arguments: The path to the encrypted configuration file.
               The encryption key.
    Returns: A reference to hash containing the key,value pairs from the file.

=cut

sub getCipherConf {
    my $file = shift;
    my $key = shift;
    open(CONFIG,"<$file") or die "Couldn't open $file: $!\n";
    my @slurp = <CONFIG>;
    my $cipher_text = join("", @slurp);
    my $plain_text = &decrypt($key, $cipher_text);
    return {} unless($plain_text =~ /[\w\s]{10,}/);
    my @file = split("\n",$plain_text);
    return &readConf(\@file);    
}

=item readConf(lines)

    Arguments: A reference to an array of lines from a file of the form key=value.
    Returns: A reference to hash containing the key,value pairs from the file.

=cut

sub readConf {
    my @file = @{ shift @_ };
    my %conf; #stores config variables
    for (@file) {
	chomp;                  # no newline
	s/#.*//;                # no comments
	s/^\s+//;               # no leading white
	s/\s+$//;               # no trailing white
	next unless length;     # anything left?
	my ($var, $value) = split(/\s*=\s*/, $_, 2);
	$conf{$var} = $value;
    }
    return \%conf;
}

=back

=cut

1;
