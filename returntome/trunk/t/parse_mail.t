#!/usr/bin/perl

use 5.010;
use strict;
use warnings;

use Test::More tests => 5;
use Data::Dumper::Simple;

#TODO: deal with parser errors in log?
#TODO: right now this only checks that the instructions are parsed. Check for error messages, ads, correctly re-assembled messages?

use_ok('R2M::ParseMail') or exit;

#TODO: mock logger
Log::Log4perl::init('conf/log4perl_test.conf');

my @tests= qw(non-mime multipart-alternative multipart-mixed multipart-mixed-encoded);

my $uid = 0;
for my $test (@tests) {
    open(my $in,'<',"t/mail/$test") or BAIL_OUT("Couldn't open t/mail/$test: $!\n");
    my @slurp = <$in>; 
    my $mail = join('', @slurp);
    close $in;

    my $message = parseMail($mail,'return.to.me.test@gmail.com', sprintf("%09d",$uid));
    print Dumper($message);
    is( $message->{return_time}, '2009-11-22 00:00:00',$test);

    $uid++;
}
