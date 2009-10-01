#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use Mod::DB;
use Mod::Test;
use Mod::TieHandle;
use Mod::Conf;

#initialize the logger:
Log::Log4perl::init('conf/log4perl_test.conf');
my $logger = Log::Log4perl->get_logger();

#Send STDERR to logger:
tie(*STDERR, 'Mod::TieHandle');

#Get config:
my %conf = %{ &getConf("conf/test.conf") };

&Mod::DB::connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});

&testGetTable;

&Mod::DB::disconnect;

sub testGetTable {
    my $table = &getTable('ParsedMessages');
    print Dumper($table);
}

sub testPut {
my @put_messages = &createMessages(2,2);
&putMessages('SentMessages',@put_messages);
#my @get_messages = &getMessages('table',); #FIXME

#TODO: compare @put_messages and @get_messages
}
