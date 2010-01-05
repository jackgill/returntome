#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 8;
use Test::MockObject;
use Test::MockModule;
use DBI;
use R2M::Parse;
use R2M::Conf;

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
#Mock R2M::Mail
my $R2M_Mail = Test::MockModule->new('R2M::Mail');
$R2M_Mail->mock(
    get_mail => sub {
        return ();
        }
);
my @sent_args;
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
$conf->{general}->{cwd} = $ENV{PWD};

my $dbh = connect_db($conf);

#Clear DB
$dbh->do('TRUNCATE TABLE Messages');
$dbh->do('TRUNCATE TABLE Archive');

#insert test messages
my $Messages = $dbh->prepare("INSERT INTO Messages VALUES(NULL, 'foo\@bar.com', ?, ? ,?)");
my $RawMail = $dbh->prepare("INSERT INTO RawMail VALUES(?,AES_ENCRYPT('this is some raw mail','foo'))");
my $ParsedMail = $dbh->prepare("INSERT INTO ParsedMail VALUES(?,AES_ENCRYPT('this is some parsed mail','foo'))");
my $Archive = $dbh->prepare("INSERT INTO Archive VALUES(?,'foo\@bar.com',NOW(),NULL,?,AES_ENCRYPT('this is some raw mail','foo'),AES_ENCRYPT('this is some parsed mail','foo'))");

$Messages->execute( from_epoch(time - 24 * 60 * 60 - 60), undef, undef);
$Messages->execute( from_epoch(time - 300)              , undef, undef);
$Messages->execute( from_epoch(time - 500)              , undef, from_epoch(time - 60));
$Messages->execute( from_epoch(time - 24 * 60 * 60 + 60), undef, from_epoch(time - 90));

for (my $i = 1; $i < 5; $i++) {
    $RawMail->execute($i);
    $ParsedMail->execute($i);
}

$Archive->execute(6, from_epoch(time - 7 *24 * 60 * 60 - 60) );
$Archive->execute(7, from_epoch(time - 7 *24 * 60 * 60 + 60) );

archive($conf, $dbh);

my $message_ref = $dbh->selectall_arrayref("SELECT uid FROM Messages");
my @message_rows = @{ $message_ref };
my @message_uids = qw(1 2);
is(scalar @message_rows, 2,"Correct number of messages in Messages");
for (my $i = 0; $i < 2; $i++) {
    ok($message_rows[$i]->[0] == $message_uids[$i],"Message $message_uids[$i-1] is in Messages");
}


my $archive_ref = $dbh->selectall_arrayref("SELECT uid FROM Archive");
my @archive_rows = @{ $archive_ref };
my @archive_uids = qw(3 4 7);
is(scalar @archive_rows, 3,"Correct number of messages in Archive");
for (my $i = 0; $i < 3; $i++) {
    ok($archive_rows[$i]->[0] == $archive_uids[$i],"Message $archive_uids[$i] is in Archive");
}

$dbh->disconnect();

