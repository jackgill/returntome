#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use lib '/home/jack/returntome/trunk/Modules/';
use R2M::SendMail;
#use R2M::GetMail;

use Data::Dumper::Simple;

my @messages;
for (my $i = 0; $i < 2; $i++) {
    push @messages, {from => 'return.to.me.receive@gmail.com',subject => "subject $i", body => "body $i"};
}
&sendMessages(@messages);
