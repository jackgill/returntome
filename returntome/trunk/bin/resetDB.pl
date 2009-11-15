#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use DBI;

use Mod::Conf;
use Mod::Crypt;

#Conf variables:
my $key_digest = 'conf/key.sha1_base64';
my $conf_file = "conf/daemon.conf";

#Get encryption key:
my $key = &getCheckedKey($key_digest);

#Read encrypted conf file:
my %conf = %{ &getConf($conf_file, $key) };

#Connect to DB:
my $dbh = DBI->connect("DBI:mysql:database=$conf{db_server}",$conf{db_user},$conf{db_pass},{PrintError => 0, RaiseError => 1});

#Define schemas:
my %schemas = (
    Messages => 
    "(" .
    "uid INTEGER(9) ZEROFILL NOT NULL AUTO_INCREMENT" . 
    ", " .
    "address VARCHAR(320) NULL" . 
    ", " .
    "received_time DATETIME" . 
    ", " .
    "return_time DATETIME" . 
    ", " .
    "sent_time DATETIME" . 
    ", " .	
    "PRIMARY KEY (uid)" .
    ")", 
    RawMail => 
    "(" .
    "uid INTEGER(9) ZEROFILL NOT NULL" 
    . ", " .
    "mail MEDIUMBLOB NOT NULL" . 
    ", " .
    "PRIMARY KEY (uid)" .
    ")",
    ParsedMail => 
    "(" .
    "uid INTEGER(9) ZEROFILL NOT NULL" . 
    ", " .
    "mail MEDIUMBLOB NOT NULL" . 
    ", " .
    "PRIMARY KEY (uid)" .
    ")",
    );

#Drop and re-create each table.
for my $table (keys %schemas) {
    $dbh->do("DROP TABLE IF EXISTS $table"); 
    $dbh->do("CREATE TABLE $table $schemas{$table}");

}

#Disconnect from DB:
$dbh->disconnect;
