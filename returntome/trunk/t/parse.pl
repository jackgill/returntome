#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 1;
use Test::MockModule;

#Mock R2M::Ad
my $R2M_Ad = Test::MockModule->new('R2M::Ad');
$R2M_Ad->mock(
    getPlainAd => sub {
        return 'This is a plain text ad.';
    }
);
$R2M_Ad->mock(
    getHTMLAd => sub{
        return 'This is a html ad.';
    }
);

use_ok('R2M::Parse');

if (scalar @ARGV != 1) {
    die "Usage: $0 (file name)\n";
}
my $file_name = $ARGV[0];
open(my $in, '<', "$file_name") or die "Couldn't open $file_name: $!\n";
my $raw_mail = do {
    local $/;
    <$in>;
};
close $in;
my $message = parse_mail($raw_mail,'return.to.me.test@gmail.com','uid');
$file_name =~ s/\.raw$/\.parsed/;
open (my $out, '>', $file_name) or die "Couldn't open $file_name: $!\n";
print $out $message->{mail};
close $out;

=head1 NAME

=head1 USAGE

=head1 DESCRIPTION

=head1 DEPENDENCIES
