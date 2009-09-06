#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;
use Mod::Test;

#&testCreateMessages;
&testCreateMail;

sub testCreateMessages {
    my @messages = &createMessages(2,2);
    for (@messages) {
	my %message = %{$_};
	print Dumper(%message);
    }
}

sub testCreateMail {
   my @mail = &createMail(1,2);
    for (@mail) {
	print;
    }
}
