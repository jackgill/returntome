#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;
use Test::MockObject;
use Config::Tiny;
use R2M::Crypt;

$INC{'Log/Log4perl.pm'} = 1;

#Mock Log::Log4perl
my $logger = Test::MockObject->new();
$logger->fake_module(
    'Log::Log4perl',
    get_logger => sub {$logger},
    );
$logger->mock('error',
            sub {
                my ($self, $text) = @_;
                print "\$logger->error($text)\n";
            }
        );

use_ok('R2M::Mail');

#Read conf file
my $conf_file  = "conf/talaria.conf";
my $key = 'foo';
open (my $in, '<', $conf_file) or die "Can't open $conf_file: $!\n";
my $conf_file_str = do {
    local $/;
    <$in>;
};
close $in;

#Decrypt conf file
$conf_file_str = decrypt($key, $conf_file_str);

#Process conf file
my $conf = Config::Tiny->read_string( $conf_file_str );

my $address = 'return.to.me.receive@gmail.com';
my $subject = 'test message ' . time;
#Clear inbox
get_mail(
    $conf->{imap}->{server},
    $address,
    $conf->{imap}->{pass},
);

#Create message
my $mail=<<"END_MAIL";
To: $address
From: $conf->{smtp}->{user}
Subject: $subject

This is the body of the message


END_MAIL

my %message = (
    mail => $mail,
    address =>  $address,
    uid => 'test',
);

#Send message
my @sent_uids = send_mail(
        $conf->{smtp}->{server},
        $conf->{smtp}->{user},
        $conf->{smtp}->{pass},
        \%message
    );

is($sent_uids[0], 'test', 'Send Message');

sleep 10;

#Check mail
my @got_messages = get_mail(
    $conf->{imap}->{server},
    $address,
    $conf->{imap}->{pass},
);

#See if we received the right message
is(scalar @got_messages, 1, 'Received 1 Message');
like($got_messages[0], qr/Subject: $subject/, "...and it's the right one");
