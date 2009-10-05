#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::SendMail;
use Mod::GetMail;
use Mod::ParseMail;
use Mod::TieHandle;
use Mod::Conf;
use Mod::Test;

use Email::Simple;
use DateTime;

#Set up logging:
Log::Log4perl::init('conf/log4perl_test.conf');
tie(*STDERR, 'Mod::TieHandle');

my %conf = %{ &getConf("conf/test.conf") };

#Clear inbox:
&getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass});

#Create messages:
my @messages;
my $nMinutes = 2;
my @mail = &createMail(2,$nMinutes);
print "Sent:\n\n";
printf "%-20s %-20s\n",'Subject','Return Time';
print "-"x40,"\n";
for (@mail) {
    my $email = Email::Simple->new($_);
    my $to = $email->header('To');
    my $subject = $email->header('Subject');
    my %parsed_message = % { &parseMail($_,'dummy') }; 
    my $return_time = $parsed_message{'return_time'}; 
    push @messages, {
	address => $to,
	uid => 'dummy',
	mail => $_,
    };  

    printf "%-20s %-20s\n",$subject,&fromEpoch($return_time);
}

#Send messages:
&sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},@messages);

sleep $nMinutes * 60 + 60;
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

