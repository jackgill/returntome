#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Log::Log4perl;
use File::Copy;


#use lib '/home/jack/returntome/trunk/Modules/';

#use R2M::GetMail;
#use R2M::SendMail;
use R2M::Test;
use R2M::ParseMail;
use R2M::DB;
use R2M::TieHandle;
use R2M::UID;

use DateTime;

my $debug = 0;
for (@ARGV) {
    $debug = 1 if ($_ eq '--debug');
} 
#clean up:
unlink 'server.log';
&clearMessages;

#initialize the logger:
Log::Log4perl::init('log4perl.conf');
#tie(*STDERR, 'R2M::TieHandle');
#tie(*STDOUT, 'R2M::TieHandle');

#This server is implemented as 2 processes:
#The parent provides terminal I/O
#The child does the work
my $pid = fork;

if ($pid > 0) { #parent process
    print "ReturnToMe server started.\n";
    while (1) {
	print "ReturnToMe>"; #display prompt
	my $line = <STDIN>; #read prompt
	#commands:
	if ($line =~ /stop/) { #stop the server
	    kill 9, $pid; #kill the child
	    die "ReturnToMe server stopped.\n";
	}
	elsif ($line =~ /logs/) {
	    system 'cat server.log';
	}
	elsif ($line =~ /return-when/) {
	    system 'cat return-when.txt';
	}
	elsif ($line =~/showdb/) {
	    &showMessages;
	}
	elsif ($line =~/makedb/) {
	    &makeTable;
	}
	elsif ($line =~ /time/) {
	    my $dt = DateTime->from_epoch( epoch => time, time_zone => 'America/Denver');
	    print $dt->hms . " " . $dt->mdy . "\n";
	}
	else {
	    print "Unrecognized command\n";
	}
    }
} elsif ($pid == 0) { #child process
    while (1) {
	sleep 60 if $debug;
	&checkIncoming;
	&checkOutgoing;
	sleep 30;
    }
} else {
    die "Can't fork: $!\n";
}



#Subroutines:
sub checkIncoming {
    my $logger = Log::Log4perl->get_logger();
    $logger->info('');
    $logger->info('Checking incoming...');

    my @raw_messages = &getMail('return.to.me.test@gmail.com','return2me');
    my @messages;
    my $nMessages = @raw_messages;
    $logger->info("Retrieved $nMessages messages from IMAP server");
    for my $raw_message (@raw_messages) {
	my $uid = &getUID;
	my %message = % { parseMail($raw_message,$uid) }; 
	my $return_time = $message{'return_time'};
	unless ($return_time eq 'NONE') {
	    my $dt = DateTime->from_epoch( epoch => $return_time , time_zone => 'America/Denver');
	    $logger->info("Return date for message $uid: " . $dt->hms . " " . $dt->mdy);
	    push @messages, \%message;
	} else {
	    $logger->info('Message ' . $message{'uid'} . ' had no readable date.');
	    #store message for debug?
	}
    }
    &putMessages(@messages);
}

sub checkOutgoing {
    my $logger = Log::Log4perl->get_logger();
    $logger->info('');
    $logger->info('Checking outgoing...');

    my $current_time = time;
    my @uids_to_send;
    my @return_times = &getReturnTimes;
    for (@return_times) {
	my ($uid, $return_time) = @$_;
	if ($return_time < $current_time) {
	    push @uids_to_send, $uid;
	    $logger->info("Marked message $uid for retrieval");
	}
    }
    my @messages_to_send = &getMessages(@uids_to_send);
    for (@messages_to_send) {
	my %message = %$_;
	my $uid = $message{'uid'};
	$logger->debug("Retrieved message $uid from database");
	my $subject= $message{'subject'};
	$message{'subject'} = "Returned To You: $subject";

    }
    my $nMessages_to_send = @messages_to_send;
    $logger->info("Sent $nMessages_to_send messages to SMTP server");
    &sendMessages('return.to.me.test@gmail.com','return2me',@messages_to_send) if @messages_to_send;
}

