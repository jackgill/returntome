#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 5;
use Test::MockObject;
use Data::Dumper::Simple;

#TODO: deal with parser errors in log?
#TODO: right now this only checks that the instructions are parsed. Check for error messages, ads, correctly re-assembled messages?
#TODO: Currently tests are failing because return dates in the past now return undef
$INC{'Log/Log4perl.pm'} = 1;
my $logger = Test::MockObject->new();
$logger->fake_module(
    'Log::Log4perl',
    get_logger => sub {$logger},
    );
$logger->mock('error',
            sub {
                my ($self, $text) = @_;
                print "\$logger->error($text)\n";
            }
        );

use_ok('R2M::Parse') or exit;


my @tests= qw(non-mime multipart-alternative multipart-mixed multipart-mixed-encoded);

my $uid = 0;
for my $test (@tests) {
    open(my $in,'<',"t/mail/$test") or BAIL_OUT("Couldn't open t/mail/$test: $!\n");
    my @slurp = <$in>; 
    my $mail = join('', @slurp);
    close $in;

    my $message = parse_mail($mail,'return.to.me.test@gmail.com', sprintf("%09d",$uid));
    #print Dumper($message);
    is( $message->{return_time}, '2009-11-22 00:00:00',$test);

    $uid++;
}
