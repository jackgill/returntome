#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use lib '/home/jack/returntome/sandbox/Modules/';
use R2M::Test;
use R2M::DB;
use R2M::GetMail;
use Data::Dumper::Simple;
use R2M::ParseMail;
#&createReturnWhen;
#&openDB;
#&deleteMessage('000000001');
#&closeDB;
my @messages = &getMail;
for my $raw_message (@messages) {
    my $uid = &getUID;
    #my @message = @$ref;
    #print Dumper(@message);
    my ($message_ref, $instructions) = parseMail($raw_message,$uid);
    my %message = %$message_ref;
    #print Dumper(%message);
    #print $instructions,"\n";
    #print "---------------------\n";
}
sub getUID {
    state $num = 0;
    my $uid = sprintf "%09d", $num;
    $num++;
    return $uid;
}
