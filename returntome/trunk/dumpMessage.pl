#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use R2M::GetMail;

my @messages = &getMail('return.to.me.test@gmail.com','return2me');
die "No messages\n" unless (@messages);
print $messages[0];

