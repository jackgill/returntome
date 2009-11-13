#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::GetMail;
use Mod::Conf;

use Log::Log4perl;

Log::Log4perl::init('conf/log4perl_test.conf');
my %conf = %{&getConf("conf/test.conf")};
my @messages = &getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass},0);
die "No messages\n" unless (@messages);
for (@messages) {
    print;
}
