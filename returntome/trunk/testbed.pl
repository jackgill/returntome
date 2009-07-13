#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use lib '/home/jack/returntome/sandbox/Modules/';

use R2M::GetMail;
use R2M::ParseMail;
use R2M::DB;
use R2M::SendMail;
use R2M::ParseInstructions;

use Test::GenerateMessages;
if (0) {
    my $raw_message = getMail;
    open(OUT,">raw_message.txt") or die "couldn't open output file.\n";
    print OUT $raw_message;
}
if (0) {
    open(OUT,">return-when.txt") or die "couldn't open return-when.txt for output.\n"; #in the future, open for appending    
    printf OUT "%-9s  %-16s\n",'UID','Date'; #in the future, only print these once
    printf OUT "%-9s  %-16s\n",'-'x9,'-'x16;
#my $raw_message = getMail;
    my @uids = ('001','002');
    my @raw_messages = generateMail(@uids);
    for my $raw_message (@raw_messages) {
	#print $raw_message;
	my $uid = &getUID;
	my ($message_ref, $instructions) = parseMail($raw_message,$uid);
	my %message = %$message_ref;
	putMessage(\%message);
	#print "MESSAGE:\n";
	#print Dumper(%message);
	#print "INSTRUCTIONS:\n$instructions\n";
	my $return_when = &parseInstructions($instructions); 
	print OUT $message{'uid'},"  ",$return_when,"\n";
    }
    close OUT;
}

if (0) {
    open(IN,"<return-when.txt") or die "couldn't open return-when.txt for input.\n";
    my $current_time = time;
    my @messages_to_send;
    while (<IN>) {
	if (/(\d+)  (\S+)/) {
	    my $uid = $1;
	    my $date = $2;
	    $date = ParseDate($date);
	    my $send_time = UnixDate($date,"%s");
	    my %message = %{ getMessage($uid) };
	    print Dumper(%message);
	    if ($send_time < $current_time) {
		push @messages_to_send,\%message;
	    }
	}
    }
    for (@messages_to_send) {
	sendMessage($_);
    }
}

sub getUID {
    state $num = 0;
    my $uid = sprintf "%09d", $num;
    $num++;
    return $uid;
}
sub printLine {
    my $line = shift;
    my @bytes = unpack("C*",$line);
    print @bytes,"\n";
}
