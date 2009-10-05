#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::DB;
use Mod::Conf;

Log::Log4perl::init('conf/log4perl_test.conf');

my %conf = %{ &getConf("conf/test.conf") };
&connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});
&printUID;
&disconnect;
sub printUID {
    for (my $i = 0; $i <5; $i++) {
	print &getUID,"\n";
    }
}
