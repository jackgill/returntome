#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use lib '/home/jack/returntome/sandbox/Modules';
use R2M::GetMail;

my $id = 1;
my @messages = &getMail;
die "No messages\n" unless (@messages);
print $messages[0];

