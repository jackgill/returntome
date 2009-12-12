#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 2;
use R2M::Crypt;

use_ok('R2M::Conf') or exit;

my $conf_file_text =<<'EOF';
[section]
foo=bar
EOF

my $conf_file = 'test.conf';
my $key = 'foo';
open(my $out, '>', $conf_file) or die "Couldn't open $conf_file: $!\n";
print $out encrypt($key, $conf_file_text);
close $out;

my $conf = read_conf($conf_file, $key);
is($conf->{section}->{foo},'bar','Retrieved conf value');
unlink $conf_file;
