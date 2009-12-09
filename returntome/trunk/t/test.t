#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 1;

BEGIN {
    use_ok('Mod::Test');
}

my @messages = createMessages(1, 2, 'return.to.me.receive@gmail.com');
my $message = $messages[0];
#print $message->{mail};
