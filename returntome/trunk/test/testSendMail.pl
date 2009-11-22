#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Log::Log4perl;

use Mod::SendMail;
use Mod::Conf;
use Mod::Test;

Log::Log4perl::init('conf/log4perl_test.conf');

my %conf = %{ getConf('conf/test.conf','foo') };
my $to = 'return.to.me.receive@gmail.com';

my @messages = &createMessages(2, 2, $to);

sendMessages(@conf{'smtp_server', 'smtp_user' , 'smtp_pass'}, @messages);

print "Sent 2 messages to $to\n";
