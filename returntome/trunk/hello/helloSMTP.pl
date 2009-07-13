#!/usr/bin/perl -w

use Net::SMTP::SSL;

sub send_mail {
my $to = $_[0];
my $subject = $_[1];
my $body = $_[2];

my $from = 'return.to.me.test@gmail.com';
my $password = 'return2me';

my $smtp;

if (not $smtp = Net::SMTP::SSL->new('smtp.gmail.com',
                            Port => 465,
                            Debug => 1)) {
   die "Could not connect to server\n";
}

$smtp->auth($from, $password) or die "Authentication failed!\n";

$smtp->mail($from . "\n");
my @recepients = split(/,/, $to);
foreach my $recp (@recepients) {
    $smtp->to($recp . "\n");
}
$smtp->data();
$smtp->datasend("From: " . $from . "\n");
$smtp->datasend("To: " . $to . "\n");
$smtp->datasend("Subject: " . $subject . "\n");
$smtp->datasend("\n");
$smtp->datasend($body . "\n");
$smtp->dataend();
$smtp->quit;
}

# Send away!
&send_mail('letothefirst1@yahoo.com', 'please', 'god');
#&send_mail('7203178333@messaging.sprintpcs.com', '', 'Perl just texted you');
#&send_mail('9097232113@vtext.com', '', 'Also, I figured out how to text you from a perl script.');
#&send_mail('7203463815@txt.att.net', '', 'This text was sent to you from a perl script.');
