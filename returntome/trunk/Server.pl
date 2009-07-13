#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Log::Log4perl;
use File::Copy;


use lib '/home/jack/returntome/sandbox/Modules/';

use R2M::GetMail;
use R2M::ParseMail;
use R2M::DB;
use R2M::SendMail;
use R2M::ParseInstructions;
#use R2M::Test;


#clean up:
unlink 'server.log';
unlink 'return-when.txt';

#initialize the logger:
Log::Log4perl::init('log4perl.conf');

#This server is implemented as 2 processes:
#The parent provides terminal I/O
#The child does the work
my $pid = fork;
#make sure the parent process when the child does:

if ($pid > 0) { #parent process
    local $SIG{CHLD} = sub {print "Child process died, stopping server\n"}; 
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
    $logger->info('Checked incoming.');

    open(OUT,">>return-when.txt") or die "couldn't open return-when.txt for output.\n"; 
    &openDB;
    my @raw_messages = &getMail;
    my $nMessages = @raw_messages;
    $logger->info("Retrieved $nMessages messages from SMTP server");
    for my $raw_message (@raw_messages) {
	my $uid = &getUID;
	my ($message_ref, $instructions) = parseMail($raw_message,$uid);
	my %message = %$message_ref;
	my $return_when = &parseInstructions($instructions);
	my $out = "$message{uid}  $return_when\n";
	$logger->info("Return-when:");
	$logger->info($out);
	unless ($return_when eq 'NONE') {
	    print OUT $out;
	    &putMessage(\%message);
	    $logger->info("Stored message $message{uid} in database");
	} else {
	    $logger->info('Message ' . $message{'uid'} . ' had no readable date.');
	}
    }
    &closeDB;
    close(OUT);
    
}

sub checkOutgoing {
    my $logger = Log::Log4perl->get_logger();
    $logger->info('Checked outgoing.');

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
		push @messages_to_send,\%message;
		$logger->info("Marked message $uid for return");
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
    &sendMessages(@messages_to_send);
}

sub getUID {
    state $num = 0;
    my $uid = sprintf "%09d", $num;
    $num++;
    return $uid;
}
