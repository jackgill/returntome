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

#todo: get this from conf file?
my $test_address = 'return.to.me.beta@gmail.com';

#Read the config file:
my %conf = %{ getConf('conf/test.conf','foo') };

#Clear DB
my $dbh = DBI->connect(
    "DBI:mysql:database=$conf{db_server}",
    $conf{db_user},
    $conf{db_pass},
    {PrintError => 0, RaiseError => 1}
);
$dbh->do('TRUNCATE TABLE Messages');

$dbh->disconnect();

startTalariad();

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

#print "Sent mail at ",&now,"\n";

#Wait:
sleep(($nMinutes + 2) * 60);

#Check mail:
my @raw_messages = getMail(@conf{'imap_server', 'imap_user', 'imap_pass'});

#print "Checked mail at ",&now,"\n";

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

    #To get the error, convert each date string to epoch seconds:
    my $error;
    if (defined $sent_time) {
        $error = UnixDate(ParseDate($sent_time), "%s") - UnixDate(ParseDate($requested_time), "%s");
    }
    else {
        $error = $tolerance + 1;
    }
    #Print the results:
    if ($sent_time) {
	printf $format,$subject,$requested_time,$sent_time,$error;
        ok($error < $tolerance,$subject);
    } else {
	#printf $format,$subject,$requested_time,'Not Received','';
        fail($subject);
    }

}

#Notify whoever's paying attention:
system "aplay -q ~/beep-7.wav";

stopTalariad();

sub startTalariad {
    open(STDIN,'<t/password.txt') or BAIL_OUT("Couldn't open STDIN: $!");
    system 'bin/talariad.pl incoming';
    close STDIN;

    open(STDIN,'<t/password.txt') or BAIL_OUT("Couldn't open STDIN: $!");
    system 'bin/talariad.pl outgoing';
    close STDIN;

}

sub stopTalariad {
    open(my $in,'<','talariad_incoming.pid') or die "Couldn't open talaria_incoming.pid: $!\n";
    my $pid_incoming = <$in>;
    close $in;

    open($in,'<','talariad_outgoing.pid') or die "Couldn't open talaria_outgoing.pid: $!\n";
    my $pid_outgoing = <$in>;
    close $in;

    system "kill $pid_incoming";
    system "kill $pid_outgoing";

}
