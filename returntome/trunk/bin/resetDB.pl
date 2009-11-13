#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Log::Log4perl;

use Mod::DB;
use Mod::TieHandle;
use Mod::Conf;
use Mod::Crypt;

#initialize the logger:
Log::Log4perl::init('conf/log4perl_cli.conf');
tie(*STDERR, 'Mod::TieHandle');

#Get encryption key:
my $key = &getCheckedKey('conf/key.sha1_base64');

#Read encrypted conf file:
my $conf_file = "conf/cli.conf";
my %conf = %{ &getCipherConf($conf_file, $key) };
die "Failed to decrypt $conf_file\n" unless %conf;

#Check that conf variables are defined:
my @conf_vars = qw(
db_server db_user db_pass 
);
for (@conf_vars) {
    unless (defined $conf{$_}) {
	die "Configuration error: $conf_file does not define $_\n";
    }
}

#Connect to DB:
&Mod::DB::connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});

&resetDB;

&Mod::DB::disconnect;

