#!/usr/bin/perl

use strict;
use warnings;

use 5.010;

use Log::Log4perl;
use File::Copy;
use Term::ReadKey;
use Getopt::Long;

use Mod::ParseMail;
use Mod::DB;
use Mod::TieHandle;
use Mod::Conf;
use Mod::GetMail;
use Mod::SendMail;
use Mod::Crypt;

=head1 NAME

    Talaria.pl

=cut

=head1 SYNOPSIS

    bin/Talaria.pl --no-daemon --clear-tables --test-mode

=cut

=head1 DESCRIPTION

    The master program.

=cut

=head1 FUNCTIONS

=over 

=cut

#Defaults for command line switches:
my $no_daemon = '';
my $clear_tables = '';
my $test_mode = '';

#Check command line arguments:
&GetOptions('--no-daemon' => \$no_daemon,
	    '--clear-tables' => \$clear_tables,
	    '--test-mode' => \$test_mode);

if ($test_mode) {
    print "Test mode enabled.\n";
    require Mod::Test;
    Mod::Test->import(qw(getMail sendMail));
} 

#initialize the logger:
Log::Log4perl::init('conf/log4perl_talaria.conf');
my $logger = Log::Log4perl->get_logger();

#Send STDERR to logger:
tie(*STDERR, 'Mod::TieHandle');

#Get encryption key:
our $key = &getKey;
#TODO: compare this with a SHA1 hash to make sure it's correct?

#Read encrypted conf file:
my $conf_file = "conf/talaria.conf.crypt";
my %conf = %{ &getCipherConf($conf_file, $key) };
unless (%conf) {
    print "Failed to decrypt $conf_file\n";
    die "\n";
}

#Check that conf variables are defined:
my @conf_vars = qw(
imap_server imap_user imap_pass 
smtp_server smtp_user smtp_pass 
db_server db_user db_pass admin_address
);
for (@conf_vars) {
    unless (defined $conf{$_}) {
	die "Configuration error: conf/talaria.conf does not define $_\n";
    }
}

#Connect to DB:
&Mod::DB::connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});
if ($clear_tables) {
    &clearTables;
    print "Cleared database.\n";
}

#This program is implemented as 2 processes:
#The parent process provides terminal I/O: CLI
#The child process does the work: daemon
my $pid = 1;
if ($no_daemon) {
    print "Daemon was not started.\n";
} else {
    $pid = fork;
}
if ($pid > 0) { #CLI process

    #define commands:
    my %commands = (
	log => sub {
	    system 'cat log/talaria.log';
	},
	showdb => sub {&showTables($key);},
	makedb => \&makeTables,
	cleardb => \&clearTables, 
	checkmail => sub {
	    eval {&checkIncoming};
	    if ($@) {
		$logger->error("Error checking incoming: $@");
	    }
	},
	time => sub {
	    print &fromEpoch(time),"\n";
	},
	);

    #CLI loop:
    while (1) {
	print "Talaria>"; #display prompt
	chomp(my $line = <STDIN>); #read prompt
	if ($line eq 'stop'){ #this command must be outside the eval block so we can exit
	    &Mod::DB::disconnect;
	    kill 9, $pid; #kill the daemon
	    $logger->info("Talaria daemon stopped.");
	    print "Talaria daemon stopped.\n";
	    exit 0;
	}
	elsif (!$line) {
	    #An empty command does nothing
	}
	elsif ($commands{$line}) {
	    eval { &{$commands{$line}} };
	    print "Error executing command: $@" if $@;
	}
	else {
	    print "Unrecognized command\n";
	}
    }
} elsif ($pid == 0) { #daemon
    $logger->info("Talaria daemon started.");
    print "Talaria daemon started.\n";

    my $last_check = 0; #TODO: persist this across Talaria.pl invocations
    while (1) {
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
	    eval {&purgeSentMessages(time - 60 * 60 * 24)};
	    if ($@) {
		$logger->error("Error purging sent messages: $@");
	    }
	    $last_check = time;
	}
	sleep 60;
    }
} else {
    die "Couldn't create daemon: $!\n";
}

##################################################
#Subroutines:
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
	#$logger->debug('');
	#$logger->debug("Raw Message $uid:");
	#$logger->debug($raw_message);


	my %message = % { &parseMail($raw_message,$uid) }; 
	my $return_time = $message{'return_time'};
	if ($return_time) {
	    #TODO: if &fromEpoch crashes, we're boned and the message gets lost.
	    #use eval block?
	    $logger->info("Return date for message $uid: " . &fromEpoch($return_time));
	    push @parsed_messages, \%message;
	} else {
	    $logger->info('Message ' . $message{'uid'} . ' had no readable date.');
	    push @unparsed_messages, \%message;
	}
    }
    #Store the parsed and unparsed messages in the appropriate tables:
    &putMessages('ParsedMessages',&encryptMessages($key,@parsed_messages));
    &putMessages('UnparsedMessages',&encryptMessages($key,@unparsed_messages));

    #If we couldn't parse the message, return it to sender:
    &sendMessages(@unparsed_messages);
}

sub checkOutgoing {
    $logger->debug('');
    $logger->debug('Checking outgoing...');

    my $current_time = time;
    my @messages_to_send = &getMessagesToSend($current_time);
    &sendMessages(&decryptMessages($key,@messages_to_send));
}

=item sendMessages(messages)

    For each message, extracts the 'From' header from the 'mail' field, 
    and sets it as the 'address' field. Calls &Mod::SendMail::sendMail,
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

sub mailAdmin {
    my $text = shift;
    my $mail = "To: $conf{admin_address}\nFrom: $conf{smtp_user}\nSubject: Talaria Alert\n\n$text\n\n";
    my %message = (
	mail => $mail,
	);
    my ($sent_ref,$unsent_ref) = &sendMail($conf{smtp_server},$conf{smtp_user},$conf{smtp_pass},\%message);
    if (@$unsent_ref) {$logger->info("Error: failed to mail admin: $text");}
}
