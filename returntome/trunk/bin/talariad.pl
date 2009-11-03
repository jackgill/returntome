#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Log::Log4perl;
use Getopt::Long;
use Proc::Daemon;

use Mod::ParseMail;
use Mod::DB;
use Mod::TieHandle;
use Mod::Conf;
use Mod::GetMail;
use Mod::SendMail;
use Mod::Crypt;

#get the CWD before we daemonize:
my $pwd = $ENV{PWD};

#Only one instance at a time, please:
die "Talariad is already running\n" if (-e "$pwd/talariad.pid");

#Get encryption key:
our $key = &getCheckedKey("$pwd/conf/key.sha1_base64");

#daemonize:
Proc::Daemon::Init();

#create PID file:
open(my $out,">$pwd/talariad.pid");
print $out "$$\n";
close $out;

#initialize the logger:
Log::Log4perl::init_once("$pwd/conf/log4perl_daemon.conf");
my $logger = Log::Log4perl->get_logger();

$logger->info("PID: $$");
$logger->info("Talaria daemon started.");

#Send STDERR to logger:
tie(*STDERR, 'Mod::TieHandle');

#Read encrypted conf file:
my $conf_file = "$pwd/conf/daemon.conf";
my %conf = %{ &getCipherConf($conf_file, $key) };
die "Failed to decrypt $conf_file" unless (%conf);

#Check that conf variables are defined:
my @conf_vars = qw(
imap_server imap_user imap_pass 
smtp_server smtp_user smtp_pass 
db_server db_user db_pass 
interval
admin_address
);
for (@conf_vars) {
    die "Configuration error: $conf_file does not define $_\n" unless (defined $conf{$_});
}

#Connect to DB:
&Mod::DB::connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});

#Set up signal handlers:
$SIG{HUP}  = sub { &quit("SIGHUP") };
$SIG{INT}  = sub { &quit("SIGINT") };
$SIG{QUIT} = sub { &quit("SIGQUIT") };
$SIG{TERM} = sub { &quit("SIGTERM") };

#the last time SentMessages was purged
my $last_check = 0; #TODO: persist this across Talaria.pl invocations
 
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

    #Once a day, purge all day old sent messages 
    if (time > ($last_check + (60 * 60 * 24))) {
	eval {&deleteMessagesByTime('SentMessages',time - 60 * 60 * 24)};
	if ($@) {
	    $logger->error("Error purging sent messages: $@");
	}
	$last_check = time;
    }

    #Wait:
    sleep $conf{interval};
}

=item checkIncoming
    
    Check the IMAP server for new messages, parse them, store them in the database.

=cut

sub checkIncoming {

    #Check for new messages:
    my @mail = &getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass});
 
    my @raw_messages; #messages exactly as we received them.
    my @parsed_messages; #messages we parsed, and have a return time.
    my @unparsed_messages; #messages we didn't parse, and have an error message.
 
    #Log the number of new messages:
    my $nMessages = @mail;
    if ($nMessages != 0) {
	$logger->info("Retrieved $nMessages messages from IMAP server");
    } else {
	return;
    }
    
    #Go through the mail:
    for (@mail) {
	#Build and store the raw message:
	my $uid = &getUID;
	my %raw_message = (
	    uid => $uid,
	    mail => $_,
	    );
	push @raw_messages, \%raw_message;
	
	#Try parsing the message:
	my %message = %{ &parseMail($_,$uid) }; 
	my $return_time = $message{'return_time'};

	if ($return_time) { #Parsing succeeded.
	    $logger->info("Return date for message $uid: " . &fromEpoch($return_time));
	    push @parsed_messages, \%message;
	} else { #Parsing failed.
	    $logger->info("Message $uid had no readable date.");
	    push @unparsed_messages, \%message;
	}
    }

    #Store the parsed and unparsed messages in the appropriate tables:
    &putUnparsedMessages('RawMessages',&encryptMessages($key,@raw_messages));
    &putParsedMessages('ParsedMessages',&encryptMessages($key,@parsed_messages)) if (@parsed_messages);
    &putUnparsedMessages('UnparsedMessages',&encryptMessages($key,@unparsed_messages)) if (@unparsed_messages);

    #If we couldn't parse the message, return it to sender:
    &sendMessages(@unparsed_messages) if (@unparsed_messages);
}

=item checkOutgoing
    
    Check the database for any messages whose return times are now in the past.
    Retrieve those messages and send them.
  Arguments: None.
  Returns: None.
    
=cut

sub checkOutgoing {
    #Check the database for messages to send:
    my @messages = &getMessagesByTime('ParsedMessages',time);
    &deleteMessagesByTime('ParsedMessages',time);

    #Send the messages:
    &sendMessages(&decryptMessages($key,@messages));
}

=item sendMessages(messages)

    Calls &Mod::SendMail::sendMail,
    then encrypts and stores the sent and unsent messages in the database.

    Arguments: A list of hash refs, each referring to an unencrypted message.
    Returns: None.

=cut

sub sendMessages {
    my @messages = @_;
    return unless @messages;

    #Send the messages:
    my ($sent_ref,$unsent_ref) = &sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},@messages);

    #Store the sent and unsent messages:
    &putParsedMessages('SentMessages',&encryptMessages($key,@$sent_ref));
    &putParsedMessages('UnsentMessages',&encryptMessages($key,@$unsent_ref));
}

=item mailAdmin(text)

    Mail the administrator a message.
    The administrator's email is given in the config file.

=cut

sub mailAdmin {
    my $text = shift;
    my $mail = "To: $conf{admin_address}\nFrom: $conf{smtp_user}\nSubject: Talaria Alert\n\n$text\n\n";
    my %message = (
	mail => $mail,
	uid => 'mailadmin', #Mod::SendMail will log this
	);
    my ($sent_ref,$unsent_ref) = &sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},\%message);
    $logger->error("Error: failed to mail admin: $text") if (@$unsent_ref);
}

=item quit(signal)

    Exit gracefully, disconnecting from the DB and emailing a notification to the admin.

=cut

sub quit {
    my $signal = shift;
    $logger->info("Caught $signal.");
    $logger->info('Talaria daemon exiting.');
    &Mod::DB::disconnect;
    &mailAdmin("talariad went down at " . &now . " due to $signal.");
    unlink("$pwd/talariad.pid");
    exit 0;
}

=back

=cut
