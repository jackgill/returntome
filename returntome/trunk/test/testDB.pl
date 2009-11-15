#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use Mod::DB;
use Mod::Test;
use Mod::Conf;
use Mod::Crypt;

#initialize the logger:
Log::Log4perl::init('conf/log4perl_test.conf');
my $logger = Log::Log4perl->get_logger();


#Get config:
my %conf = %{ &getConf("conf/test.conf") };

#Connect to the DB:

&Mod::DB::connect(@conf{'db_server', 'db_user', 'db_pass'});

#Run tests:

#&testGetSchemas;
#&testResetDB;
#&testCreateEntry;
#&testStoreMail;
#&testRetrieveMail;

#&testDeleteMessageByUID;
#&testGetMessagesByTime;
#&testDeleteMessagesByTime;
#&testGetTable('ParsedMessages');

#Disconnect from the DB:
&Mod::DB::disconnect;

#############################################33
#Testing subroutines

sub testGetSchemas {
    my %schemas = %{ &getSchemas };
    my @tables = keys %schemas; 
    for (@tables) {
	print "Table: $_\n\tSchema: $schemas{$_}\n";
    }
}

sub testResetDB {
    &resetDB;
}

sub testCreateEntry {
    my $uid = &createEntry('foo@bar.com','2009-12-01 12:13:44');
    print "UID: $uid\n";
}

sub testStoreMail {
    &storeMail('RawMail',2,'this here is a mail message','foo');
}

sub testRetrieveMail {
    my $mail = &retrieveMail('RawMail',2,'foo');
    print "mail: $mail\n";
}

sub testDeleteMessageByUID {
    &deleteMessageByUID('ParsedMessages','000000000');
}

sub testGetMessagesByTime {
    my @messages = &getMessagesByTime('SentMessages',time);
    print Dumper(@messages);
}

sub testDeleteMessagesByTime {
    &deleteMessagesByTime('ParsedMessages',time);
}


sub testGetTable {
    my $table_name = shift;
    my $table = &getTable($table_name);
    print Dumper($table);
}


