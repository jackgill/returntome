#!/usr/bin/perl

use strict;
use warnings;

use File::Find;

my ($wanted, $files) = &getWanted;
find ($wanted, @INC);
my @names = &$files;
for (sort @names) {
    print "$_\n";
}
sub getWanted {
    my @names;
    my $wanted = sub {
	if (/.+\.pm/) {
	    push @names, $_;
	}
    };
    my $files = sub {
	return @names;
    };
    return ($wanted,$files);
}
