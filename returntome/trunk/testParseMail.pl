#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::ParseMail;
use Mod::Test;
use Data::Dumper::Simple;

Log::Log4perl::init('log4perl_test.conf');
my %message = (uid => 'dummy',
	       from => 'return.to.me.receive@gmail.com',
	       subject => 'subject',
	       body => "Mod: 7-14-09 8:00 am \r\n body of message",
    );
my @mail = &createMail(\%message);
#print $mail[0];
my ($ref, $instructions) = &parseMail($mail[0]);
print "Instructions: $instructions\n";
print Dumper(%$ref);
