#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 16;
use DateTime;

use_ok('R2M::Parse') or exit;

my @tests;
my ($expected, $dt);

build_test('Aug 19 2009'   , '2009-08-19 00:00:00');
build_test('Nov 22nd, 2009', '2009-11-22 00:00:00');
build_test('Aug 19, 2009'  , '2009-08-19 00:00:00');
build_test('19 August 2009', '2009-08-19 00:00:00');
build_test('8/19/09'       , '2009-08-19 00:00:00');
build_test('tomorrow'      , from_epoch(time + 24 * 60 *60));
build_test('today 11:59pm' , today() . ' 23:59:00');
build_test('today 3pm'     , today() . ' 15:00:00');
build_test('today 8:00'    , today() . ' 08:00:00');
build_test('1/1'           , '2011-01-01 00:00:00');
build_test('2/1'           , '2010-02-01 00:00:00');
build_test('8-19-09'       , '2009-08-19 00:00:00');

$dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
$dt->add(days => 7);
build_test('next week', from_epoch(time + 7 * 24 * 60 * 60));

for my $test (@tests) {
    is($test->{got}, $test->{expected}, 'Instructions: ' . $test->{instructions});
}

TODO: {
    local $TODO = 'These instructions are known to fail.';
    @tests = ();

    build_test('5 am'          , today() . ' 05:00:00');
    build_test('today 5', today() . ' 05:00:00');

    for my $test (@tests) {
        is($test->{got}, $test->{expected}, 'Instructions: ' . $test->{instructions});
    }
}

sub build_test {
    my ($instructions, $expected) = @_;
    my $got = parseInstructions($instructions);
    push @tests, {
        instructions => $instructions,
        expected => $expected,
        got => $got,
    };
}

sub today {
    $dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
    return  $dt->ymd;
}
