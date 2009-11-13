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
#&testGetSchemas;
#&testMakeTables;
#&testClearTables;
#&testPutMessages('ParsedMessages');
#&testGetMessageByUID;
#&testDeleteMessageByUID;
#&testGetMessagesByTime;
#&testDeleteMessagesByTime;
#&testGetUID;
&testGetTable('ParsedMessages');
#&testShowTables();

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

sub testPutMessages {
    my $table_name = shift;
    my @messages = &createMessages(2,2);
    #my $key = &getKey;
    #&putMessages($table_name,&encryptMessages($key,@messages));
    &putParsedMessages($table_name,@messages);
}

sub testGetMessageByUID {
    my %message = &getMessageByUID('SentMessages','000000000');
    print Dumper(%message);
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

