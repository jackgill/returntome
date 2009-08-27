#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::ParseMail;

Log::Log4perl::init('conf/log4perl_test.conf');

my @instructions = ("Aug 16 2009","tomorrow","today 3pm","8-19-09","8/19/09","today 8:00" ,"today 5","next week");
printf "%-20s","Instructions";
printf "%-20s\n","Result";
print "-" x 19," ","-"x19,"\n";
for (@instructions) {
    printf "%-20s",$_;
    my $epoch = &parseInstructions($_);
    if ($epoch) {
	my $result = &fromEpoch($epoch);    
	printf "%-20s",$result;
    } else {
	print "error";
    }
    print "\n";
}
