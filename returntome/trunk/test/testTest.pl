#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use Mod::Test;
use Mod::Conf;
use Mod::DB;

Log::Log4perl::init('conf/log4perl_test.conf');

my %conf = %{ &getConf("conf/test.conf") };
&connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});

&testCreateMessages;
#&testCreateMail;
&disconnect;

sub testCreateMessages {
    my @messages = &createMessages(2,2);
    for (@messages) {
	my %message = %{$_};
	print Dumper(%message);
    }
}

sub testCreateMail {
   my @mail = &createMail(1,2);
    for (@mail) {
	print;
    }
}
