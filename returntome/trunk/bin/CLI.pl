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
our $key = &getKey;

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
#define commands:
my %commands = (
    showdb => sub {&showTables($key);},
    makedb => \&makeTables,
    cleardb => \&clearTables, 
    );

#CLI loop:
while (1) {
    print "Talaria>"; #display prompt
    chomp(my $line = <STDIN>); #read prompt
    if ($line eq 'exit'){ #this command must be outside the eval block so we can exit
	&Mod::DB::disconnect;
	exit 0;
    }
    elsif (!$line) {
	#An empty command does nothing
    }
    elsif ($commands{$line}) {
	eval { &{$commands{$line}} };
	print "Error executing command: $@" if $@;
    }
    else {
	print "Unrecognized command\n";
    }
}
