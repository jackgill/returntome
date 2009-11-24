#!/usr/bin/perl

use 5.010;
use strict;
use warnings;

use Test::More tests => 5;

#TODO: deal with parser errors in log?
#TODO: right now this only checks that the instructions are parsed. Check for error messages, ads, correctly re-assembled messages?
BEGIN {
    use_ok('Mod::ParseMail');
}

Log::Log4perl::init('conf/log4perl_test.conf');

my @tests= qw(non-mime multipart-alternative multipart-mixed multipart-mixed-encoded);

my $uid = 0;
for my $test (@tests) {
    open(my $in,'<',"t/mail/$test") or BAIL_OUT("Couldn't open t/mail/$test: $!\n");
    my @slurp = <$in>; 
    my $mail = join('', @slurp);
    close $in;

    my $message = parseMail($mail,'return.to.me.test@gmail.com', sprintf("%09d",$uid));
    is( $message->{return_time}, '2009-11-22 00:00:00',$test);

    $uid++;
}
