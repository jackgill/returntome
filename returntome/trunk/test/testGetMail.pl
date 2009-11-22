#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::GetMail;
use Mod::Conf;

use Log::Log4perl;

Log::Log4perl::init('conf/log4perl_test.conf');

my %conf = %{ getConf('conf/test.conf', 'foo') };

my @messages = &getMail( @conf{'imap_server', 'imap_user', 'imap_pass'} );

die "No messages\n" unless (@messages);

for my $message (@messages) {
    print $message;
    print "\n",'-' x 78,"\n";
}
