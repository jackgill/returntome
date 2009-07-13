#!/usr/bin/perl

use strict;
use warnings;

use File::Find;

my @names;
for (@INC) {
#    print "$_\n";
#    system `find * | grep -e 'Net'`;
    my @modules = glob "$_/*.pm";
    for (@modules) {
#	print "\t$_\n";
	push @names, $_;
#	if (-d) {
#	    if (/Net/){
	    #print "\t$_\n";
#	    }
#	}
    }
}
for (sort @names) {
    print "\t$_\n";
}
#find(\&wanted,@INC);
#sub wanted {
#    if (/SSLeay.pm/) {
#	print $File::Find::name,"\n";
#    }
#}
