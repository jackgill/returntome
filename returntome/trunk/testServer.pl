#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Date::Manip;
use Time::Piece;

use lib '/home/jack/returntome/sandbox/Modules/';
use R2M::SendMail;
use R2M::GetMail;
use R2M::ParseMail;

Log::Log4perl::init('log4perl_test.conf');

my $now = localtime;
my $wait =  int(rand(2 * 60));
my $return_time = $now + $wait;
my $return_when =$return_time->datetime;

#print $now,"\n";
#print $wait,"\n";
#print $return_time,"\n";
#print $return_when,"\n";
#die;
my $address = 'return.to.me.test@gmail.com';
my $subject = 'subject';
my $body = "R2M: $return_when\n body";
print "Message sent at ",$now->datetime,"\n";
print "Return requested at ",$return_when,"\n";
&sendMail($address,$subject,$body,'return.to.me.receive@gmail.com','return2me');
sleep $wait + 60;
my @raw_messages = &getMail;
die "No messages\n" unless (@raw_messages);
my $date = getDate($raw_messages[0]);

$now = localtime;
print "Message received at ",$now->datetime,"\n";

