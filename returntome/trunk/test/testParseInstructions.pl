#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::ParseMail;

#Initialize logger:
Log::Log4perl::init('conf/log4perl_test.conf');

#The instructions to test:
my @instructions = (
    "Aug 16 2009",
    "tomorrow",
    "today 3pm",
    "8-19-09",
    "8/19/09",
    "today 8:00",
    "today 5",
    "next week",
    );

#Print headers:
my $format = "%-20s %-20s\n";
printf $format,"Instructions","Result";
printf $format, "-" x 19,"-" x 19;

#Test instructions:
for (@instructions) {
    my $result = &parseInstructions($_);
    $result = "error" unless $result;
    printf $format,$_,$result;
}
