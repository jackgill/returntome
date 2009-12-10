#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::SendMail;
use Mod::GetMail;
use Mod::Conf;
use Mod::Test;

use Data::Dumper::Simple;
use Date::Manip;
use Test::More tests => 4;
use DBI;

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

#Read the config file:
my %conf = getConf('conf/test.conf','foo');

#Clear DB
my $dbh = DBI->connect(
    "DBI:mysql:database=$conf{db_server}",
    $conf{db_user},
    $conf{db_pass},
    {PrintError => 0, RaiseError => 1}
);
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
    my $key = 'foo';
    open(STDIN, "echo $key|") or BAIL_OUT("Couldn't open STDIN: $!");
    system 'bin/talariactl.pl start';
    close STDIN;
}

#Clear inbox:
getMail(@conf{'imap_server', 'imap_user', 'imap_pass'});

#Create mail:
my $nMessages = 4;
my $nMinutes = 2;
my @messages = createMessages($nMessages,$nMinutes,$test_address);

#Load the requested return times into a hash keyed by subject:
my %requested;
for my $message (@messages) {
    my $subject = getHeader($message->{mail},'Subject');
    my $return_time = $message->{return_time};
    $requested{$subject} = $return_time;
}

#Send messages:
#Sending more than 2 messages at a time seems to trip gmail's spam filter,
#so we send them one at a time.
for my $message (@messages) {
    sendMessages(@conf{'smtp_server', 'smtp_user', 'smtp_pass'},$message);
    sleep 15;
}

#Wait:
sleep(($nMinutes + 2) * 60);

#Check mail:
my @raw_messages = getMail(@conf{'imap_server', 'imap_user', 'imap_pass'});

#Print the headers the results:
my $format =  "%-20s %-20s %-20s %-20s\n";
printf $format,'Subject','Requested','Sent','Error (sec)';
print "-"x80,"\n";

#Load the Date header of each received message into a hash keyed by Subject header
my %date;
for my $raw_message (@raw_messages) {
    my $subject = getHeader($raw_message,'Subject');
    my $date = getHeader($raw_message,'Date');
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

#Notify whoever's paying attention
system 'aplay -q ~/beep-7.wav';



