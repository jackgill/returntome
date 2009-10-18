#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::SendMail;
use Mod::Conf;
use Mod::TieHandle;
use Mod::Test;
use Log::Log4perl;
use Mod::ParseMail;

Log::Log4perl::init('conf/log4perl_test.conf');
tie(*STDERR, 'Mod::TieHandle');

my %conf = %{&getConf("conf/test.conf")};
my @messages = &createMessages(2,2);
for (@messages) {
	my %message = %$_;
	$message{address} = &getHeader($message{mail},'From');
	$_ = \%message;
    }
&sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},@messages);
print "Sent 2 messages to return.to.me.test\@gmail.com\n";
