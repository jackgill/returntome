#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use lib '/home/jack/returntome/sandbox/Modules/';
use Mod::DB;

open;
my %message = (
    uid => '001',
    from => 'foo@bar.com',
    subject => 'subject line',
    body => 'this is the body',
    );
putMessage(\%message);
my %_message = %{ getMessage('001') };
close;
print Dumper(%_message);

