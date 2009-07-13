#!/usr/bin/perl

use strict;
use warnings;

use DBI;


my $dbh = DBI->connect('DBI:mysql:database=Roster;host=localhost','root','foo') or die "Couldn't connect to database: " . DBI->errstr;
my $sth = $dbh->prepare('SELECT * FROM RogueSquadron') or die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
my @data;
while (@data = $sth->fetchrow_array()) {
    my $firstName = $data[0];
    my $lastName = $data[1];
    my $rank = $data[2];
    print "\tname: $firstName $lastName rank: $rank\n";
}
$sth->finish;
$dbh->disconnect;

