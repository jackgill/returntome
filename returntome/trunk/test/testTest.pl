#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use Mod::Test;

testCreateMessages();

sub testCreateMessages {
    #Create messages:
    my @messages = createMessages(2,2,'return.to.me.receive@gmail.com');

    #Print messages:
    for my $message (@messages) {
	print Dumper($message);
        print "\n", '-' x 78, "\n";
    }
}
