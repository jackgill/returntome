#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::ParseInstructions;

my $instructions = "tomorrow";
my $result = &parseInstructions($instructions);
print "Instructions: $instructions\n";
print "Result: $result \n";

