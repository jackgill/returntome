#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

my $pid = fork;
if ($pid > 0) {
    local $SIG{CHLD} = \&catchSig;
    print "Entered parent process\n";
    sleep 4;
} elsif ($pid == 0) {
    print "Entered child process\n";
    sleep 2;
} else {
    die "Can't fork: $!\n";
}

sub catchSig {
    print "Caught signal\n";
}


