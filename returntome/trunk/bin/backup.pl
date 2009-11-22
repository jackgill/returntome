#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use MIME::Lite;
use DateTime;
use Net::SMTP::SSL;

die "Usage: $0 (working_copy|repository)\n" unless (scalar @ARGV == 1);

my $mode = $ARGV[0];
my $tarball;
my $subject;

given($mode) {
    when('working_copy') {
        #Create a gzipped tarball of the current source code:
        $tarball = 'trunk.tar.gz';
        $subject = 'Snapshot';
        chdir('..') or die "Couldn't cd ..\n";
        system 'tar -cf trunk.tar trunk';
        system 'gzip trunk.tar';
        system 'mv trunk.tar.gz trunk';
        chdir('trunk') or die "Couldn't cd to trunk\n"
    }
    when('repository') {
        $tarball = 'repository.gz';
        $subject = 'Backup';
        system "svnadmin dump svn > repository";
        system "gzip repository";
    }
    default {
	die "Invalid mode: $mode\n";
    }
}




#Create the MIME::Lite message
my $dt = DateTime->from_epoch( epoch => time, time_zone => 'America/Denver');
my $date = $dt->hms . " " . $dt->mdy;
my $mime = MIME::Lite->new(
    From    => ,
    To      => ,
    Subject => "R2M $subject $date",
    Type    => 'multipart/mixed',
    );

#Attach the tarball
$mime->attach(
    Type         => 'application/x-gzip',
    Path        => $tarball,
    Filename    => $tarball,
    Disposition => 'attachment'
   );

#Define the mail parameters
my $smtp_server = 'smtp.gmail.com';
my $from_address = 'return.to.me.test@gmail.com';
my $password = 'return2me';
my $to_address = 'return.to.me.backup@gmail.com';
my $mail = $mime->as_string;

#Connect to the SMTP server:
my $smtp;
unless ($smtp = Net::SMTP::SSL->new($smtp_server, Port => 465, Debug => 0)) {
    die "Could not connect to SMTP server\n";
}

#Authenticate to the SMTP server:
unless ($smtp->auth($from_address, $password)) {
    die "Could not authenticate to SMTP server\n";
}

#Send the mail
$smtp->mail($from_address . "\n");
$smtp->to($to_address . "\n");
$smtp->data();
$smtp->datasend($mail . "\n");
$smtp->dataend();

#Check the SMTP response:
my $smtp_response = $smtp->message;
unless ($smtp_response =~ /2.0.0 OK/) {
    $smtp->quit;
    die "Failed to send mail: $smtp_response\n";
}
$smtp->quit;

unlink $tarball;

__END__

=head1 NAME

backup.pl

=head1 USAGE

C<bin/snapshot.pl (working_copy|repository)>

=head1 DESCRIPTION

Create a gzipped tarball, and mail it to a gmail account which stores backups.

Mode:

=over

=item *

working_copy

Make a tarball of the current working copy.

=item *

repository

Make a tarball of the entire repository.

=back

=head1 DEPENDENCIES

=over

=item *

MIME::Lite

=item *

DateTime

=item *

Net::SMTP::SSL

=back
