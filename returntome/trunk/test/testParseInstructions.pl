#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::ParseMail;

#TODO: re-write using Test::More

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
for my $instruction (@instructions) {
    my $result = &parseInstructions( $instruction );
    $result = "error" unless $result;
    printf $format, $instruction, fromEpoch($result);
}
