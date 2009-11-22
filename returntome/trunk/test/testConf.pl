#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use Mod::Conf;

&testGetConf;

sub testGetConf {
    my %conf = %{ getConf('conf/test.conf','foo') };
    print Dumper(%conf);
}

