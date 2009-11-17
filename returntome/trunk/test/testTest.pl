#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use Mod::Test;

&testCreateMessages;

sub testCreateMessages {
    my @messages = &createMessages(2,2);
    for my $message (@messages) {
	print Dumper($message);
    }
}
