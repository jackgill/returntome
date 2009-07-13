#!/usr/bin/perl

use strict;
use warnings;

use DBI;

use Data::Dumper;

use CGI qw(:standard *table); #function based interface to CGI module, start_table and end_table tags
use CGI::Carp qw(fatalsToBrowser); #send errors to browser as well as server error log


my $database_name = 'ReturnToMe';
my $table_name = 'Messages';

#Set up the display page:
print header, start_html('Display database'), h3("Admin view");

#Connect to the database:
my $sth; #statement handle
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

#set up the table:
print start_table({-border=>1});
print caption("$database_name:$table_name");
print Tr( th( \@col_names ) );

#Now get the entire table:
$sth = $dbh->prepare("SELECT * FROM $table_name") or die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
while (my $row = $sth->fetchrow_arrayref()) {
    print Tr( td( $row ) );    
}

#End the table:
$dbh->disconnect;
print end_table;
print end_html( );

