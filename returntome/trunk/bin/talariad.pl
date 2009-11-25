#!/usr/bin/perl

#pragmas
use 5.010;
use strict;
use warnings;

use Proc::Daemon;

use Mod::TieSTDERR;
use Mod::TieSTDOUT;
use Mod::Conf;
use Mod::Crypt;
use Mod::Talaria;

#Determine mode:
die "Usage: $0 (incoming|outgoing|archive)\n" unless (scalar @ARGV == 1);

my $mode = $ARGV[0];
my $subroutine_ref;

given($mode) {
    when('incoming') {
	$subroutine_ref = \&checkIncoming;

        #Create temporary directory for MIME parser
        my $tmp_dir = '/tmp/mimedump/';
        if ( !(-d $tmp_dir) ) {
            mkdir($tmp_dir, 0755) or die "Couldn't create $tmp_dir: $!";
        }
    }
    when('outgoing') {
	$subroutine_ref = \&checkOutgoing;
    }
    when('archive') {
        $subroutine_ref = \&archiveMessages;
    }
    default {
	die "Invalid mode: $mode\n";
    }
}

#get the CWD before we daemonize:
my $cwd = $ENV{PWD};

#Various conf variables:
my $conf_file  = "$cwd/conf/talaria.conf";
my $key_digest = "$cwd/conf/key_digest.conf";
my $pid_file   = "$cwd/talariad_$mode.pid";

#Only one instance at a time, please:
if (-e $pid_file) {
    die "talariad is already running.\n" ;
}

#Get encryption key for conf file:
my $key = getCheckedKey($key_digest);

#daemonize:
Proc::Daemon::Init();

#create PID file:
open(my $out, '>', $pid_file);
print $out "$$\n";
close $out;

#initialize the logger:
my $logger_conf = <<"END_LOGGER_CONF";
log4perl.rootLogger=INFO, LOG

log4perl.appender.LOG=Log::Log4perl::Appender::File
log4perl.appender.LOG.filename=$cwd/log/talariad_$mode.log
log4perl.appender.LOG.mode=write
log4perl.appender.LOG.layout=PatternLayout
log4perl.appender.LOG.layout.ConversionPattern=[\%d{DATE}] \%C: \%p: \%m \%n

END_LOGGER_CONF

Log::Log4perl::init( \$logger_conf );

#Get logger:
my $logger = Log::Log4perl->get_logger();

#Start logging:
$logger->info("PID: $$");
$logger->info('Talaria daemon started.');

#Send output streams to logger:
tie(*STDERR, 'Mod::TieSTDERR');
tie(*STDOUT, 'Mod::TieSTDOUT');

#Read conf file:
my %conf = %{ getConf($conf_file, $key) };

#Set conf vars:
setConf(\%conf);

#Connect to DB:
connectDB();

#Set up signal handlers:
$SIG{HUP}  = sub { quit('SIGHUP' , $pid_file) };
$SIG{QUIT} = sub { quit('SIGQUIT', $pid_file) };
$SIG{TERM} = sub { quit('SIGTERM', $pid_file) };
$SIG{INT}  = sub { quit('SIGINT' , $pid_file) };

#Main loop:
while (1) {
    #Call subroutine
    eval {
	&{ $subroutine_ref };
    };
    if ($@) {
        $logger->error($@);
    }

    #Wait
    sleep $conf{interval};
}

=head1 NAME

talariad.pl -- a daemon which serves as the Talaria main program.

=head1 USAGE

C<bin/talariad.pl (incoming|outgoing)>

=head1 DESCRIPTION

This is a daemon.

=head1 DEPENDENCIES

=over

=item *

Proc::Daemon

=back
