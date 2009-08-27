#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Mod::Test;
use Mod::UID;
use Data::Dumper::Simple;

my @uids;
for (my $i = 0; $i < 2; $i++) {
    push @uids, &getUID;
}
my @messages = &createMessages(@uids);
my @mail = &createMail(@messages);
for (@messages) {
    my %message = %$_;
    print Dumper(%message);
}
for (@mail) {
    print $_;
}
