package Mod::Talaria;

#pragmas
use 5.010;
use strict;
use warnings;

#modules
use Exporter;
use Log::Log4perl;
use DBI;

use Mod::ParseMail;
use Mod::GetMail;
use Mod::SendMail;
use Mod::Crypt;

our @ISA = qw(Exporter);
our @EXPORT = qw(setConf connectDB disconnectDB checkIncoming checkOutgoing quit archiveMessages);

our $dbh; #Database handle
our %conf; #configuration variables
our $logger = Log::Log4perl->get_logger();

sub setConf {
    my $conf_ref = shift;
    %conf = %{ $conf_ref };
}

sub connectDB {
    $dbh = DBI->connect(
        "DBI:mysql:database=$conf{db_server}",
        $conf{db_user},
        $conf{db_pass},
        {PrintError => 1, RaiseError => 1}
    );
}

sub disconnectDB {
    $dbh->disconnect();
}

sub checkIncoming {

    #Check for new messages:
    my @mail = getMail(@conf{'imap_server', 'imap_user', 'imap_pass'});

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
            $logger->error("Couldn't create UID. Message follows.");
            my $encrypted_mail = encrypt($conf{db_key}, $raw_mail);
            $logger->error($encrypted_mail);
            next MAIL;
        };

        #Try to store raw mail in DB
        eval {
            $store_raw->execute($uid, $raw_mail, $conf{db_key});
        };

        #If raw mail wasn't stored, log it
        if ($@) {
            $logger->error("Failed to store message $uid in RawMail");
            my $encrypted_mail = &encrypt($conf{db_key}, $raw_mail);
            $logger->error($encrypted_mail);
            next MAIL;
        }

	#Attempt to MIME parse the message
	eval {
	    $message = parseMail($raw_mail, $conf{smtp_user}, $uid);
	};

	#If MIME parsing failed, move on to next message
	if ($@) {
	    $logger->error("Error MIME parsing message: $@");
            next MAIL;
	}

	#Unpack message:
	my $return_time = $message->{return_time};
	my $address = $message->{address};
	my $parsed_mail = $message->{mail};

        #Try to store parsed mail in DB
	eval {
	    $store_parsed->execute($uid, $parsed_mail, $conf{db_key});
	};

        #If parsed mail wasn't stored, log it
	if ($@) {
            $logger->error("Failed to store message $uid in ParsedMail");
	    my $encrypted_mail = encrypt($conf{db_key}, $parsed_mail);
	    $logger->error($encrypted_mail);
            next MAIL;
	}

        #Try to store address
        eval {
            $dbh->do("UPDATE Messages SET address = '$address' WHERE uid = '$uid'");
        };
        if ($@) {
            $logger->error("Failed to store address $address for message $uid");
        }

	#If there we got a return time, store it.
	if (defined $return_time) {
            eval {
                $dbh->do("UPDATE Messages SET return_time = '$return_time' WHERE uid = '$uid'");
            };
            if ($@) {
                $logger->error("Failed to store return time $return_time for message $uid");
            }
	}
        else { #If we didn't return the message to sender.
            push @error_messages, $message;
        }
    }

    #Return messages for which there was an error to the sender:
    my @sent_uids = sendMessages(@conf{'smtp_server', 'smtp_user', 'smtp_pass'}, @error_messages);

    #Mark the messages as sent
    for my $uid (@sent_uids) {
        eval {
            $dbh->do("UPDATE Messages SET sent_time = NOW() WHERE uid = '$uid'");
        };
        if ($@) {
            $logger->error("Failed to store sent time " . fromEpoch(time) . " for message $uid");
        }
    }
}

sub checkOutgoing {

    #Check the database for messages to send:
    my $messages_ref = $dbh->selectall_arrayref("SELECT Messages.uid, Messages.address, AES_DECRYPT(ParsedMail.mail, '$conf{db_key}') AS mail FROM Messages INNER JOIN ParsedMail WHERE Messages.return_time < NOW() AND Messages.sent_time IS NULL AND Messages.uid = ParsedMail.uid", { Slice => {} });

    #Send the messages:
    my @sent_uids = sendMessages(@conf{'smtp_server', 'smtp_user', 'smtp_pass'},  @{ $messages_ref } );

    #Mark the messages as sent
    for my $uid (@sent_uids) {
        eval {
            $dbh->do("UPDATE Messages SET sent_time = NOW() WHERE uid = '$uid'");
        };
        if ($@) {
            $logger->error("Failed to store sent time " . fromEpoch(time) . " for message $uid");
        }
    }
}

sub mailAdmin {
    my $text = shift;

    #Create the message:
    my %message = (
	mail => "To: $conf{admin_address}\nFrom: $conf{smtp_user}\nSubject: Talaria Alert\n\n$text\n\n",
	address => $conf{admin_address},
        uid => 'mailadmin',
	);

    #Send the message:
    my @sent_uids = sendMail(@conf{'smtp_server', 'smtp_user', 'smtp_pass'}, \%message);

    #Log any errors:
    $logger->error("Error: failed to mail admin: $text") unless (@sent_uids);
}

sub quit {
    my $signal = shift;
    my $pid_file = shift;

    #Log the fact that we're quiting
    $logger->info("Caught $signal.");
    $logger->info('Talaria daemon exiting.');

    #Disconnect from database
    &disconnectDB;

    #Mail the admin a notification
    unless ($signal eq 'SIGINT') { #SIGINT is used for normal shutdown
	&mailAdmin("talariad went down at " . &now . " due to $signal.");
    }

    #Remove PID file
    unlink($pid_file);

    #Exit
    exit 0;
}

sub archiveMessages {
    my $archive = $dbh->prepare("INSERT INTO Archive VALUE(?,?,?,?,?,?,?)");
    my $archive_time = fromEpoch(time);
    my $messages_ref = $dbh->selectall_arrayref("SELECT * FROM Messages WHERE sent_time < $archive_time");
    my @messages = @{ $messages_ref };
    for my $message (@messages) {
        my $uid = $message->[0];
        my $raw_mail = $dbh->selectrow_array("SELECT mail FROM RawMail WHERE uid = '$uid'");
        my $parsed_mail = $dbh->selectrow_array("SELECT mail FROM ParsedMail WHERE uid = '$uid'");
        $archive->execute(@{ $message }, $raw_mail, $parsed_mail);
        $dbh->do("DELETE FROM Messages WHERE uid = '$uid'");
    }
    my $delete_time = fromEpoch(time - 7 * 24 * 60 * 60);
    $dbh->do("DELETE FROM Archive WHERE sent_time < $delete_time");
    #TODO: database maintainance
}

1;

=head1 NAME

Mod::Talaria

=head1 SYNOPSIS

See bin/talariad.pl

=head1 DESCRIPTION

Contains subroutines used by bin/talariad.pl

=head1 SUBROUTINES

=over

=item *

B<setConf>

Set the configuration options.

I<Arguments:>

=over

=item *

A hash ref.

=back

I<Returns:> None.

=item *

B<checkIncoming>

Check the IMAP server for new messages, parse them, store them in the database.

I<Arguments:> None.

I<Returns:>   None.

=item *

B<checkOutgoing>

Check the database for any messages whose return times are now in the past.
Retrieve those messages and send them.

I<Arguments:> None.

I<Returns:>   None.

=item *

B<mailAdmin>

Mail the administrator a message.
The administrator's email is given in the config file.

I<Arguments:>

=over

=item *

The text of the message to mail the admin.

=back

I<Returns:> None.

=item *

B<quit>

Exit gracefully, disconnecting from the DB and emailing a notification to the admin.

I<Arguments:>

=over

=item *

The signal. (e.g., SIGINT)

=back

I<Returns:> None.

=back

=head1 DEPENDENCIES

=over

=item *

Log::Log4perl

=item *

DBI

=back
