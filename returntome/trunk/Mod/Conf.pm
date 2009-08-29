package Mod::Conf;

use 5.010;

use strict;
use warnings;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(getConf);

sub getConf {
    my $file = shift;
    #read config file:
    my %conf; #stores config variables
    open(CONFIG,"<$file") or die "Couldn't open $file: $!\n";
    while (<CONFIG>) {
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
