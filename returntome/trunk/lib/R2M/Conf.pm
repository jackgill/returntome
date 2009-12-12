package R2M::Conf;

use 5.010;
use strict;
use warnings;

use Exporter;
use Config::Tiny;
use R2M::Crypt;

our @ISA = qw(Exporter);
our @EXPORT = qw(read_conf);

sub read_conf {
    my ($conf_file, $key) = @_;

    #Read conf file
    open (my $in, '<', $conf_file) or die "Can't open $conf_file: $!\n";
    my $conf_file_str = do {
        local $/;
        <$in>;
    };
    close $in;

    #Decrypt conf file
    $conf_file_str = decrypt($key,$conf_file_str);

    #Process conf file
    my $conf = Config::Tiny->read_string( $conf_file_str );

    if (!$conf) {
        die "Error reading conf file $conf_file: $Config::Tiny::errstr\n";
    }

    return $conf;
}

1;

=head1 NAME

R2M::Conf -- read encrypted configuration files.

=head1 SYNOPSIS

C<my $conf = read_conf($conf_file, $key);>

=head1 DESCRIPTION

Uses Config::Tiny to read ini-style config files.

=head1 SUBROUTINES

=over

=item B<read_conf>

I<Arguments:>

=over

=item *

Name of configuration file

=item *

Decryption key

=back

I<Returns:>

=over

=item *

Config::Tiny object (hashref)

=back

=back

=head1 DEPENDENCIES

=over

=item *

R2M::Crypt

=item *

Config::Tiny

=back
