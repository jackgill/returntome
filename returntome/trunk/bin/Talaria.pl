#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Log::Log4perl;
use File::Copy;
#use Data::Dumper::Simple;
use Mod::GetMail;
use Mod::SendMail;
#use Mod::Test;
use Mod::ParseMail;
use Mod::DB;
use Mod::TieHandle;
#use Mod::UID;
use Mod::Conf;

#use DateTime;

#UID counter:
our $num = 0;

#Defaults for command line switches:
my $start_daemon = 1;
my $clear_tables = 0;

#Check command line arguments:
for (@ARGV) {
    $start_daemon = 0 if ($_ eq '--no-daemon');
    $clear_tables = 1 if ($_ eq '--clear-tables');
} 

#initialize the logger:
Log::Log4perl::init('conf/log4perl_talaria.conf');
my $logger = Log::Log4perl->get_logger();

#Send STDERR to logger:
tie(*STDERR, 'Mod::TieHandle');


my %conf = %{ &getConf("conf/talaria.conf") };

#TODO: check that conf file was complete!


#Connect to DB:
&DB::connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});
&clearTables if $clear_tables;

#This program is implemented as 2 processes:
#The parent process provides terminal I/O: CLI
#The child process does the work: daemon
my $pid = 1;
$pid = fork if $start_daemon;

if ($pid > 0) { #CLI process

    #define commands:
    my %commands = (
	log => sub {
	    system 'cat log/talaria.log';
	},
	showdb => \&showTables,
	makedb => \&makeTables,
	cleardb => \&clearTables, 
	checkmail => sub {
	    eval {&checkIncoming};
	    if ($@) {
		$logger->error("Error checking incoming: $@");
	    }
	},
	time => sub {
	    print &fromEpoch(time),"\n";
	},
	);

    #CLI loop:
    while (1) {
	print "Talaria>"; #display prompt
	chomp(my $line = <STDIN>); #read prompt
	if ($line eq 'stop'){
	    &DB::disconnect;
	    kill 9, $pid; #kill the daemon
	    $logger->info("Talaria daemon stopped.");
	    print "Talaria daemon stopped.\n";
	    exit 0;
	}
	elsif ($commands{$line}) {
	    eval { &{$commands{$line}} };
	    print "Error executing command: $@" if $@;
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

    my @raw_messages = &getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass});
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
	if ($return_time) {
	    #TODO: if &fromEpoch crashes, we're boned and the message gets lost.
	    #use eval block?
	    $logger->info("Return date for message $uid: " . &fromEpoch($return_time));
	    push @parsed_messages, \%message;
	} else {
	    $logger->info('Message ' . $message{'uid'} . ' had no readable date.');
	    push @unparsed_messages, \%message;
	}
    }
    &putMessages('ParsedMessages',@parsed_messages);
    &putMessages('UnparsedMessages',@unparsed_messages);
    #If we couldn't parse the message, return it to sender:
    &sendMessages(@unparsed_messages);
}

sub checkOutgoing {
    $logger->debug('');
    $logger->debug('Checking outgoing...');

    my $current_time = time;
    my @messages_to_send = &getMessagesToSend($current_time);
    &sendMessages(@messages_to_send);
}

sub sendMessages{
    my @messages = @_;
    return unless @messages;
    my ($sent_ref,$unsent_ref) = &sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},@messages);
    &putMessages('SentMessages',@$sent_ref);
    &putMessages('UnsentMessages',@$unsent_ref);
}



sub getUID {
    my $uid = sprintf "%09d", $num;
    $num++;
    return $uid;
}

