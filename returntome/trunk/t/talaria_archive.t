#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 7;
use DBI;

use Mod::Test;
use Mod::ParseMail;

BEGIN {
    use_ok('Mod::Talaria');
}

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
$dbh->do("INSERT INTO Messages VALUES(NULL,'foo\@bar.com',NOW(),NULL, NULL)");
$dbh->do("INSERT INTO RawMail VALUES(1,'this is some raw mail')");
$dbh->do("INSERT INTO ParsedMail VALUES(1,'this is some parsed mail')");

$dbh->do("INSERT INTO Messages VALUES(NULL,'foo\@bar.com',NOW(),NULL, NULL)");
$dbh->do("INSERT INTO RawMail VALUES(2,'this is some raw mail')");
$dbh->do("INSERT INTO ParsedMail VALUES(2,'this is some parsed mail')");

$dbh->do("INSERT INTO Messages VALUES(NULL,'foo\@bar.com',NOW(),NULL, '" . fromEpoch(time - 60) . "')");
$dbh->do("INSERT INTO RawMail VALUES(3,'this is some raw mail')");
$dbh->do("INSERT INTO ParsedMail VALUES(3,'this is some parsed mail')");

$dbh->do("INSERT INTO Messages VALUES(NULL,'foo\@bar.com',NOW(),NULL, '" . fromEpoch(time - 60) . "')");
$dbh->do("INSERT INTO RawMail VALUES(4,'this is some raw mail')");
$dbh->do("INSERT INTO ParsedMail VALUES(4,'this is some parsed mail')");

$dbh->do("INSERT INTO Archive VALUES(5,'foo\@bar.com',NOW(),NULL,'" . fromEpoch(time - 7 *24 * 60 * 60 - 60) . "','this is some raw mail','this is some parsed mail')");
$dbh->do("INSERT INTO Archive VALUES(6,'foo\@bar.com',NOW(),NULL,'" . fromEpoch(time - 7 *24 * 60 * 60 - 60) . "','this is some raw mail','this is some parsed mail')");

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

my $uids_ref = $dbh->selectall_arrayref("SELECT uid FROM Messages");
my $i = 1;
my @rows = @{ $uids_ref };
is(scalar @rows, 2,"Correct number of messages in Messages");
for my $row (@rows) {
   my $uid = $row->[0];
   ok($uid == $i,"Message $uid still in Messages");
   $i++;
}

$uids_ref = $dbh->selectall_arrayref("SELECT uid FROM Archive");
@rows = @{ $uids_ref };
is(scalar @rows, 2,"Correct number of messages in Archive");
for my $row (@rows) {
   my $uid = $row->[0];
   ok($uid == $i,"Message $uid in Archive");
   $i++
}
$dbh->disconnect();

