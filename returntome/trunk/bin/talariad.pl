#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use lib 'lib';

use Proc::Daemon;
use DBI;
use R2M::TieSTDERR;
use R2M::Conf;
use R2M::Crypt;
use R2M::Talaria;

#Determine mode:
die "Usage: $0 (incoming|outgoing|archive)\n" unless (scalar @ARGV == 1);

my $mode = $ARGV[0];
my $subroutine_ref;

given($mode) {
    when('incoming') {
	$subroutine_ref = \&incoming;
    }
    when('outgoing') {
	$subroutine_ref = \&outgoing;
    }
    when('archive') {
        $subroutine_ref = \&archive;
    }
    default {
	die "Invalid mode: $mode\n";
    }
}

#get the CWD before we daemonize
my $cwd = $ENV{PWD};

#conf variables:
my $conf_file  = "$cwd/conf/talaria.conf";
#TODO: these should be defined in conf file
my $key_digest = "$cwd/conf/key_digest.conf";
my $pid_file   = "$cwd/talariad_$mode.pid";
my $log_file   = "$cwd/log/talariad_$mode.log";

#Only one instance at a time, please
if (-e $pid_file) {
    die "talariad is already running.\n" ;
}

#Get encryption key for conf file
my $key = get_checked_key($key_digest);

#Configuration options represented as Config::Tiny object
my $conf = read_conf($conf_file, $key);

#daemonize
Proc::Daemon::Init();

#initialize the logger
my $logger_conf = <<"END_LOGGER_CONF";
log4perl.rootLogger=INFO, LOG

log4perl.appender.LOG=Log::Log4perl::Appender::File
log4perl.appender.LOG.filename=$log_file
log4perl.appender.LOG.mode=write
log4perl.appender.LOG.layout=PatternLayout
log4perl.appender.LOG.layout.ConversionPattern=[\%d{DATE}] \%C: \%p: \%m \%n
END_LOGGER_CONF

Log::Log4perl::init( \$logger_conf );

#Get logger:
my $logger = Log::Log4perl->get_logger();

#Start logging:
$logger->info("Started talariad.pl, PID: $$");

#Send output streams to logger:
tie(*STDERR, 'R2M::TieSTDERR');
tie(*STDOUT, 'R2M::TieSTDERR');

#create PID file:
if ( open(my $out, '>', $pid_file) ) {
    print $out "$$\n";
    close $out;
}
else {
    $logger->error("Couldn't create PID file: $!");
}


my $working = 0; #flag indicating if daemon is executing subroutine
my $TERM    = 0; #flag indicating if SIGTERM has been received
my $HUP     = 0; #flag indicating if SIGHUP has been received

#SIGTERM commands a graceful shutdown
$SIG{TERM} = sub {
    if ($working) { #daemon is currently executing subroutine
        $TERM = 1;  #set flag, daemon will exit when subroutine is done executing
    }
    else { #daemon is sleeping
        quit();
    }
};

#SIGHUP commands a re-read of the conf file
$SIG{HUP}  = sub {
    if ($working) {
        $HUP = 1;
    }
    else {
        $conf = read_conf($conf_file, $key);
    }
};

#daemon should never receive SIGINT, but just to be safe...
$SIG{INT} = 'IGNORE';

#DB handle is global so that quit() can disconnect it:
my $dbh;

#Main loop:
while (1) {
    #Set flag to indicate subroutine processing
    $working = 1;

    #Connect to DB
    $dbh = connect_db($conf);

    if ($dbh) {

        #Execute subroutine
        eval {
            &$subroutine_ref($conf, $dbh);
        };

        #Log any errors
        if ($@) {
            $logger->error($@);
        }
    }
    else {
        $logger->error("Could not connect to DB: " . $DBI::errstr);
    }

    #clear flag to indicate subroutine processing
    $working = 0;

    #check to see if SIGTERM was received while subroutine was processing
    if ($TERM) {
        quit();
    }

    #check to see if SIGHUP was received while subroutine was processing
    if ($HUP) {
        $conf = read_conf($conf_file, $key);
        $HUP = 0;
    }

    #wait
    sleep $conf->{general}->{"interval_$mode"};
}

sub quit {
    #Log the fact that we're quiting
    $logger->info('Caught SIGTERM, exiting.');

    #Disconnect from DB:
    $dbh->disconnect() if $dbh;

    #Remove PID file
    unlink($pid_file);

    exit 0;
}

__END__

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

=item *

DBI

=item *

R2M::TieSTDERR

=item *

R2M::Conf

=item *

R2M::Talaria

=back
