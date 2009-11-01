#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use Mod::DB;
use Mod::Test;
use Mod::TieHandle;
use Mod::Conf;
use Mod::Crypt;

#initialize the logger:
Log::Log4perl::init('conf/log4perl_test.conf');
my $logger = Log::Log4perl->get_logger();

#Send STDERR to logger:
tie(*STDERR, 'Mod::TieHandle');

#Get config:
my %conf = %{ &getConf("conf/test.conf") };

#Connect to the DB:
&Mod::DB::connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});

#Run tests:
#&testPutMessages('UnparsedMessages');
#&testGetSchemas;
#&testMakeTables;
&testPutCryptMessages('ParsedMessages');
#&testPutMessages('ParsedMessages');
#&getUID;
#&testClearTables;
#&testGetMessages;
&testGetMessagesToSend;
#&testPurgeSentMessages;
#&testGetUID;
#&testGetTable('ParsedMessages');
&testShowTables();
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

sub testMakeTables {
    &makeTables;
}

sub testClearTables {
    &clearTables;
}

sub testPutCryptMessages {
    my $table_name = shift;
    my @messages = &createMessages(2,2);
    my $key = &getKey;
    &putMessages($table_name,&encryptMessages($key,@messages));
}

sub testPutMessages {
    my $table_name = shift;
    my @messages = &createMessages(2,2);
    &putMessages($table_name,@messages);
}

sub testGetMessages {
    my @messages = &getMessages('UnparsedMessages','000000000','000000001');
    print Dumper(@messages);
}

sub testGetMessagesToSend {
    my @messages = &getMessagesToSend(time);
    print Dumper(@messages);
}

sub testPurgeSentMessages {
    &purgeSentMessages(time);
}

sub testGetUID {
    for (my $i = 0; $i < 5; $i++) {
	print &getUID,"\n";
    }
}

sub testGetTable {
    my $table_name = shift;
    my $table = &getTable($table_name);
    print Dumper($table);
}

sub testShowTables {
    &showTables(&getKey);
}

