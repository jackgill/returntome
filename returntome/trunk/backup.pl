#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Net::SMTP::SSL;
use MIME::Lite;

unlink 'r2m.tar.gz';
system 'tar -cf r2m.tar sandbox';
system 'gzip r2m.tar';
unlink 'r2m.tar';

my $smtp;
if (not $smtp = Net::SMTP::SSL->new('smtp.gmail.com', Port => 465, Debug => 1)) {
	die "Could not connect to server\n";
}
my $from = 'return.to.me.test@gmail.com';
my $password = 'return2me';
my $to = 'return.to.me.receive@gmail.com';
$smtp->auth($from, $password) or die "Authentication failed!\n";

$smtp->mail($from . "\n");
my @recepients = split(/,/, $to);
foreach my $recp (@recepients) {
    $smtp->to($recp . "\n");
}
my $msg = MIME::Lite->new(
    From    => 'return.to.me.test@gmail.com',
    To      => $to,
    #Cc      => 'some@other.com, some@more.com',
    Subject => 'Backup',
    Type    => 'multipart/mixed',
    );

### Add parts (each "attach" has same arguments as "new"):
$msg->attach(
    Type     => 'TEXT',
    Data     => "This is the body. Or a text attachment. Is there a difference?"
    );
$msg->attach(
    Type     => 'application/x-tar-gz',
    Path     => '/home/jack/returntome/r2m.tar.gz',
    Filename => 'r2m.tar.gz',
    Disposition => 'attachment'
   );
my $str = $msg->as_string;
print $str;
#$msg->send('smtp','smtp.gmail.com', Port => 465,Debug=>1,AuthUser=>'return.to.me.test@gmail.com', AuthPass=>'return2me');


$smtp->data();
$smtp->datasend($str);
$smtp->dataend();
$smtp->quit;
