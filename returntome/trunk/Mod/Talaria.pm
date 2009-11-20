package Mod::Talaria;

use 5.010;

use strict;
use warnings;

use Exporter;
use Log::Log4perl;
use DBI;

use Mod::ParseMail;
use Mod::GetMail;
use Mod::SendMail;
use Mod::Crypt;

our @ISA = qw(Exporter);
our @EXPORT = qw(setConf connectDB disconnectDB checkIncoming checkOutgoing quit);

our $dbh; #Database handle
our %conf; #configuration variables
our $logger = Log::Log4perl->get_logger();

sub setConf {
    my $conf_ref = shift;
    %conf = %{ $conf_ref };
}

sub connectDB {
    $dbh = DBI->connect("DBI:mysql:database=$conf{db_server}",$conf{db_user},$conf{db_pass},{PrintError => 0, RaiseError => 1});
}

sub disconnectDB {
    $dbh->disconnect();
}

sub checkIncoming {

    #Check for new messages:
    my @mail = &getMail(@conf{'imap_server', 'imap_user', 'imap_pass'});
    
    my @error_messages; #messages we are going to return immediately
    
    #Prepare SQL statements:
    my $create_entry = $dbh->prepare("INSERT INTO Messages VALUES (NULL, ?, NOW(), ?, NULL)");
    my $store_raw = $dbh->prepare("INSERT INTO RawMail VALUES (?, AES_ENCRYPT(?,?))");
    my $store_parsed = $dbh->prepare("INSERT INTO ParsedMail VALUES (?, AES_ENCRYPT(?,?))");

    #Go through the mail:
  MAIL:
    for my $raw_mail (@mail) {

	my $message; #hashref
	
	#Attempt to MIME parse the message:
	eval { 
	    $message = &parseMail($raw_mail, $conf{smtp_user});
	}; 

	#If MIME parsing failed, store raw mail and move on to next message
	if ($@) { 
	    $logger->error("Error MIME parsing message: $@");

	    #Try to store message in DB:
	    eval { 
		$create_entry->execute(undef, undef);
		my $uid = $dbh->last_insert_id(undef,undef,undef,undef);
		$store_raw->execute($uid, $raw_mail, $conf{db_key});
	    };

	    #If we can't store the message in the DB, log it
	    if ($@) { 
		my $encrypted_mail = &encrypt($conf{db_key}, $raw_mail);
		$logger->error($encrypted_mail);
	    }
	    next MAIL;
	} 

	#Unpack message:
	my $return_time = $message->{return_time};
	my $address = $message->{address};
	my $parsed_mail = $message->{mail};

        #Try to store message in DB
	eval {  
	    #Create an entry and set UID for this message:
	    $create_entry->execute($address, $return_time);
	    my $uid = $dbh->last_insert_id(undef,undef,undef,undef);
	    $uid = sprintf("%09d",$uid);
	    $message->{uid} = $uid;
	    
	    #Store this message:
	    $store_raw->execute($uid, $raw_mail, $conf{db_key});
	    $store_parsed->execute($uid, $parsed_mail, $conf{db_key});
	};

	#If we can't store the message in the DB, log it
	if ($@) {
	    my $encrypted_mail = &encrypt($conf{db_key}, $raw_mail);
	    $logger->error($encrypted_mail);

	    $encrypted_mail = &encrypt($conf{db_key}, $parsed_mail);
	    $logger->error($encrypted_mail);
	}

	#If there was an error, we will return message to sender:
	unless ($return_time) {
	    push @error_messages, $message;
	}
    }

    #Return messages for which there was an error to the sender:
    &sendMessages(@error_messages);
}

sub checkOutgoing {

    #Check the database for messages to send:
    my $messages_ref = $dbh->selectall_arrayref("SELECT Messages.uid, Messages.address, AES_DECRYPT(ParsedMail.mail, '$conf{db_key}') AS mail FROM Messages INNER JOIN ParsedMail WHERE Messages.return_time < NOW() AND Messages.sent_time IS NULL AND Messages.uid = ParsedMail.uid", { Slice => {} });

    my @messages = @{ $messages_ref };

    &sendMessages(@messages);
}

sub sendMessages {
    my @messages = @_;

    #Send the messages:
    my @sent_uids = &sendMail(@conf{'smtp_server', 'smtp_user', 'smtp_pass'},@messages);

    #Mark the messages as sent
    for my $uid (@sent_uids) {
	$dbh->do("UPDATE Messages SET sent_time = NOW() WHERE uid = '$uid'");
    }
}

sub mailAdmin {
    my $text = shift;

    #Create the message:
    my %message = (
	mail => "To: $conf{admin_address}\nFrom: $conf{smtp_user}\nSubject: Talaria Alert\n\n$text\n\n",
	address => $conf{admin_address},
	);

    #Send the message:
    my @sent_uids = &sendMail(@conf{'smtp_server', 'smtp_user', 'smtp_pass'}, \%message);
    
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

1;

=over

=cut

=item checkIncoming
    
    Check the IMAP server for new messages, parse them, store them in the database.

=cut

=item checkOutgoing
    
    Check the database for any messages whose return times are now in the past.
    Retrieve those messages and send them.
  Arguments: None.
  Returns: None.
    
=cut

=item mailAdmin(text)

    Mail the administrator a message.
    The administrator's email is given in the config file.

=cut

=item quit(signal)

    Exit gracefully, disconnecting from the DB and emailing a notification to the admin.

=cut

=back

=cut
