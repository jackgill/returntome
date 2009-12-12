#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 8;
use DBI;

use R2M::Test;
use R2M::ParseMail;

#Populate DB
my $dbh = DBI->connect(
    "DBI:mysql:database=ReturnToMe",
    'root',
    'foo',
    {PrintError => 0, RaiseError => 1}
);

$dbh->do('TRUNCATE TABLE Messages');
$dbh->do('TRUNCATE TABLE Archive');

#insert test messages
my $Messages = $dbh->prepare("INSERT INTO Messages VALUES(NULL, 'foo\@bar.com', ?, ? ,?)");
my $RawMail = $dbh->prepare("INSERT INTO RawMail VALUES(?,AES_ENCRYPT('this is some raw mail','foo'))");
my $ParsedMail = $dbh->prepare("INSERT INTO ParsedMail VALUES(?,AES_ENCRYPT('this is some parsed mail','foo'))");
my $Archive = $dbh->prepare("INSERT INTO Archive VALUES(?,'foo\@bar.com',NOW(),NULL,?,AES_ENCRYPT('this is some raw mail','foo'),AES_ENCRYPT('this is some parsed mail','foo'))");

$Messages->execute(fromEpoch(time - 24 * 60 * 60 - 60), undef,undef);
$Messages->execute(fromEpoch(time - 300), undef,undef);
$Messages->execute(fromEpoch(time - 500), undef,fromEpoch(time - 60));
$Messages->execute(fromEpoch(time - 24 * 60 * 60 + 60), undef,fromEpoch(time - 90));

for (my $i = 1; $i < 5; $i++) {
    $RawMail->execute($i);
    $ParsedMail->execute($i);
}

$Archive->execute(6, fromEpoch(time - 7 *24 * 60 * 60 - 60) );
$Archive->execute(7, fromEpoch(time - 7 *24 * 60 * 60 + 60) );

#Start talaria
open(STDIN,'<t/password.txt') or BAIL_OUT("Couldn't open STDIN: $!");
system 'bin/talariad.pl archive';
close STDIN;

sleep 5;

#Stop talaria
open(my $in,'<','talariad_archive.pid') or die "Couldn't open talariad_archive.pid: $!\n";
my $pid_archive = <$in>;
close $in;

system "kill -s SIGINT $pid_archive";

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

