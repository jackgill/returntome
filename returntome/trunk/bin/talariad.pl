#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Log::Log4perl;
use Getopt::Long;
use Proc::Daemon;

use Mod::ParseMail;
use Mod::DB;
use Mod::TieSTDERR;
use Mod::TieSTDOUT;
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

#Send output streams to logger:
tie(*STDERR, 'Mod::TieSTDERR');
tie(*STDOUT, 'Mod::TieSTDOUT');

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
&Mod::DB::connect("mysql:database=" . $conf{db_server, db_user, db_pass});

#Set up signal handlers:
$SIG{HUP}  = sub { &quit("SIGHUP") };
$SIG{QUIT} = sub { &quit("SIGQUIT") };
$SIG{TERM} = sub { &quit("SIGTERM") };
$SIG{INT}  = sub {     
    $logger->info("Caught SIGINT.");
    $logger->info('Talaria daemon exiting.');
 };

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
    my @mail = &getMail($conf{imap_server, imap_user, imap_pass});
 
    my @return_messages; #messages we are going to return immediately
    
    my $nMessages = scaler @mail;
    if ($nMessages != 0) {#If we have mail, log the number of new messages:
	$logger->info("Retrieved $nMessages messages from IMAP server");
    } else {#If we don't have mail, return:
	return;
    }
    
    #Go through the mail:
    for my $raw_mail (@mail) {
	
	#Attempt to MIME parse the message:
	my $message; #hashref
	eval { $message = &parseMail($mail, $conf{smtp_user}) }; 

	if ($@) { #MIME parsing failed
	    $logger->error("Error MIME parsing message: $@");
	    my $uid = &createEntry(undef,time,undef);
	    &storeMail('RawMail',$uid, $raw_mail, $key);
	} else { #MIME parsing succeeded
	    my $return_time = $message->{return_time};
	    my $address = $message->{address};
	    my $parsed_mail = $message->{mail};
	    my $uid = &createEntry($address, time, $return_time);
	    &storeMail('RawMail',$uid, $raw_mail, $key);
	    &storeMail('ParsedMail',$uid, $parsed_mail, $key);

	    if ($return_time) { #Parsing succeeded.
		$logger->info("Return date for message $uid: " . $return_time);
	    } else { #Parsing failed.
		$logger->info("Message $uid had no readable date.");
		push @return_messages, $message;
	    }
	}
    }

    #If we couldn't parse the message, return it to sender:
    &sendMessages(@return_messages) if (@return_messages);
}

=item checkOutgoing
    
    Check the database for any messages whose return times are now in the past.
    Retrieve those messages and send them.
  Arguments: None.
  Returns: None.
    
=cut

sub checkOutgoing {
    #Check the database for messages to send:
    my @messages = &getMessagesToReturn(time, $key);

    #Send the messages:
    my ($sent_ref,$unsent_ref) = &sendMail($conf{smtp_server, smtp_user, smtp_pass},@messages);

    #Mark the messages as sent
    for my $message (@$sent_ref) {
	&markAsSent($message->{uid});
    }

    #Log any errors:
    for my $message (@$unsent_ref) {
	$logger->error("Failed to send message " . $message->{uid});
    }
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
	address => $conf{admin_address},
	);
    my ($sent_ref,$unsent_ref) = &sendMail($conf{smtp_server, smtp_user, smtp_pass},\%message);
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
