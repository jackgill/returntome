#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 2;
use DateTime;

use_ok('R2M::Parse');
my $epoch = time;
my $dt = DateTime->from_epoch( epoch => $epoch , time_zone => 'America/Denver');
my $exp_time =  $dt->ymd . " " . $dt->hms;
my $got_time = from_epoch($epoch);
is($got_time, $exp_time,'Current time');
