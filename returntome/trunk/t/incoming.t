#!/usr/bin/perl

use 5.010;

use strict;
use warnings;
use Test::More tests => 8;
use Test::MockObject;
use Test::MockModule;
use R2M::Conf;
use R2M::Parse;
use DBI;

#Mock Log::Log4perl
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

#$logger->set_true(qw(debug info error));

#Mock R2M::Mail
my $R2M_Mail = Test::MockModule->new('R2M::Mail');
$R2M_Mail->mock(
    get_mail => sub {
        return ();
        }
);
$R2M_Mail->mock(
    send_mail => sub{
        return ();
        }
);
use_ok('R2M::Talaria') or exit;

my $conf_file  = 'conf/talaria.conf';
my $key = 'foo';
my $conf = read_conf($conf_file, $key);
my $dbh = connect_db($conf);

#Clear DB
$dbh->do('TRUNCATE TABLE Messages');
$dbh->do('TRUNCATE TABLE Archive');

#No mail
incoming($conf, $dbh);

my ($method, $args) = $logger->next_call();
is($method, undef,'No messages should be logged during normal operation');

#One mail
my $mail =<<'END_MAIL';
Date: Tue, 11 Aug 2009 18:52:29 -0600
Subject: subject line
From: sender@domain.tld
To: return.to.me.test@gmail.com

R2M: January 22nd, 2010
this is the body
END_MAIL

my $parsed_mail =<<'END_MAIL';
From: return.to.me.test@gmail.com
To: sender@domain.tld
Subject: subject line

Your plain text ad here.

R2M: January 22nd, 2010
this is the body
END_MAIL

$R2M_Mail->mock(
    get_mail => sub {
        return ($mail);
    }
);
my $received =  from_epoch(time);
incoming($conf, $dbh);

my ($rows, $expected);

#Messages
$rows = $dbh->selectall_arrayref("SELECT * FROM Messages",{ Slice => {} });
is(scalar @{ $rows },1,'One row in Messages');
$expected = {
    uid => '000000001',
    address => 'sender@domain.tld',
    received_time => $received,
    return_time => '2010-01-22 00:00:00',
    sent_time => undef,
};
is_deeply($rows->[0], $expected, 'Row in Messages');

#RawMail
$rows = $dbh->selectall_arrayref("SELECT uid, AES_DECRYPT(mail,'$key') AS mail FROM RawMail",{ Slice => {} });
is(scalar @{ $rows },1,'One row in RawMail');
$expected = {
   uid => '000000001',
   mail => $mail,
};
is_deeply($rows->[0], $expected, 'Row in RawMail');

#ParsedMail
$rows = $dbh->selectall_arrayref("SELECT uid, AES_DECRYPT(mail,'$key') AS mail FROM ParsedMail",{ Slice => {} });
is(scalar @{ $rows },1,'One row in ParsedMail');
$expected = {
   uid => '000000001',
   mail => $parsed_mail,
};
is_deeply($rows->[0], $expected, 'Row in ParsedMail');

#TODO: test error conditions

$dbh->disconnect();
