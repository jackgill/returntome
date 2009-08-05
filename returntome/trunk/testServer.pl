#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

#use Time::Piece;
use DateTime;

use R2M::SendMail;
use R2M::GetMail;
use R2M::ParseMail;
use R2M::TieHandle;

Log::Log4perl::init('log4perl_test.conf');
#tie(*STDERR, 'R2M::TieHandle');

my @messages;
my $nMessages = 2;
for (my $i = 0; $i < $nMessages; $i++) {
    my $return_time = time + int(rand(2 * 60));
    my $dt = DateTime->from_epoch( epoch => $return_time , time_zone => 'America/Denver');
    my $return_when = $dt->hms . " " . $dt->mdy;
    print "Return date for message $i: $return_when";
    push @messages, {uid => 'dummy', address => 'return.to.me.test@gmail.com',subject => "subject $i", body => "R2M: $return_when \r\nbody $i"};
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
