#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 5;
use Test::MockObject;
use Test::MockModule;
use Test::Differences;
use Email::Simple;

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
#Mock R2M::Ad
my $R2M_Ad = Test::MockModule->new('R2M::Ad');
$R2M_Ad->mock(
    getPlainAd => sub {
        return 'This is a plain text ad.';
    }
);
$R2M_Ad->mock(
    getHTMLAd => sub{
        return 'This is a html ad.';
    }
);
use_ok('R2M::Parse') or exit;

my @tests= glob 't/mail/*';

my $uid = 0;
for my $test (@tests) {
    open(my $in, '<', "$test") or die "Couldn't open $test: $!\n";
    my $raw_mail = do {
        local $/;
        <$in>;
    };
    close $in;

    my $got_message = parse_mail($raw_mail,'return.to.me.test@gmail.com', sprintf("%09d",$uid));


    is($got_message->{return_time}, '2010-06-06 00:00:00', "$test -- return_time");
    is($got_message->{address}    , 'address@domain.tld', "$test -- address");
    is($got_message->{uid}        ,  sprintf("%09d",$uid), "$test -- uid");
    eq_or_diff($got_message->{mail}, build_parsed($raw_mail), "$test -- mail");

    $uid++;
    die;
}

use Email::Simple;
sub build_parsed {
    my $raw_mail = shift;
    my $mail = Email::Simple->new($raw_mail);
    my $parsed_mail = "From: return.to.me.test\@gmail.com\n";
    if ($raw_mail =~ /^From:\s(.+?)$/xms) {
        $parsed_mail .= "To: $1\n";
    }
    else {
        die "Couldn't find To:\n";
    }
    my @header_names = ('Subject','MIME-Version','Content-Type','Content-Transfer-Encoding');
    for my $header_name (@header_names) {
        my $header_value = $mail->header($header_name);
        #if ($raw_mail =~ /^($header_name:\s.+)$/xms) {
        #    $parsed_mail .= "$1\n";
        #}
        if ($header_value) {
            $parsed_mail .= "$header_name: $header_value\n";
        }
    }
    $parsed_mail .= "\n\n";

    #my @tokens = split(/^\n$/xms,$raw_mail);
    #shift @tokens;
    #$parsed_mail .= join("\n",@tokens);
    $parsed_mail .= $mail->body;
    return $parsed_mail;
}
