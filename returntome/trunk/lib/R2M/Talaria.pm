package R2M::Talaria;

use 5.010;
use strict;
use warnings;

use Exporter;
use DBI;
use R2M::Crypt;
use R2M::Mail;
use R2M::Parse;

our @ISA = qw(Exporter);
our @EXPORT = qw(incoming outgoing archive connect_db);

sub incoming {
    my ($conf, $dbh) = @_;
    my $logger = Log::Log4perl->get_logger();

    my $db_key = $conf->{db}->{key};

    #Check for new messages
    my @mail = R2M::Mail::get_mail(
        $conf->{imap}->{server},
        $conf->{imap}->{user},
        $conf->{imap}->{pass},
    );

    my @error_messages; #messages we are going to return immediately

    #Prepare SQL statements
    my $create_entry = $dbh->prepare("INSERT INTO Messages VALUES (NULL, ?, NOW(), ?, NULL)");
    my $store_raw    = $dbh->prepare("INSERT INTO RawMail VALUES (?, AES_ENCRYPT(?,?))");
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
            $logger->error("Couldn't create UID: $DBI::lasth->errstr");
            $logger->error("Message follows:");
            my $encrypted_mail = encrypt($db_key, $raw_mail);
            $logger->error("\n$encrypted_mail\n");
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
	    $message = parse_mail($raw_mail, $conf->{smtp}->{user}, $uid);
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
    my @sent_uids = R2M::Mail::send_mail(
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
            $logger->error("Failed to store sent time " . from_epoch(time) . " for message $uid:");
            $logger->error($DBI::lasth->errstr);
            #TODO: if this statement fails, messages could be sent multiple time
            #fallback: store in memory array of messages we've sent?
        }
    }
}

sub outgoing {
    my ($conf, $dbh) = @_;
    my $logger = Log::Log4perl->get_logger();

    #Check the database for messages to send:
    my $messages_ref = $dbh->selectall_arrayref(
        "SELECT Messages.uid, Messages.address, AES_DECRYPT(ParsedMail.mail, '$conf->{db}->{key}') AS mail " .
        "FROM Messages INNER JOIN ParsedMail " .
        "WHERE Messages.return_time < NOW() AND Messages.sent_time IS NULL AND Messages.uid = ParsedMail.uid",
        { Slice => {} }
    );

    #Send the messages:
    my @sent_uids = send_mail(
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
            $logger->error("Failed to store sent time " . from_epoch(time) . " for message $uid: $DBI::lasth->errstr");
        }
    }
}

#TODO: these log files are beingh held in memory. Check log file modification time stamp instead?
my $old_incoming = "";
my $old_outgoing = "";
my $old_archive  = "";

sub archive {
    my ($conf, $dbh) = @_;
    my $logger = Log::Log4perl->get_logger();

    eval {
        #Determine how many messages were received in the last 24 hours
        my $received = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM Messages WHERE received_time > '" . from_epoch(time - 24*60*60) . "'"
        );

        #Determine how many messages were sent in the last 24 hours
        my $sent = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM Messages WHERE sent_time > '" . from_epoch(time - 24*60*60) . "'"
        );

        #Retrieve messages to be archived
        my $archive_time = from_epoch(time);
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
        my $delete_time = from_epoch(time - 7 * 24 * 60 * 60);
        my $deleted = $dbh->do("DELETE FROM Archive WHERE sent_time < '$delete_time'");
        $deleted += 0; #force numeric context;

        #Collect tails of log files
        my $incoming_log = get_tail($conf->{general}->{cwd} . '/log/talariad_incoming.log');
        my $outgoing_log = get_tail($conf->{general}->{cwd} . '/log/talariad_outgoing.log');
        my $archive_log  = get_tail($conf->{general}->{cwd} . '/log/talariad_archive.log');

        my $new_log = "";
        if (
            ($old_incoming ne $incoming_log) ||
            ($old_outgoing ne $outgoing_log) ||
            ($old_archive  ne $archive_log)
        ) {
            $new_log = "NEW LOG ENTRIES";
            $old_incoming = $incoming_log;
            $old_outgoing = $outgoing_log;
            $old_archive = $archive_log;
        }

        #Prepare report
        my $report =<<"END_REPORT";
Incoming Log File:
$incoming_log

Outgoing Log File:
$outgoing_log

Archive Log File:
$archive_log
END_REPORT

        #Send report
        mailAdmin($conf, "Talaria: R: $received S: $sent $new_log", $report);
    };
    if ($@) {
        $logger->error($@);
        mailAdmin($conf, "Talaria: Error preparing report: $@");
    }
    #TODO: database maintainance
}

sub connect_db {
    my $conf = shift;

    my $dbh = DBI->connect_cached (
        "DBI:mysql:database=$conf->{db}->{server}",
        $conf->{db}->{user},
        $conf->{db}->{pass},
        {PrintError => 0, RaiseError => 1}
    );

    return $dbh;
}

sub mailAdmin {
    my ($conf, $subject, $text) = @_;
    my $logger = Log::Log4perl->get_logger();

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
    my @sent_uids = send_mail(
        $conf->{smtp}->{server},
        $conf->{smtp}->{user},
        $conf->{smtp}->{pass},
        \%message
    );

    #Log any errors:
    $logger->error("Failed to mail admin: $text") unless (@sent_uids);
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

1;

=head1 NAME

R2M::Talaria -- Subroutines for the three talariad modes: incoming, outgoing, and archive.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES

=over

=item *

B<incoming>

=item *

B<outgoing>

=item *

B<archive>

=back

=head1 DEPENDENCIES

=over

=item *

DBI

=item *

R2M::Crypt

=item *

R2M::Parse

=item *

=R2M::Mail

=back
