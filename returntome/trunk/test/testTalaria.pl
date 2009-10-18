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

#TestTalaria.pl
#Send a set of test messages to the Talaria program
#Wait for their return
#Check that they were returned at the correct time

#Set up logging:
Log::Log4perl::init('conf/log4perl_test.conf');
tie(*STDERR, 'Mod::TieHandle');

#Read the config file:
my %conf = %{ &getConf("conf/test.conf") };

#Clear inbox:
&getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass});

#Create mail:
my $nMessages = 20; 
my $nMinutes = 120;
my @mail = &createMail($nMessages,$nMinutes);

my %requested;
my @messages;
for (@mail) {
    #Load the requested return time into a hash keyed by subject:
    my $subject = &getHeader($_,'Subject');
    my %parsed_message = % { &parseMail($_,'dummy') }; 
    my $return_time = $parsed_message{'return_time'};
    $requested{$subject} = $return_time;

    #Convert the mail to a message ready for sending:
    push @messages, {
	uid => 'dummy',
	mail => $_,
    };  
}

#Send messages:
#Sending more than 2 messages at a time seems to trip gmail's spam filter,
#So we send them one at a time.
for (@messages) {
    &sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},$_);
    sleep 30;
}
print "Sent mail at ",&now,"\n";

#Wait:
sleep(($nMinutes + 2) * 60);

#Check mail:
my @raw_messages = &getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass});

print "Checked mail at ",&now,"\n";

#Print the headers for the reports:
my $format =  "%-20s %-20s %-20s %-20s\n";
printf $format,'Subject','Requested','Sent','Error (sec)';
print "-"x80,"\n";

#Load the Date header of each received message into a hash keyed by Subject header
my %date;
for my $raw_message (@raw_messages) {
    my $subject = &getHeader($raw_message,'Subject');
    $subject =~ s/R2M: //;
    $date{$subject} = &parseInstructions( &getHeader($raw_message,'Date') );
}

#For each message received, print the time requested and the time sent:
for (sort keys %requested) {
    my $requested_time = $requested{$_};
    my $date_time = $date{$_};
    if ($date_time) {
	printf $format,$_,&fromEpoch($requested_time),&fromEpoch($date_time),abs($requested_time-$date_time);
    } else {
	printf $format,$_,&fromEpoch($requested_time),'Not Received';
    }
}

#Notify whoever's paying attention:
system "aplay -q ~/beep-7.wav";
