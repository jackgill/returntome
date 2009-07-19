#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Date::Manip;
use Time::Piece;

use R2M::SendMail;
use R2M::GetMail;
use R2M::ParseMail;
use R2M::TieHandle;

Log::Log4perl::init('log4perl_test.conf');
tie(*STDERR, 'R2M::TieHandle');

my @messages;
my $nMessages = 2;
for (my $i = 0; $i < $nMessages; $i++) {
    my $now = localtime;
    my $wait =  int(rand(2 * 60));
    my $return_time = $now + $wait;
    my $return_when =$return_time->datetime;
    push @messages, {uid => 'dummy', from => 'return.to.me.test@gmail.com',subject => "subject $i", body => "R2M: $return_when \r\nbody $i"};
    print "Return requested at $return_when\n";
}
&sendMessages('return.to.me.receive@gmail.com','return2me',@messages);
print "Waiting...\n";
sleep 2 * 60;
my @raw_messages = &getMail('return.to.me.receive@gmail.com','return2me');
die "No messages\n" unless (@raw_messages);
for my $raw_message (@raw_messages) {
    my $date = getDate($raw_messages[0]);
    print "Message received at $date\n";
}
