#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;
use Test::MockObject;

#We're going to mock these modules, so prevent them from being loaded
$INC{'Net::IMAP::Simple::SSL'} = 1;
$INC{'Log/Log4perl.pm'} = 1;

use_ok('R2M::Mail') or exit;

#Define IMAP authentication credentials
my $server = 'imap.domain.tld';
my $address = 'address@domain.tld';
my $password = 'secret';

#Mock Net::IMAP::Simple::SSL
my $imap = Test::MockObject->new();

#Net::IMAP::Simple::SSL->new() establishes a connection with the IMAP server
$imap->fake_module(
    'Net::IMAP::Simple::SSL',
    new => sub {
        my ($self, $got_server) = @_;
        if ($got_server eq $server) {
            return $imap;
        }
    },
);

#$imap->login() authenticates to the IMAP server
$imap->mock('login',
            sub {
                my ($self, $got_address, $got_password) = @_;
                if ($got_address eq $address && $got_password eq $password) {
                    return 1;
                }
            }
        );
#$imap->get() retrieves a message as an array ref
$imap->mock('get',
            sub {
                my @message = (
                    'oh goodness, a message!',
                    "and it's on 2 lines!",
                    );
                return \@message;
            }
        );
#$imap->errstr() returns an error message
$imap->mock('errstr',
            sub {
                return 'DENIED';
            }
        );
$imap->set_true(qw(select delete quit));

#Mock Log::Log4perl
my $logger = Test::MockObject->new();
$logger->fake_module(
    'Log::Log4perl',
    get_logger => sub {$logger},
    );
$logger->set_true(qw(debug info error));

get_mail($server, $address, $password);

my ($method, $args) = $logger->next_call();
is($method, undef,'No messages should be logged during normal operation');

($method, $args) = $imap->next_call();
is($method   , 'login'    , 'Authenticate to IMAP server' );
is($args->[1], $address   , '...using sending address'    );
is($args->[2], $password  , '...and password'             );

($method, $args) = $imap->next_call();
is($method   , 'select'   , 'Selecting folder'            );
is($args->[1], 'INBOX'    , '...which is INBOX'           );

($method, $args) = $imap->next_call();
is($method   , 'get'      , 'Retrieving message'          );
is($args->[1], 1          , '...using its index'          );

($method, $args) = $imap->next_call();
is($method   , 'delete'   , 'Delete the message'          );
is($args->[1], 1          , '...using its index'          );

($method, $args) = $imap->next_call();
is($method   , 'quit'     , 'Close connection with IMAP server' );

#Check that errors are logged
get_mail('wrong server', $address, $password);

($method, $args) = $logger->next_call();
is($method   ,'error'                           , 'Error logged for failed connection');
is($args->[1],'Could not connect to IMAP server.', '...logged appropriate message'     );

get_mail($server, $address, 'wrong password');

($method, $args) = $logger->next_call();
is($method   ,'error'                           , 'Error logged for failed authentication');
is($args->[1],'Could not login to IMAP server: DENIED', '...logged appropriate message'     );

