#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;
use DateTime;

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
&testResetDB;
#&testCreateEntry;
#&testStoreMail;
#&testRetrieveMail;
#&testDeleteRow;
&populateDB;
#&testGetMessagesToReturn;
&testMarkAsSent;

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

sub testDeleteRow {
    &deleteRow('RawMail','2');
}

sub populateDB {
    my @messages = &createMessages(2,2,'foo@bar.com');
    for my $message (@messages) {
	my $mail = $message->{mail};
	my $return_time = $message->{return_time};
	my $uid = &createEntry('foo@bar.com',$return_time);
	&storeMail('ParsedMail',$uid,$mail,'foo');
    }
}

sub testGetMessagesToReturn {
    my @messages = &getMessagesToReturn('foo');
    for (@messages) {
	print Dumper($_);
    }
}

sub testMarkAsSent {
    &markAsSent('1');
}
