#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Data::Dumper;

my $database_name = 'ReturnToMe';
my $table_name = 'Messages';
my $sth; #statement handle
#Connect to the database:
my $dbh = DBI->connect("DBI:mysql:database=$database_name;",'root','foo') or die "Couldn't connect to database: " . DBI->errstr;
#Get the column names:
$sth = $dbh->prepare("DELETE FROM $table_name") or die "Couldn't prepare statement: " . $dbh->errstr; #this returns a table with one column. Each row is the name of a column in $table_name
$sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
$dbh->disconnect;



