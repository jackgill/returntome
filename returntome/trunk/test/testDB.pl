#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use Mod::DB;
use Mod::Test;

#initialize the logger:
Log::Log4perl::init('conf/log4perl_test.conf');
my $logger = Log::Log4perl->get_logger();

#Send STDERR to logger:
tie(*STDERR, 'Mod::TieHandle');

#Get config:
my %conf = %{ &getConf("conf/test.conf") };

&DB::connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});
my @put_messages = &createMessages(2,2);
&putMessages('table',@messages);
my @get_messages = &getMessages('table',); #FIXME

#TODO: compare @put_messages and @get_messages

&DB::disconnect;

