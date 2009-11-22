#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 14;
use DateTime;

BEGIN {
    use_ok('Mod::ParseMail');
}

my @tests;
my ($instructions, $time, $expected, $got, $dt);

$instructions = 'Aug 19 2009';
$expected = '2009-08-19 00:00:00';
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

$instructions = 'Aug 19, 2009';
$expected = '2009-08-19 00:00:00';
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

$instructions = '19 August 2009';
$expected = '2009-08-19 00:00:00';
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

$instructions = '8/19/09';
$expected = '2009-08-19 00:00:00';
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

$instructions = 'tomorrow';
$expected = fromEpoch(time + 24 * 60 *60);
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

$instructions = 'today 11:59pm';
$dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
$expected = $dt->ymd . ' 23:59:00';
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

$instructions = 'today 3pm';
$dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
$expected = $dt->ymd . ' 15:00:00';
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

$instructions = 'today 8:00';
$dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
$expected = $dt->ymd . ' 08:00:00';
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

$instructions = '5 am';
$dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
$expected = $dt->ymd . ' 05:00:00';
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

$instructions = 'next week';
$dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
#$expected = fromEpoch(time + 7 * 24 * 60 * 60);
$dt->add(days => 7);
$expected = $dt->ymd . ' 00:00:00';
$got = parseInstructions($instructions);
push @tests, {
    instructions => $instructions,
    expected => $expected,
    got => $got,
};

for my $test (@tests) {
    is($test->{got}, $test->{expected}, 'Instructions: ' . $test->{instructions});
}

TODO: {
    local $TODO = 'These instructions are known to fail.';
    @tests = ();

    $instructions = '8-19-09';
    $expected = '2009-08-19 00:00:00';
    $got = parseInstructions($instructions);
    push @tests, {
        instructions => $instructions,
        expected => $expected,
        got => $got,
    };

    $instructions = '5';
    $dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
    $expected = $dt->ymd . ' 05:00:00';
    $got = parseInstructions($instructions);
    push @tests, {
        instructions => $instructions,
        expected => $expected,
        got => $got,
    };

    $instructions = 'today 5';
    $dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
    $expected = $dt->ymd . ' 05:00:00';
    $got = parseInstructions($instructions);
    push @tests, {
        instructions => $instructions,
        expected => $expected,
        got => $got,
    };

    for my $test (@tests) {
        is($test->{got}, $test->{expected}, 'Instructions: ' . $test->{instructions});
    }
}
