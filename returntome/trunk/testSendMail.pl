#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use R2M::SendMail;
use Log::Log4perl;

Log::Log4perl::init('log4perl_test.conf');
my @messages;
for (my $i = 0; $i < 1; $i++) {
    push @messages, {address => 'return.to.me.receive@gmail.com',subject => "subject $i", body => "body $i"};
}
&sendMessages('return.to.me.test@gmail.com','return2me',@messages);
