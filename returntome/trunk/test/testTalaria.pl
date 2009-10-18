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
my %requested;
my $nMinutes = 10;
my @mail = &createMail(2,$nMinutes);
#print "Sent:\n\n";
#printf "%-20s %-20s\n",'Subject','Return Time';
#print "-"x40,"\n";
for (@mail) {
    my $to = &getHeader($_,'To');
    my $subject = &getHeader($_,'Subject');
    my %parsed_message = % { &parseMail($_,'dummy') }; 
    my $return_time = $parsed_message{'return_time'};
    $requested{$subject} = $return_time;
    push @messages, {
	uid => 'dummy',
	mail => $_,
    };  
}

#Send messages:
&sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},@messages);
my $dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
my $now = $dt->hms . " " . $dt->mdy;
print "\nSent mail at $now\n\n";
sleep(($nMinutes + 2) * 60);
$dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
$now = $dt->hms . " " . $dt->mdy;
print "\nChecked mail at $now\n\n";

#Check mail:
my @raw_messages = &getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass});
system "aplay -q ~/beep-7.wav";

my $format =  "%-20s %-20s %-20s %-20s\n";
printf $format,'Subject','Requested','Received','Error (sec)';
print "-"x80,"\n";
#See if we got the right message at the right time:
my %received;
for my $raw_message (@raw_messages) {
    my $date = &getHeader($raw_message,'Date');
    my $subject = &getHeader($raw_message,'Subject');
    $subject =~ s/R2M: //;
    $received{$subject} = &parseInstructions($date);
}
for (sort keys %requested) {
    my $received_time = $received{$_};
    if ($received_time) {
	printf $format,$_,&fromEpoch($requested{$_}),&fromEpoch($received_time),abs($requested{$_}-$received_time);
    } else {
	printf $format,$_,&fromEpoch($requested{$_}),'Not Received';
    }
}
