#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Net::SMTP::SSL;
use MIME::Lite;

#die "Must run with two arguments: file and MIME-type\n" unless (@ARGV == 2);
#my $file = $ARGV[0];
#my $type = $ARGV[1];

#declare sender and recipient:
my $from = 'return.to.me.received@gmail.com';
my $password = 'return2me';
#my $to = 'return.to.me.test@gmail.com';
my $to = 'jack@jackmgill.com';

#compose the email:
my $msg = MIME::Lite->new(
    From    => $from,
    To      => $to,
    Subject => "Test",
    Type    => 'multipart/alternative',
    );
$msg->attach(
    Type     => 'text/plain',
    Path     => 'mail/justin_plain.txt',
    Encoding => 'quoted-printable',
);
$msg->attach(
    Type     => 'text/html',
    Path     => 'mail/justin_html.txt',
    Encoding => 'quoted-printable',
);

my $str = $msg->as_string;
die $str;
#send the email:
my $smtp;
if (not $smtp = Net::SMTP::SSL->new('smtp.gmail.com', Port => 465)) {
	die "Could not connect to SMTP server\n";
}
$smtp->auth($from, $password) or die "Authentication failed!\n";
$smtp->mail($from . "\n");
$smtp->to($to . "\n");
$smtp->data();
$smtp->datasend($str);
$smtp->dataend();

my $smtp_response = $smtp->message;
if ($smtp_response =~ /2.0.0 OK/) {
    print "Email sent successfully.\n";
} else {
    print "Error: email not sent!\n";
}
$smtp->quit;



