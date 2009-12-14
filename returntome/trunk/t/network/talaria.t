#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;
use Date::Manip;
use Test::More tests => 6;
use Test::MockObject;
use DBI;
use Email::Simple;

#Mock Log::Log4perl
$INC{'Log/Log4perl.pm'} = 1;
my $logger = Test::MockObject->new();
$logger->fake_module(
    'Log::Log4perl',
    get_logger => sub {$logger},
);
$logger->mock('error',
              sub {
                  my ($self, $text) = @_;
                  print "\$logger->error($text)\n";
              }
          );

use R2M::Mail;
use R2M::Conf;
use R2M::Parse;
use R2M::Talaria;

#TestTalaria.pl
#Send a set of test messages to the Talaria program
#Wait for their return
#Check that they were returned at the correct time

#Usage: talaria.t 1 or talaria.t to test development deployment
#       talaria.t 0 to test test deployment
my $local = 1;
if (@ARGV) {
    $local = $ARGV[0];
}
my $test_address;
if ($local) {
    $test_address= 'return.to.me.test@gmail.com';
}
else {
    $test_address= 'return.to.me.beta@gmail.com';
}

my $sending_address = 'return.to.me.receive@gmail.com';

#Read the config file:
my $conf_file  = 'conf/talaria.conf';
my $key = 'foo';
my $conf = read_conf($conf_file, $key);
my $dbh = connect_db($conf);

#Clear DB
if ($dbh) {
    $dbh->do('TRUNCATE TABLE Messages');
    $dbh->do('TRUNCATE TABLE Archive');
    $dbh->disconnect();
}
else {
    die("Error: could not connect to DB: " . $DBI::errstr . "\n");
}

if ($local) {
    #Start talariad.pl
    open(STDIN, "echo $key|") or BAIL_OUT("Couldn't open STDIN: $!");
    system 'bin/talariad.pl incoming';
    close STDIN;

    open(STDIN, "echo $key|") or BAIL_OUT("Couldn't open STDIN: $!");
    system 'bin/talariad.pl outgoing';
    close STDIN;
}

#Clear inbox:
get_mail(
    $conf->{imap}->{server},
    $sending_address,
    $conf->{imap}->{pass},
);

#Create mail:
my $nMessages = 4;
my $nMinutes = 2;


my %requested;
my @messages;
for (my $i = 0; $i < $nMessages; $i++) {

    #Determine when this message will be returned, in epoch sends
    my $return_time = time + $nMessages * 15 + int(rand($nMinutes * 60));

    #Compose the body of the message
    my $body;

    #The last two messages will have no instructions
    if ($i >= ($nMessages - 2)) {
        $body = "no instructions here...";
	    $return_time = time + $nMessages * 15;
    }
    else {
        $body = "R2M: " . from_epoch($return_time) . "\nbody $i";
    }

    my $subject = "subject $i";

    #Create the mail
    my $mail =<<"END_MAIL";
From: $sending_address
To: $test_address,
Subject: $subject

$body

END_MAIL

    #Construct the message hash
    my %message = (
        mail => $mail,
        address => $test_address,
    );

    push @messages, \%message;

    #Load the requested return times into a hash keyed by subject:
    $requested{$subject} = from_epoch($return_time);
}

#Send messages:
#Sending more than 2 messages at a time seems to trip gmail's spam filter,
#so we send them one at a time.
for my $message (@messages) {
    my @sent_uids = send_mail(
        $conf->{smtp}->{server},
        $sending_address,
        $conf->{smtp}->{pass},
        $message,
    );
    unless (scalar @sent_uids == 1) {
         die "Could not send message.\n";
     }
    sleep 15;
}

#Wait:
sleep(($nMinutes + 2) * 60);

#Check mail:
my @raw_messages = get_mail(
    $conf->{imap}->{server},
    $sending_address,
    $conf->{imap}->{pass},
);

#Print the headers the results:
my $format =  "%-20s %-20s %-20s %-20s\n";
printf $format,'Subject','Requested','Sent','Error (sec)';
print "-"x80,"\n";

#Load the Date header of each received message into a hash keyed by Subject header
my %date;
for my $raw_message (@raw_messages) {
    my $email = Email::Simple->new( $raw_message );
    my $subject = $email->header('Subject');
    my $date = $email->header('Date');
    $date{$subject} =  UnixDate(ParseDate($date),"%Y-%m-%d %T");
}

my $tolerance = 120; #seconds

#For each message received, print the time requested and the time sent:
for my $subject (sort keys %requested) {

    #Get the time this message was requested, and the time it was actually sent
    my $requested_time = $requested{$subject};
    my $sent_time = $date{$subject};

    #Print the results:
    if ($sent_time) {
        #To get the error, convert each date string to epoch seconds:
        my $error = UnixDate(ParseDate($sent_time), "%s") - UnixDate(ParseDate($requested_time), "%s");
	printf $format,$subject,$requested_time,$sent_time,$error;
        ok($error < $tolerance,$subject);
    }
    else {
        fail($subject);
    }
}

if ($local) {
    #Stop talariad.pl
    system 'bin/talariactl.pl stop';
}

#TODO: check talariad log files
my $log_file = 'log/talariad_incoming.log';
open (my $in, '<', $log_file) or die "Couldn't open $log_file: $!\n";
my @lines = <$in>;
close $in;
is(scalar @lines, 2, "$log_file has no error messages");

$log_file = 'log/talariad_outgoing.log';
open ($in, '<', $log_file) or die "Couldn't open $log_file: $!\n";
@lines = <$in>;
close $in;
is(scalar @lines, 2, "$log_file has no error messages");

#Notify whoever's paying attention
system 'aplay -q ~/beep-7.wav';

sub create_messages {
    my ($nMessages, $nMinutes, $to) = @_;

    my @messages;
    for (my $i = 0; $i < $nMessages; $i++) {

        #Determine when this message will be returned, in epoch sends
	my $return_time = time + $nMessages * 15 + int(rand($nMinutes * 60));

        #Parse the return time
	my $dt = DateTime->from_epoch( epoch => $return_time, time_zone => 'America/Denver');

        #Compose the body of the message
	my $body;

        #The last two messages will have no instructions
	if ($i >= ($nMessages - 2)) {
	    $body = "no instructions here...";
	    $return_time = time + $nMessages * 15;
	}
        else {
            $body = "R2M: " . $dt->hms . " " . $dt->mdy . "\nbody $i";
        }

        #Construct the MIME message
	my $msg = MIME::Lite->new(
	    From    => $sending_address,
	    To      => $test_address,
	    Subject => "subject $i",
	    Type    => 'multipart/alternative',
	    );
	$msg->attach(
	    Type     => 'text/plain',
	    Data     => $body,
	    );
	$msg->attach(
	    Type => 'text/html',
	    Data => '<br>' . $body . '<br>',
	    );

        #Construct the message hash
	my %message = (
	    mail => $msg->as_string,
	    return_time => $dt->ymd . " " . $dt->hms,
	    address => $to,
	    );

	push @messages, \%message;
    }

    return @messages;
}
