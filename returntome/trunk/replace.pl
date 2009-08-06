#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use File::Find;

#Assemble the list of perl files:
my @files;
find(\&wanted,'.');
sub wanted {
    if (/\.p(l|m)$/) {
	push @files, $File::Find::name;
    }
}

for my $file (@files) {
    print "Modifying $file\n";
    open(IN,"<$file") or die "Couldn't open $file for input: $!\n";
    open(OUT,">$file.tmp") or die "Couldn't open $file.tmp for output: $!\n";
    while (<IN>) {
	s/R2M/Mod/;
	print OUT;
    }
    close IN;
    close OUT;
    copy("$file.tmp",$file);
    unlink "$file.tmp";
}
