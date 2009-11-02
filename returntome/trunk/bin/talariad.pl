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

#get the CWD for future reference:
my $pwd = $ENV{PWD};

#Only one instance at a time, please:
die "Talariad is already running\n" if (-e "$pwd/talariad.pid");

#Defaults for command line switches:
my $test_mode = '';

#Check command line arguments:
&GetOptions(
    '--test-mode' => \$test_mode,
    );

#Get encryption key:
our $key = &getKey;
#TODO: compare this with a SHA1 hash to make sure it's correct?

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

#Test mode:
if ($test_mode) {
    $logger->info("Test mode enabled.");
    require Mod::Test;
    Mod::Test->import(qw(getMail sendMail));
} 

#Read encrypted conf file:
my $conf_file = "$pwd/conf/daemon.conf";
my %conf = %{ &getCipherConf($conf_file, $key) };
unless (%conf) {
    $logger->info("Failed to decrypt $conf_file") ;
    exit 0;
}

#Check that conf variables are defined:
my @conf_vars = qw(
imap_server imap_user imap_pass 
smtp_server smtp_user smtp_pass 
db_server db_user db_pass 
interval
admin_address
);
for (@conf_vars) {
    unless (defined $conf{$_}) {
	die "Configuration error: $conf_file does not define $_\n";
    }
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
    $logger->debug('');
    $logger->debug('Checking incoming...');

    #Check for new messages:
    my @raw_messages = &getMail($conf{imap_server},$conf{imap_user},$conf{imap_pass});
    my @parsed_messages;
    my @unparsed_messages;

    #Log the number of new messages:
    my $nMessages = @raw_messages;
    if ($nMessages != 0) {
	$logger->info("Retrieved $nMessages messages from IMAP server");
    }
    
    #Parse the messages:
    for my $raw_message (@raw_messages) {
	my $uid = &getUID;
	my %message = %{ &parseMail($raw_message,$uid) }; 
	my $return_time = $message{'return_time'};
	if ($return_time) {
	    $logger->info("Return date for message $uid: " . &fromEpoch($return_time));
	    push @parsed_messages, \%message;
	} else {
	    $logger->info("Message $uid had no readable date.");
	    $logger->debug('');
	    $logger->debug("Raw Message $uid:");
	    $logger->debug($raw_message);	    
	    push @unparsed_messages, \%message;
	}
    }

    #Store the parsed and unparsed messages in the appropriate tables:
    &putMessages('ParsedMessages',&encryptMessages($key,@parsed_messages));
    &putMessages('UnparsedMessages',&encryptMessages($key,@unparsed_messages));

    #If we couldn't parse the message, return it to sender:
    &sendMessages(@unparsed_messages);
}

=item checkOutgoing
    
    Check the database for any messages whose return times are now in the past.
    Retrieve those messages and send them.
  Arguments: None.
  Returns: None.
    
=cut

sub checkOutgoing {
    $logger->debug('');
    $logger->debug('Checking outgoing...');

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
    &putMessages('SentMessages',&encryptMessages($key,@$sent_ref));
    &putMessages('UnsentMessages',&encryptMessages($key,@$unsent_ref));
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
	uid => 'mailadmin', #else Mod::SendMail complains
	);
    my ($sent_ref,$unsent_ref) = &sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},\%message);
    if (@$unsent_ref) {$logger->error("Error: failed to mail admin: $text");}
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
