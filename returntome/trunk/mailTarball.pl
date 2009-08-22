#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Net::SMTP::SSL;
use MIME::Lite;
use DateTime;

#Make gzip'd tarball of the current source tree and email it

#make the backup
#system 'tar -cf r2m.tar trunk';
#system 'gzip r2m.tar';
#unlink 'r2m.tar';
#my $file = 'r2m.tar.gz';
my $file = $ARGV[0];
die "Must run with one argument: gzip'd tarball\n" unless ($file =~ /tar.gz$/);

#declare sender and recipient:
my $from = 'return.to.me.test@gmail.com';
my $password = 'return2me';
my $to = 'return.to.me.backup@gmail.com';

#compose the email:
my $dt = DateTime->from_epoch( epoch => time, time_zone => 'America/Denver');
my $date = $dt->hms . " " . $dt->mdy;
my $msg = MIME::Lite->new(
    From    => $from,
    To      => $to,
    Subject => "R2M Backup $date",
    Type    => 'multipart/mixed',
    );
$msg->attach(
    Type     => 'application/x-tar-gz',
    Path     => $file,
    Filename => $file,
    Disposition => 'attachment'
   );
my $str = $msg->as_string;

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
    print "Backup email sent successfully.\n";
} else {
    print "Error: backup email not sent!\n";
}
$smtp->quit;

#clean up:
unlink $file;

#now update the subversion repository:
#system "svn commit -F trunk/commit.log";
#TODO: Check that the commit succeeded before deleting commit.log!
#system "rm trunk/commit.log";
#system "touch trunk/commit.log";
