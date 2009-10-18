#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::GetMail;
use Mod::Conf;
use Mod::TieHandle;

use Log::Log4perl;

Log::Log4perl::init('conf/log4perl_test.conf');
tie(*STDERR, 'Mod::TieHandle');
my %conf = %{&getConf("conf/test.conf")};
my $user = $ARGV[0];
die "Usage: $0 email address\n" unless $user;
my @messages = &getMail($conf{imap_server},$user,$conf{imap_pass},0);
die "No messages\n" unless (@messages);
for (@messages) {
    print;
}
