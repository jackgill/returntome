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
unlink 'talaria-info.log';
unlink 'talaria-debug.log';


#initialize the logger:
Log::Log4perl::init('conf/log4perl_talaria.conf');
#Send STDERR to logger:
tie(*STDERR, 'Mod::TieHandle');

#Connect to DB:
&connect;
&clearMessages;

#This program is implemented as 2 processes:
#The parent provides terminal I/O: CLI
#The child does the work: daemon
my $pid = 1;
$pid = fork if $start_daemon;

if ($pid > 0) { #CLI process

    #commands:
    my %commands = (
	info => sub {
	    system 'cat talaria-info.log';
	},
	debug => sub {
	    system 'cat talaria-debug.log';
	},
	showdb => \&showMessages,
	makedb => \&makeTables,
	cleardb => \&clearMessages, 
	time => sub {
	    my $dt = DateTime->from_epoch( epoch => time, time_zone => 'America/Denver');
	    print $dt->hms . " " . $dt->mdy . "\n";
	},
	);
    while (1) {
	print "Talaria>"; #display prompt
	chomp(my $line = <STDIN>); #read prompt
	if ($line eq 'stop'){
	    &disconnect;
	    kill 9, $pid; #kill the daemon
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
    my $logger = Log::Log4perl->get_logger();
    $logger->info("Started daemon");
    print "Talaria daemon started.\n";
    while (1) {
	eval {&checkIncoming};
        if ($@) {
	    $logger->info("Error checking incoming: $@");
	}
	eval {&checkOutgoing};
        if ($@) {
	    $logger->info("Error checking outgoing: $@");
	}
	sleep 60;
    }
} else {
    die "Couldn't create daemon: $!\n";
}



#Subroutines:
sub checkIncoming {
    my $logger = Log::Log4perl->get_logger();
    $logger->debug('');
    $logger->debug('Checking incoming...');

    my @raw_messages = &getMail('imap.gmail.com','return.to.me.test@gmail.com','return2me');
    my @messages;
    my $nMessages = @raw_messages;
    if ($nMessages != 0) {
	$logger->info("Retrieved $nMessages messages from IMAP server");
    }
    for my $raw_message (@raw_messages) {
	$logger->debug('');
	$logger->debug('Raw Message:');
	$logger->debug($raw_message);

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
	    #TODO: send back an error email
	    $logger->info('Message follows:');
	    $logger->info($raw_message);
	}
    }
    &putMessages('Messages',@messages);
}

sub checkOutgoing {
    my $logger = Log::Log4perl->get_logger();
    $logger->debug('');
    $logger->debug('Checking outgoing...');

    my $current_time = time;
    my @messages_to_send = &getMessagesToSend('Messages',$current_time);
    for (@messages_to_send) {
	my %message = %$_;
	#my $uid = $message{'uid'};
	#$logger->debug("Retrieved message $uid from database");
	my $subject= $message{'subject'};
	$message{'subject'} = "Returned To You: $subject";
	#TODO: subject isn't being altered
    }
    my $nMessages_to_send = @messages_to_send;
    
    if (@messages_to_send) {
	my ($sent,$unsent) = &sendMessages('smtp.gmail.com','return.to.me.test@gmail.com','return2me',@messages_to_send);
	&putMessages('SentMessages',@$sent);
	&putMessages('UnsentMessages',@$unsent);
	$logger->info("Sent $nMessages_to_send messages to SMTP server");
    } 
}

