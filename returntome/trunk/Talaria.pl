#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Log::Log4perl;
use File::Copy;

use Mod::GetMail;
use Mod::SendMail;
#use Mod::Test;
use Mod::ParseMail;
use Mod::DB;
use Mod::TieHandle;
use Mod::UID;

use DateTime;

my $start_daemon = 1;
for (@ARGV) {
    $start_daemon = 0 if ($_ eq '--no-daemon');
} 

#clean up:
unlink 'talaria.log';

#initialize the logger:
Log::Log4perl::init('conf/log4perl_talaria.conf');
my $logger = Log::Log4perl->get_logger();

#Send STDERR to logger:
tie(*STDERR, 'Mod::TieHandle');

#Connect to DB:
&connect;
&clearTables; #TODO: probably don't want to do this in production

#This program is implemented as 2 processes:
#The parent process provides terminal I/O: CLI
#The child process does the work: daemon
my $pid = 1;
$pid = fork if $start_daemon;

if ($pid > 0) { #CLI process

    #define commands:
    my %commands = (
	log => sub {
	    system 'cat talaria.log';
	},
	showdb => \&showTables,
	makedb => \&makeTables,
	cleardb => \&clearTables, 
	time => sub {
	    print &fromEpoch(time),"\n";
	},
	);

    #CLI loop:
    while (1) {
	print "Talaria>"; #display prompt
	chomp(my $line = <STDIN>); #read prompt
	if ($line eq 'stop'){
	    &disconnect;
	    kill 9, $pid; #kill the daemon
	    $logger->info("Talaria daemon stopped.");
	    print "Talaria daemon stopped.\n";
	    exit 0;
	}
	elsif ($commands{$line}) {
	    eval { &{$commands{$line}} };
	    warn "Error executing command: $@" if $@;
	}
	else {
	    print "Unrecognized command\n";
	}
    }
} elsif ($pid == 0) { #daemon
    $logger->info("Talaria daemon started.");
    print "Talaria daemon started.\n";
    while (1) {
	eval {&checkIncoming};
        if ($@) {
	    $logger->error("Error checking incoming: $@");
	}
	eval {&checkOutgoing};
        if ($@) {
	    $logger->error("Error checking outgoing: $@");
	}
	sleep 60;
    }
} else {
    die "Couldn't create daemon: $!\n";
}

#Subroutines:
sub checkIncoming {
    $logger->debug('');
    $logger->debug('Checking incoming...');

    my @raw_messages = &getMail('imap.gmail.com','return.to.me.test@gmail.com','return2me');
    my @parsed_messages;
    my @unparsed_messages;

    my $nMessages = @raw_messages;
    if ($nMessages != 0) {
	$logger->info("Retrieved $nMessages messages from IMAP server");
    }
    for my $raw_message (@raw_messages) {
	my $uid = &getUID;
	$logger->debug('');
	$logger->debug('Raw Message $uid:');
	$logger->debug($raw_message);


	my %message = % { &parseMail($raw_message,$uid) }; 
	my $return_time = $message{'return_time'};
	unless ($return_time eq 'NONE') {
	    $logger->info("Return date for message $uid: " . &fromEpoch($return_time));
	    push @parsed_messages, \%message;
	} else {
	    $logger->info('Message ' . $message{'uid'} . ' had no readable date.');
	    push @unparsed_messages, \%message;
	    #TODO: send back an error email

	}
    }
    &putMessages('ParsedMessages',@parsed_messages);
    &putMessages('UnparsedMessages',@unparsed_messages);

    #If we couldn't parse the message, return it to sender, with an error message:
    if (@unparsed_messages) {
	for my $message (@unparsed_messages) {
	    #TODO: This doesn't work:
	    my $subject= $message{'subject'};
	    $message{'subject'} = "Returned To You: $subject";
	    my $body = $message{'body'};
	    $message{'body'} = "Sorry, we couldn't parse this.\n$body";
	}
	&sendMessages(@unparsed_messages);
    }
}

sub checkOutgoing {
    $logger->debug('');
    $logger->debug('Checking outgoing...');

    my $current_time = time;
    my @messages_to_send = &getMessagesToSend($current_time);
    for (@messages_to_send) {
	my %message = %$_;
	my $uid = $message{'uid'};
	$logger->info("Marked message $uid for sending.");
	#TODO: subject isn't being altered
	my $subject= $message{'subject'};
	$message{'subject'} = "Returned To You: $subject";
    }
    my $nMessages_to_send = @messages_to_send;
    
    &sendMessages(@messages_to_send) if @messages_to_send;
}

sub sentMessages{
    my @messages_to_send = @_;
    my ($sent,$unsent) = &sendMail('smtp.gmail.com','return.to.me.test@gmail.com','return2me',@messages_to_send);
    &putMessages('SentMessages',@$sent);
    &putMessages('UnsentMessages',@$unsent);
    $logger->info("Sent $nMessages_to_send messages to SMTP server");
}

sub fromEpoch {
    my $epoch = shift;
    my $dt = DateTime->from_epoch( epoch => $epoch , time_zone => 'America/Denver');
    return $dt->hms . " " . $dt->mdy;
}
