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
$sth = $dbh->prepare("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns where TABLE_NAME = '$table_name'") or die "Couldn't prepare statement: " . $dbh->errstr; #this returns a table with one column. Each row is the name of a column in $table_name
$sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
my @col_refs = @{ $sth->fetchall_arrayref }; #this is an array of references to arrays
my @col_names; #this will hold the names of the columns
for my $col_ref (@col_refs) {
    my @row = @$col_ref; #get the array which is a row in the schema table
    my $col_name = $row[0]; #get the first (and only) column in the row
    push @col_names, $col_name;
}
#print Dumper(@col_names);
#print the column names:
my $format = "%-20s | " x @col_names;
printf $format,@col_names;
print "\n","-" x (23*@col_names),"\n";

#Now get the entire table:
$sth = $dbh->prepare("SELECT * FROM $table_name") or die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
my @row;
while (@row = $sth->fetchrow_array()) {
    printf $format,@row;
    print "\n";
}
$sth->finish;
$dbh->disconnect;



