#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 27;
use Test::MockObject;

$INC{'Net/SMTP/SSL.pm'} = 1; #prevent Net::SMTP::SSL from being loaded
$INC{'Log/Log4perl.pm'} = 1; #prevent Log::Log4perl from being loaded

use_ok('R2M::Mail') or exit;

#Define SMTP authentication credentials
my $server = 'smtp.gmail.com';
my $from_address = 'from@example.com';
my $password = 'secret';

#Mock Net::SMTP::SSL
my $smtp = Test::MockObject->new();

#Net::SMTP::SSL->new() establishes a connection with the SMTP server
$smtp->fake_module(
    'Net::SMTP::SSL',
    new => sub {
        my ($self, $got_server, undef, $port, undef, $debug) = @_;
        if ($got_server eq $server && $port == 465) {
            return $smtp;
        }
    },
);

#$smtp->message() returns the response of the SMTP server
my $accepted = 1;
my $error_response = 'DENIED';
$smtp->mock('message',
            sub {
                if ($accepted) {
                    return '2.0.0 OK';
                }
                else {
                    return $error_response;
                }
            }
        );

#$smtp->auth() authenticates to the SMTP server
$smtp->mock('auth',
            sub {
                my ($self, $login, $pass) = @_;
                if ($login eq $from_address && $pass eq $password) {
                    return 1;
                }
            }
        );

$smtp->set_true(qw(mail to data datasend dataend quit));

#Mock Log::Log4perl
my $logger = Test::MockObject->new();
$logger->fake_module(
    'Log::Log4perl',
    get_logger => sub {$logger},
    );
$logger->set_true(qw(debug info error));

#Create a new message
my $mail =<<'END_MAIL';
MIME-Version: 1.0
Content-Transfer-Encoding: binary
Content-Type: multipart/alternative; boundary="_----------=_126033191110930"
X-Mailer: MIME::Lite 3.024 (F2.76; T1.27; A2.04; B3.07_01; Q3.07)
Date: Tue, 8 Dec 2009 21:11:51 -0700
From: return.to.me.receive@gmail.com
To: return.to.me.receive@gmail.com
Subject: subject 0

This is a multi-part message in MIME format.

--_----------=_126033191110930
Content-Disposition: inline
Content-Length: 23
Content-Transfer-Encoding: binary
Content-Type: text/plain

no instructions here...
--_----------=_126033191110930
Content-Disposition: inline
Content-Length: 31
Content-Transfer-Encoding: binary
Content-Type: text/html

<br>no instructions here...<br>
--_----------=_126033191110930--
END_MAIL

my $to_address = 'to@example.com';
my $uid = '2';

my %message = (
    address => $to_address,
    uid => $uid,
    mail => $mail,
    );

#Send message using mocked Net::SMTP::SSL object
my @sent_uids = send_mail($server,$from_address,$password,\%message);

is_deeply(\@sent_uids, [$uid], 'UID of sent message is returned');

#Check logger
my ($method, $args) = $logger->next_call();
is($method, undef,'No messages should be logged during normal operation');

#Check that mocked object was exercised properly

($method, $args) = $smtp->next_call();
is($method   , 'auth'              , 'Authenticate to SMTP server'      );
is($args->[1], $from_address       , '...using sending address'         );
is($args->[2], $password           , '...and password'                  );

($method, $args) = $smtp->next_call();
is($method   , 'mail'              , 'Open mail transfer'               );
is($args->[1], $from_address . "\n", '...using sending address'         );

($method, $args) = $smtp->next_call();
is($method   , 'to'                , "Set 'To' address of SMTP envelope");
is($args->[1], $to_address . "\n"  , "...using 'To' address"            );

($method, $args) = $smtp->next_call();
is($method   , 'data'              , 'Start data transfer'              );

($method, $args) = $smtp->next_call();
is($method   , 'datasend'          , 'Send data'                        );
is($args->[1], $mail . "\n"        , '...using mail'                    );

($method, $args) = $smtp->next_call();
is($method   , 'dataend'           , 'End data transfer'                );

($method, $args) = $smtp->next_call();
is($method   , 'message'           , 'Check SMTP server response'       );

($method, $args) = $smtp->next_call();
is($method   , 'quit'              , 'Close connection to server'       );

#Check that errors are logged
@sent_uids = send_mail('smtp.wrong.domain',$from_address,$password,\%message);
($method, $args) = $logger->next_call();
is($method   ,'error'                           , 'Error logged for failed connection');
is($args->[1],'Could not connect to SMTP server', '...logged appropriate message'     );
is(scalar @sent_uids, 0, '...no UIDs returned');

@sent_uids = send_mail('smtp.gmail.com',$from_address,'wrong password',\%message);
($method, $args) = $logger->next_call();
is($method   ,'error'                                , 'Error logged for failed authentication');
is($args->[1],'Could not authenticate to SMTP server', '...logged appropriate message'         );
is(scalar @sent_uids, 0, '...no UIDs returned');

$accepted = 0;
@sent_uids = send_mail('smtp.gmail.com',$from_address,$password,\%message);
($method, $args) = $logger->next_call();
is($method   , 'error'                    , 'Error logged for SMTP server not accepting message');
is($args->[1], "Did not send message $uid: DENIED", '...logged appropriate message'                     );
($method, $args) = $logger->next_call();

$message{address} = '';
@sent_uids = send_mail('smtp.gmail.com',$from_address,$password,\%message);
($method, $args) = $logger->next_call();
is($method   , 'error'                    , 'Error logged for null address field in message hash');
is($args->[1], "Address is null for message $uid.", '...logged appropriate message'                     );
is(scalar @sent_uids, 0, '...no UIDs returned');
