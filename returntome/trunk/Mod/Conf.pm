package Mod::Conf;

use 5.010;

use strict;
use warnings;

use Exporter;

use Mod::Crypt;

our @ISA = qw(Exporter);
our @EXPORT = qw(getConf getCipherConf);

sub getConf {
    my $file = shift;
    open(CONFIG,"<$file") or die "Couldn't open $file: $!\n";
    my @file = <CONFIG>;
    return &readConf(\@file);
}

sub getCipherConf {
    my $file = shift;
    my $key = &getKey;
    open(CONFIG,"<$file") or die "Couldn't open $file: $!\n";
    my @slurp = <CONFIG>;
    my $cipher_text = join("", @slurp);
    my $plain_text = &decrypt($key, $cipher_text);
    return {} unless($plain_text =~ /[\w\s]{10,}/);
    my @file = split("\n",$plain_text);
    return &readConf(\@file);    
}

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


1;
