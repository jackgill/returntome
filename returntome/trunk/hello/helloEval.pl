#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

eval {&risk};
warn $@ if $@;
print "but I am still alive...\n";
sub risk {
    die "sub is dying\n";
}

