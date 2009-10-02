#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;
use Mod::Conf;

&testGetCipherConf;

sub testGetConf {
    my %conf = %{ &getConf("conf/talaria.conf") };
    print Dumper(%conf);
}

sub testGetCipherConf {
    my %conf = %{ &getCipherConf("conf/talaria.conf.crypt") };
    die "Failed to decrypt conf file.\n" unless (%conf);
    print Dumper(%conf);
}
