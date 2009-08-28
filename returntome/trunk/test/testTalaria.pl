#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

#use Time::Piece;


use Mod::SendMail;
use Mod::GetMail;
use Mod::ParseMail;
use Mod::TieHandle;

use Email::Simple;
use DateTime;

#Set up logging:
Log::Log4perl::init('conf/log4perl_test.conf');
tie(*STDERR, 'Mod::TieHandle');

#Clear inbox:
&getMail('imap.gmail.com','return.to.me.receive@gmail.com','return2me');

#Create messages:
#my @return_times;
my @messages;
my $nMessages = 2;
my $minutes = 2;

print "Sent:\n\n";
printf "%-20s %-20s\n",'Subject','Return Time';
print "-"x40,"\n";
for (my $i = 0; $i < $nMessages; $i++) {
    my $return_time = time + int(rand($minutes * 60));
    my $dt = DateTime->from_epoch( epoch => $return_time , time_zone => 'America/Denver');
    my $return_when = $dt->hms . " " . $dt->mdy;
    my $subject = "subject $i";
    #print "Return date for message $i: $return_when\n";
    #$return_times{$subject} = $return_when;
    
    printf "%-20s %-20s\n",$subject,$return_when;
    push @messages, {uid => 'dummy', address => 'return.to.me.test@gmail.com',mail => "To: return.to.me.test\@gmail.com\nFrom: return.to.me.receive\@gmail.com\nSubject: $subject\n\nR2M: $return_when \nbody $i"};
}

#Send messages:
&sendMail('smtp.gmail.com','return.to.me.receive@gmail.com','return2me',@messages);


sleep $minutes * 60 + 60;
my $dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
my $now = $dt->hms . " " . $dt->mdy;
print "\nChecked mail at $now\n\n";

#Check mail:
my @raw_messages = &getMail('imap.gmail.com','return.to.me.receive@gmail.com','return2me');
#system "aplay ~/dramatic_chord.wav";
unless (@raw_messages) {
    print "No messages\n";
    die "\n";
}
print "Received:\n";
printf "%-20s %-20s\n",'Subject','Return Time';
print "-"x40,"\n";
#See if we got the right message at the right time:
for my $raw_message (@raw_messages) {
    my $email = Email::Simple->new($raw_message);
    my $date = $email->header('Date');
    my $epoch =
    my $subject = $email->header('Subject');
    my $dt = DateTime->from_epoch( epoch => &parseInstructions($date) , time_zone => 'America/Denver');
    my $return_when = $dt->hms . " " . $dt->mdy;
    printf "%-20s %-20s\n",$subject,$return_when;
}

