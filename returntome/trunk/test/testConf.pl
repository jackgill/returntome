#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;
use Mod::Conf;

my %conf = %{ &getConf("conf/talaria.conf") };
print Dumper(%conf);
