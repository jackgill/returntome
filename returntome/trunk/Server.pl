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
use R2M::ParseInstructions;
use R2M::TieHandle;
use R2M::UID;


#clean up:
unlink 'server.log';
unlink 'return-when.txt';
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
	else {
	    print "Unrecognized command\n";
	}
    }
} elsif ($pid == 0) { #child process
    while (1) {
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
    $logger->info('Checking incoming...');

    open(OUT,">>return-when.txt") or die "couldn't open return-when.txt for output.\n"; 
 
    my @raw_messages = &getMail('return.to.me.test@gmail.com','return2me');
    my @messages;
    my $nMessages = @raw_messages;
    $logger->info("Retrieved $nMessages messages from SMTP server");
    for my $raw_message (@raw_messages) {
	my $uid = &getUID;
	my ($message_ref, $instructions) = parseMail($raw_message,$uid);
	my %message = %$message_ref;
	my $subject= $message{'subject'};
	$message{'subject'} = "Returned To You: $subject";
	my $return_when = &parseInstructions($instructions);
	my $out = "$message{uid}  $return_when\n";
	$logger->info("Return-when:");
	$logger->info($out);
	unless ($return_when eq 'NONE') {
	    print OUT $out;
	    push @messages, \%message;
	    $logger->info("Stored message $message{uid} in database");
	} else {
	    $logger->info('Message ' . $message{'uid'} . ' had no readable date.');
	}
    }
    &putMessages(@messages);
    close(OUT);
    
}

sub checkOutgoing {
    my $logger = Log::Log4perl->get_logger();
    $logger->info('Checking outgoing...');

    my $current_time = time;
    my @uids_to_send;

    #read the return-when list
    open(IN,"<return-when.txt") or die "couldn't open return-when.txt for input.\n";
    open(OUT,">return-when.txt.temp") or die "couldn't open return-when.txt.temp for output.\n";
    while (<IN>) {
	if (/(\d+)  (\S+)/) {
	    my $uid = $1;
	    my $date = $2;
	    my $send_time = &parseReturnWhen($date); #eliminate this call, 
	    if ($send_time < $current_time) {
		push @uids_to_send, $uid;
		$logger->debug("Marked message $uid for retrieval");
	    } else {
		print OUT $_;
	    }
	} else {
	    print OUT $_;
	}
    }
    close(IN);
    close(OUT);
    move("return-when.txt.temp","return-when.txt");

    my @messages_to_send = &getMessages(@uids_to_send);
    for (@messages_to_send) {
	my %message = %$_;
	my $uid = $message{'uid'};
	$logger->info("Retrieved message $uid from database");
    }
    &sendMessages('return.to.me.test@gmail.com','return2me',@messages_to_send);
}

