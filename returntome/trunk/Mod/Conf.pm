package Mod::Conf;

use 5.010;

use strict;
use warnings;

use Exporter;

use Mod::Crypt;

our @ISA = qw(Exporter);
our @EXPORT = qw(getConf);

sub getConf {
    my ($file, $key) = @_;

    my %conf; #stores conf variables
 
    #Open the conf file:
    open(CONFIG,"<$file") or die "Couldn't open $file: $!\n";
    my @slurp = <CONFIG>;
    my $cipher_text = join("", @slurp);

    #Decrypt the conf file:
    my $plain_text = &decrypt($key, $cipher_text);

    #Determine if decryption was successful:
    die "Error: failed to decrypt conf file.\n" unless($plain_text =~ /[\w\s]{10,}/);

    #Read the conf file:
    my @file = split("\n",$plain_text);
    for (@file) {
	chomp;                  # no newline
	s/#.*//;                # no comments
	s/^\s+//;               # no leading white
	s/\s+$//;               # no trailing white
	next unless length;     # anything left?
	my ($var, $value) = split(/\s*=\s*/, $_, 2);
	$conf{$var} = $value;
    }
    
    #Check that conf variables are defined:
    my @conf_vars = qw(
imap_server imap_user imap_pass 
smtp_server smtp_user smtp_pass 
db_server db_user db_pass db_key
interval
admin_address
);
    for (@conf_vars) {
	die "Configuration error: $file does not define $_\n" unless (defined $conf{$_});
    }

    return \%conf;
}


1;

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

=item getConf(file, key)

    Arguments: The path to the configuration file, the encryption key.
    Returns: A reference to hash containing the key,value pairs from the file.

=cut

=back

=cut
