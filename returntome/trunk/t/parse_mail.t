#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 5;
use Test::MockObject;
use Test::MockModule;
use Test::Differences;
use Email::Simple;

#TODO: deal with parser errors in log?
#TODO: right now this only checks that the instructions are parsed. Check for error messages, ads, correctly re-assembled messages?
#TODO: Currently tests are failing because return dates in the past now return undef
$INC{'Log/Log4perl.pm'} = 1;
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
#Mock R2M::Ad
my $R2M_Ad = Test::MockModule->new('R2M::Ad');
$R2M_Ad->mock(
    getPlainAd => sub {
        return 'This is a plain text ad.';
    }
);
$R2M_Ad->mock(
    getHTMLAd => sub{
        return 'This is a html ad.';
    }
);
use_ok('R2M::Parse') or exit;

my @mail_files= glob 't/mail/*.raw';

my $uid = 0;
for my $mail_file (@mail_files) {

    #Read in raw mail:
    open(my $in, '<', "$mail_file") or die "Couldn't open $mail_file: $!\n";
    my $raw_mail = do {
        local $/;
        <$in>;
    };
    close $in;
    $mail_file =~ s/\.raw$/\.parsed/;

    #Read in parsed_mail
    open($in, '<', "$mail_file") or die "Couldn't open $mail_file: $!\n";
    my $parsed_mail = do {
        local $/;
        <$in>;
    };
    close $in;

    my $message = parse_mail($raw_mail,'return.to.me.test@gmail.com', sprintf("%09d",$uid));

    $mail_file =~ s/\.parsed//;
    is($message->{return_time}, '2010-06-06 00:00:00', "$mail_file -- return_time");
    is($message->{address}    , 'address@domain.tld', "$mail_file -- address");
    is($message->{uid}        ,  sprintf("%09d",$uid), "$mail_file -- uid");
    eq_or_diff($message->{mail}, $parsed_mail, "$mail_file -- mail");

    $uid++;
}

