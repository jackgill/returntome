#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

#TODO: redo using Pod::Simple::HTMLBatch

open(my $index,">doc/index.html") || die "Couldn't open doc/index.html: $!\n";
print $index "<h2>Modules</h2><br><ul>";
my @modules = qw(Conf);
for (@modules) {
    system "pod2html --infile=Mod/$_.pm --outfile=doc/$_.html";
    print $index "<li><h4><a href='$_.html'>$_.pm</a></h4></li>";
}
print $index "</ul>";
