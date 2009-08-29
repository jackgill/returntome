#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::SendMail;
use Mod::GetMail;
use Mod::ParseMail;
use Mod::TieHandle;
use Mod::Conf;

use Email::Simple;
use DateTime;

#Set up logging:
Log::Log4perl::init('conf/log4perl_test.conf');
tie(*STDERR, 'Mod::TieHandle');

my %conf = %{ &getConf("conf/test.conf") };

#Clear inbox:
&getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass});

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
&sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},@messages);

sleep $minutes * 60 + 60;
my $dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
my $now = $dt->hms . " " . $dt->mdy;
print "\nChecked mail at $now\n\n";

#Check mail:
my @raw_messages = &getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass});
system "aplay ~/beep-7.wav";
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
    my $subject = $email->header('Subject');
    my $dt = DateTime->from_epoch( epoch => &parseInstructions($date) , time_zone => 'America/Denver');
    my $return_when = $dt->hms . " " . $dt->mdy;
    printf "%-20s %-20s\n",$subject,$return_when;
}

