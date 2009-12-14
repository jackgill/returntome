#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 3;
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
my @sent_args;
#Mock R2M::Mail
my $R2M_Mail = Test::MockModule->new('R2M::Mail');
$R2M_Mail->mock(
    get_mail => sub {
        return ();
        }
);
$R2M_Mail->mock(
    send_mail => sub{
        @sent_args = @_;
        return (1);
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

my $create_entry = $dbh->prepare("INSERT INTO Messages VALUES (NULL, ?, NOW(), ?, NULL)");
my $store_parsed = $dbh->prepare("INSERT INTO ParsedMail VALUES (?, AES_ENCRYPT(?,?))");

my $address = 'sender@domain.tld';
my $mail = 'this is a mail message';
my $db_key = $conf->{db}->{key};
my $uid = '000000001';
$create_entry->execute($address, '2009-12-13 00::00::00');
$store_parsed->execute($uid, $mail, $db_key);
my $start_time = from_epoch(time);

outgoing($conf, $dbh);
my %message = (
    address => $address,
    mail => $mail,
    uid => $uid,
    );
my @expected_sent_args = ($conf->{smtp}->{server},
                          $conf->{smtp}->{user},
                          $conf->{smtp}->{pass},
                          \%message);
is_deeply(\@sent_args,\@expected_sent_args, 'Called R2M::Mail::send_mail with appropriate arguments');

my $rows = $dbh->selectall_arrayref("SELECT sent_time FROM Messages", { Slice => {} });
my $sent_time = $rows->[0]->{sent_time};
#print "$sent_time\n";
#print "$start_time\n";
is($sent_time, $start_time,'Message marked as sent');
#ok($sent_time lt from_epoch(time) && $sent_time gt $start_time);
$dbh->disconnect();
