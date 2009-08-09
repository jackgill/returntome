#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::GetMail;
use Log::Log4perl;

Log::Log4perl::init('conf/log4perl_test.conf');

my @messages = &getMail('imap.gmail.com','return.to.me.receive@gmail.com','return2me');
die "No messages\n" unless (@messages);
#print $messages[0];
for (@messages) {
    print;
}
