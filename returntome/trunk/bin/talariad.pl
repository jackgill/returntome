#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Log::Log4perl;
use Getopt::Long;
use Proc::Daemon;
use DBI;

use Mod::ParseMail;
use Mod::TieSTDERR;
use Mod::TieSTDOUT;
use Mod::Conf;
use Mod::GetMail;
use Mod::SendMail;
use Mod::Crypt;

#get the CWD before we daemonize:
my $pwd = $ENV{PWD};

#Various conf variables:
my $conf_file = "$pwd/conf/talaria.conf";
my $key_digest= "$pwd/conf/key.sha1_base64";
my $logger_conf_file = "$pwd/conf/log4perl_talaria.conf";
my $pid_file = "$pwd/talariad.pid"

#Only one instance at a time, please:
die "talariad is already running.\n" if (-e $pid_file);

#Get encryption key:
our $key = &getCheckedKey($key_digest);

#daemonize:
Proc::Daemon::Init();

#create PID file:
open(my $out,">$pwd/talariad.pid");
print $out "$$\n";
close $out;

#initialize the logger:
Log::Log4perl::init_once($logger_conf_file);
my $logger = Log::Log4perl->get_logger();
$logger->info("PID: $$");
$logger->info("Talaria daemon started.");

#Send output streams to logger:
tie(*STDERR, 'Mod::TieSTDERR');
tie(*STDOUT, 'Mod::TieSTDOUT');

#Read conf file:
my %conf = %{ &getConf($conf_file, $key) };

#Connect to DB:
my $dbh = DBI->connect("DBI:mysql:database=$conf{db_server}",$conf{db_user},$conf{db_pass},{PrintError => 0, RaiseError => 1});

#Set up signal handlers:
$SIG{HUP}  = sub { &quit("SIGHUP") };
$SIG{QUIT} = sub { &quit("SIGQUIT") };
$SIG{TERM} = sub { &quit("SIGTERM") };
$SIG{INT}  = sub {     
    $dbh->disconnect;
    $logger->info("Caught SIGINT.");
    $logger->info('Talaria daemon exiting.');
    unlink("$pwd/talariad.pid");
    exit 0;
 };

#Main loop:
while (1) {
    #Check incoming and outgoing, wrapped in eval blocks for safety:
    eval {&checkIncoming};
    if ($@) {
	$logger->error("Error checking incoming: $@");
    }
    eval {&checkOutgoing};
    if ($@) {
	$logger->error("Error checking outgoing: $@");
    }

    #Wait:
    sleep $conf{interval};
}

#########################
#Subroutines

sub checkIncoming {

    #Check for new messages:
    my @mail = &getMail(@conf{'imap_server', 'imap_user', 'imap_pass'});
    
    my @return_messages; #messages we are going to return immediately
    
    #If we have mail, log the number of new messages:
    $logger->info("Retrieved " . scalar @mail ." messages from IMAP server") if (scalar @mail);    

    #Prepare SQL statements:
    my $create_entry = $dbh->prepare("INSERT INTO Messages VALUES (NULL, ?, NOW(), ?, NULL)");
    my $store_raw = $dbh->prepare("INSERT INTO RawMail VALUES (?, AES_ENCRYPT(?,?))");
    my $store_parsed = $dbh->prepare("INSERT INTO ParsedMail VALUES (?, AES_ENCRYPT(?,?))");

    #Go through the mail:
  MAIL:
    for my $raw_mail (@mail) {
	
	#Attempt to MIME parse the message:
	my $message; #hashref
	eval { $message = &parseMail($raw_mail, $conf{smtp_user}) }; 

	if ($@) { #MIME parsing failed
	    $logger->error("Error MIME parsing message: $@");
	    $create_entry->execute(undef, undef);
	    my $uid = $dbh->last_insert_id(undef,undef,undef,undef);
	    $store_raw->execute($uid, $raw_mail, $key);
	    next MAIL;
	} 

	#Unpack message:
	my $return_time = $message->{return_time};
	my $address = $message->{address};
	my $parsed_mail = $message->{mail};

	#Create an entry and set UID for this message:
	$create_entry->execute($address, $return_time);
	my $uid = $dbh->last_insert_id(undef,undef,undef,undef);
	$uid = sprintf("%09d",$uid);
	$message->{uid} = $uid;

	#Store this message:
	$store_raw->execute($uid, $raw_mail, $key);
	$store_parsed->execute($uid, $parsed_mail, $key);

	#Return unparsable messages to sender:
	if ($return_time) { #Parsing succeeded.
	    $logger->info("Return date for message $uid: " . $return_time);
	} else { #Parsing failed.
	    $logger->info("Message $uid had no readable date.");
	    push @return_messages, $message;
	}
    }

    #If we couldn't parse the message, return it to sender:
    &sendMessages(@return_messages) if (@return_messages);
}

sub checkOutgoing {
    #Check the database for messages to send:
    my $messages_ref = $dbh->selectall_arrayref("SELECT Messages.uid, Messages.address, AES_DECRYPT(ParsedMail.mail, '$key') AS mail FROM Messages INNER JOIN ParsedMail WHERE Messages.uid = ParsedMail.uid AND Messages.return_time < NOW() AND Messages.sent_time IS NULL", { Slice => {} });

    my @messages = @{ $messages_ref };

    #Send the messages:
    &sendMessages(@messages) if (@messages);
}

sub sendMessages {
    my @messages = @_;

    #Send the messages:
    my ($sent_ref,$unsent_ref) = &sendMail(@conf{'smtp_server', 'smtp_user', 'smtp_pass'},@messages);

    #Mark the messages as sent
    for my $message (@$sent_ref) {
	my $uid = $message->{uid};
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
    my ($sent_ref,$unsent_ref) = &sendMail(@conf{'smtp_server', 'smtp_user', 'smtp_pass'}, \%message);
    
    #Log any errors:
    $logger->error("Error: failed to mail admin: $text") if (@$unsent_ref);
}


sub quit {
    my $signal = shift;

    #Log the fact that we're quiting
    $logger->info("Caught $signal.");
    $logger->info('Talaria daemon exiting.');

    #Disconnect from database
    $dbh->disconnect;

    #Mail the admin a notification
    &mailAdmin("talariad went down at " . &now . " due to $signal.");

    #Remove PID file
    unlink("$pwd/talariad.pid");

    #Exit
    exit 0;
}

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
