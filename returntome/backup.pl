#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Net::SMTP::SSL;
use MIME::Lite;
use DateTime;

#make the backup
system 'tar -cf r2m.tar trunk';
system 'gzip r2m.tar';
unlink 'r2m.tar';

#declare sender and recipient:
my $from = 'return.to.me.test@gmail.com';
my $password = 'return2me';
my $to = 'jack.m.gill@gmail.com';

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
    Path     => 'r2m.tar.gz',
    Filename => 'r2m.tar.gz',
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
$smtp->quit;

#clean up:
unlink 'r2m.tar.gz';

#TODO: check if message was sent sucessfully?
