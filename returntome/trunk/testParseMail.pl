#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::ParseMail;
use Data::Dumper::Simple;

Log::Log4perl::init('conf/log4perl_test.conf');

#Read in the mail:
open(IN,"<mail.log") or die "Couldn't open mail";
my @lines = <IN>;
close IN;
my $raw_message = join '', @lines;
my %message = %{ &parseMail($raw_message)};
my $return_date = $message{'return_time'};
if ($return_date) {
    print "Return date: ",&fromEpoch($return_date),"\n";
} else {
    print "Return date not found, see log for details.\n";
}
print "Message: ",Dumper(%message);
