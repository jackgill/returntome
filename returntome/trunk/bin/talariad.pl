#!/usr/bin/perl

#pragmas
use 5.010;
use strict;
use warnings;

use Proc::Daemon;
use DBI;
use Config::Tiny;

use Mod::TieSTDERR;
use Mod::TieSTDOUT;
use Mod::Crypt;
use Mod::GetMail;
use Mod::SendMail;
use Mod::ParseMail;

#Determine mode:
die "Usage: $0 (incoming|outgoing|archive)\n" unless (scalar @ARGV == 1);

my $mode = $ARGV[0];
my $subroutine_ref;

given($mode) {
    when('incoming') {
	$subroutine_ref = \&checkIncoming;
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

#get the CWD before we daemonize
my $cwd = $ENV{PWD};

#conf variables:
my $conf_file  = "$cwd/conf/talaria.conf";
my $key_digest = "$cwd/conf/key_digest.conf";
my $pid_file   = "$cwd/talariad_$mode.pid";
my $log_file   = "$cwd/log/talariad_$mode.log";

#Only one instance at a time, please
if (-e $pid_file) {
    die "talariad is already running.\n" ;
}

#Get encryption key for conf file
my $key = getCheckedKey($key_digest);

#Configuration options represented as Config::Tiny object
my $conf;
read_conf();

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
tie(*STDERR, 'Mod::TieSTDERR');
tie(*STDOUT, 'Mod::TieSTDOUT');

#create PID file:
if ( open(my $out, '>', $pid_file) ) {
    print $out "$$\n";
    close $out;
}
else {
    $logger->error("Couldn't create PID file: $!");
}

#DB handle is global so that quit() can disconnect it:
my $dbh;

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
        read_conf();
    }
};

#daemon should never receive SIGINT, but just to be safe...
$SIG{INT} = 'IGNORE';

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

    #check to see if SIGHUP was received while subroutine was processing
    if ($HUP) {
        read_conf();
        $HUP = 0;
    }

    #wait
    sleep $conf->{general}->{"interval_$mode"};
}

sub checkIncoming {
    connect_db();
    if (! $dbh ) {
        $logger->error("Could not connect to DB: " . $DBI::errstr);
        return;
    }

    my $db_key = $conf->{db}->{key};

    #Check for new messages:
    my @mail = getMail(
        $conf->{imap}->{server},
        $conf->{imap}->{user},
        $conf->{imap}->{pass},
    );

    my @error_messages; #messages we are going to return immediately

    #Prepare SQL statements:
    my $create_entry = $dbh->prepare("INSERT INTO Messages VALUES (NULL, ?, NOW(), ?, NULL)");
    my $store_raw = $dbh->prepare("INSERT INTO RawMail VALUES (?, AES_ENCRYPT(?,?))");
    my $store_parsed = $dbh->prepare("INSERT INTO ParsedMail VALUES (?, AES_ENCRYPT(?,?))");

    #Go through the mail:
  MAIL:
    for my $raw_mail (@mail) {

        my $uid;
	my $message; #hashref

        #Try to create UID for message
        eval {
            $create_entry->execute(undef, undef);
            $uid = $dbh->last_insert_id(undef,undef,undef,undef);
	    $uid = sprintf("%09d",$uid);
        };

        #If UID wasn't created, log it
        if ($@) {
            $logger->error("Couldn't create UID.");
            $logger->error($DBI::lasth->errstr);
            $logger->error("Message follows:");
            my $encrypted_mail = encrypt($db_key, $raw_mail);
            $logger->error($encrypted_mail);
            next MAIL;
        };

        #Try to store raw mail in DB
        eval {
            $store_raw->execute($uid, $raw_mail, $db_key);
        };

        #If raw mail wasn't stored, log it
        if ($@) {
            $logger->error("Failed to store message $uid in RawMail:");
            $logger->error($DBI::lasth->errstr);
            $logger->error("Message follows:");
            my $encrypted_mail = encrypt($db_key, $raw_mail);
            $logger->error($encrypted_mail);
            next MAIL;
        }

	#Attempt to MIME parse the message
	eval {
	    $message = parseMail($raw_mail, $conf->{smtp}->{user}, $uid);
	};

	#If MIME parsing failed, move on to next message
	if ($@) {
	    $logger->error("Error MIME parsing message $uid:");
            $logger->error($@);
            next MAIL;
	}

	#Unpack message:
	my $return_time = $message->{return_time};
	my $address = $message->{address};
	my $parsed_mail = $message->{mail};

        #Try to store parsed mail in DB
	eval {
	    $store_parsed->execute($uid, $parsed_mail, $db_key);
	};

        #If parsed mail wasn't stored, log it
	if ($@) {
            $logger->error("Failed to store message $uid in ParsedMail:");
            $logger->error($DBI::lasth->errstr);
            $logger->error("Message follows:");
	    my $encrypted_mail = encrypt($db_key, $parsed_mail);
	    $logger->error($encrypted_mail);
            next MAIL;
	}

        #Try to store address
        eval {
            $dbh->do("UPDATE Messages SET address = '$address' WHERE uid = '$uid'");
        };
        if ($@) {
            $logger->error("Failed to store address $address for message $uid:");
            $logger->error($DBI::lasth->errstr);
            next MAIL;
        }

	#If we got a return time, store it.
	if (defined $return_time) {
            eval {
                $dbh->do("UPDATE Messages SET return_time = '$return_time' WHERE uid = '$uid'");
            };
            if ($@) {
                $logger->error("Failed to store return time $return_time for message $uid:");
                $logger->error($DBI::lasth->errstr);
                next MAIL;
            }
	}
        else { #If we didn't get a return time, we will return the message to sender.
            push @error_messages, $message;
        }
    }

    #Return messages for which there was an error to the sender:
    my @sent_uids = sendMessages(
        $conf->{smtp}->{server},
        $conf->{smtp}->{user},
        $conf->{smtp}->{pass},
        @error_messages
    );

    #Mark the messages as sent
    for my $uid (@sent_uids) {
        eval {
            $dbh->do("UPDATE Messages SET sent_time = NOW() WHERE uid = '$uid'");
        };
        if ($@) {
            $logger->error("Failed to store sent time " . fromEpoch(time) . " for message $uid:");
            $logger->error($DBI::lasth->errstr);
            #TODO: if this statement fails, messages could be sent multiple time
            #fallback: store in memory array of messages we've sent?
        }
    }
}

sub checkOutgoing {
    connect_db();
    if (! $dbh ) {
        $logger->error("Could not connect to DB: " . $DBI::errstr);
        return;
    }

    #Check the database for messages to send:
    my $messages_ref = $dbh->selectall_arrayref(
        "SELECT Messages.uid, Messages.address, AES_DECRYPT(ParsedMail.mail, '$conf->{db}->{key}') AS mail " .
        "FROM Messages INNER JOIN ParsedMail " .
        "WHERE Messages.return_time < NOW() AND Messages.sent_time IS NULL AND Messages.uid = ParsedMail.uid",
        { Slice => {} }
    );

    #Send the messages:
    my @sent_uids = sendMessages(
        $conf->{smtp}->{server},
        $conf->{smtp}->{user},
        $conf->{smtp}->{pass},
        @{ $messages_ref }
    );

    #Mark the messages as sent
    for my $uid (@sent_uids) {
        eval {
            $dbh->do("UPDATE Messages SET sent_time = NOW() WHERE uid = '$uid'");
        };
        if ($@) {
            $logger->error("Failed to store sent time " . fromEpoch(time) . " for message $uid:");
            $logger->error($DBI::lasth->errstr);
        }
    }
}

sub archiveMessages {
    connect_db();
    if (! $dbh ) {
        $logger->error("Could not connect to DB: " . $DBI::errstr);
        return;
    }

    eval {
        #Determine how many messages were received in the last 24 hours
        my $received = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM Messages WHERE received_time > '" . fromEpoch(time - 24*60*60) . "'"
        );

        #Determine how many messages were sent in the last 24 hours
        my $sent = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM Messages WHERE sent_time > '" . fromEpoch(time - 24*60*60) . "'"
        );

        #Retrieve messages to be archived
        my $archive_time = fromEpoch(time);
        my $messages_ref = $dbh->selectall_arrayref(
            "SELECT Messages.uid, address, received_time, return_time, sent_time, RawMail.mail, ParsedMail.mail " .
            "FROM Messages INNER JOIN ParsedMail INNER JOIN RawMail " .
            "WHERE Messages.uid = ParsedMail.uid AND Messages.uid = RawMail.uid AND Messages.sent_time < '$archive_time'"
        );
        my @messages = @{ $messages_ref };

        #Determine how many messages are being archived
        my $archived = scalar @messages;

        #Move messages to archive table
        my $archive = $dbh->prepare("INSERT INTO Archive VALUE(?,?,?,?,?,?,?)");
        for my $message (@messages) {
            $archive->execute( @{ $message } );
            $dbh->do("DELETE FROM Messages WHERE uid = '$message->[0]'");
        }

        #Delete old messages in archive
        my $delete_time = fromEpoch(time - 7 * 24 * 60 * 60);
        my $deleted = $dbh->do("DELETE FROM Archive WHERE sent_time < '$delete_time'");
        $deleted += 0; #force numeric context;

        #Collect tails of log files
        my $incoming_log_file = $log_file;
        $incoming_log_file =~ s/archive/incoming/;
        my $incoming_log = get_tail($incoming_log_file);

        my $outgoing_log_file = $log_file;
        $outgoing_log_file =~ s/archive/outgoing/;
        my $outgoing_log = get_tail($outgoing_log_file);

        #Prepare report
        my $report =<<"END_REPORT";
In the last 24 hours,
Messages Received: $received
Messages Sent    : $sent
Messages Archived: $archived
Messages Deleted : $deleted

Incoming Log File:
$incoming_log

Outgoing Log File:
$outgoing_log
END_REPORT

        #Send report
        mailAdmin('Talaria report ' . fromEpoch(time), $report);
    };
    if ($@) {
        $logger->error($@);
        mailAdmin('Talaria report ' . fromEpoch(time) , "Error preparing report: $@");
    }
    #TODO: database maintainance
}

sub mailAdmin {
    my $subject = shift;
    my $text = shift;

    my $mail =<<"END_MAIL";
To: $conf->{general}->{admin_address}
From: $conf->{smtp}->{user}
Subject: $subject

$text


END_MAIL

    #Create the message:
    my %message = (
	mail => $mail,
	address => $conf->{general}->{admin_address},
        uid => 'mailadmin',
	);

    #Send the message:
    my @sent_uids = sendMessages(
        $conf->{smtp}->{server},
        $conf->{smtp}->{user},
        $conf->{smtp}->{pass},
        \%message
    );

    #Log any errors:
    $logger->error("Failed to mail admin: $text") unless (@sent_uids);
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

sub connect_db {
    $dbh = DBI->connect_cached (
        "DBI:mysql:database=$conf->{db}->{server}",
        $conf->{db}->{user},
        $conf->{db}->{pass},
        {PrintError => 0, RaiseError => 1}
    );
}

sub read_conf {
    #Read conf file
    open (my $in, '<', $conf_file) or die "Can't open $conf_file: $!\n";
    my $conf_file_str = do {
        local $/;
        <$in>;
    };
    close $in;

    #Decrypt conf file
    $conf_file_str = decrypt($key,$conf_file_str);

    #Process conf file
    $conf = Config::Tiny->read_string( $conf_file_str );
}

sub get_tail {
    my $file_name = shift;
    open(my $in,"tail $file_name |") or die "$!\n";
    my $file = do {
        local $/;
        <$in>;
    };
    close $in;
    return $file;
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

Config::Tiny

=back
