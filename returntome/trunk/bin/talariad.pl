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
            mkdir($tmp_dir, 0700) or die "Couldn't create $tmp_dir: $!";
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

#conf variables:
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
my %conf = %{ readConf($conf_file, $key) };

#Connect to DB:
connectDB();

my $working = 0; #flag indicating if subroutine is currently processing
my $TERM = 0; #flag indicating if SIGTERM has been received

#SIGTERM commands a graceful shutdown
$SIG{TERM} = sub {
    if ($working) { #subroutine is currently processing
        $TERM = 1; #set flag, daemon will exit when subroutine finishes
    } else { #daemon is sleeping
        quit();
    }
};

my $HUP = 0; #flag indicating if SIGHUP has been received

#SIGHUP commands a re-read of the conf file
$SIG{HUP}  = sub {
    if ($working) {
        $HUP = 1;
    }
    else {
        %conf = %{ readConf($conf_file, $key) };
     }
};

#Main loop:
while (1) {
    #Set flag to indicate subroutine processing
    $working = 1;

    #Execute subroutine
    eval {
	&{ $subroutine_ref };
    };
    #Log any errors
    if ($@) {
        $logger->error($@);
    }

    #clear flag to indicate subroutine processing
    $working = 0;

    #check to see if SIGTERM was received while subroutine was processing
    if ($TERM) {
        quit();
    }
    if ($HUP) {
        readConf($conf_file, $key);
    }

    #wait
    sleep $conf{interval};
}

sub quit {
    #Log the fact that we're quiting
    $logger->info('Caught SIGTERM, exiting.');

    #Disconnect from DB:
    disconnectDB();

    #Remove PID file
    unlink($pid_file);

    #Exit
    exit 0;
}

sub readConf {
    my ($conf_file, $key) = @_;

    my $conf = getConf($conf_file, $key);

    #Set conf vars:
    setConf($conf);

    return $conf;
}

=head1 NAME

talariad.pl -- a daemon which serves as the Talaria main program.

=head1 USAGE

C<bin/talariad.pl (incoming|outgoing|archive)>

=head1 DESCRIPTION

This daemon runs an infinite loop which executes a subroutine specified by the mode, then sleeps for a number of seconds given in the config file. The available modes are:

=over

=item *

B<incoming> - get messages from IMAP server, parse them, store them in the database.

=item *

B<outgoing> - retrieve messages from database, send them to SMTP server.

=item *

B<archive> - move sent messages from main tables to archive table, delete old archived messages.

=back

=head1 DEPENDENCIES

=over

=item *

Proc::Daemon

=back
