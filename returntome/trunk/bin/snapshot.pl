#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use MIME::Lite;
use DateTime;

use Mod::SendMail;

#Create a gzipped tarball of the current source code:
chdir('..') or die "Couldn't cd ..\n";
system 'tar -cf trunk.tar trunk';
system 'gzip trunk.tar';
system 'mv trunk.tar.gz trunk';
chdir('trunk') or die "Couldn't cd to trunk\n";

#Create the MIME::Lite message
my $dt = DateTime->from_epoch( epoch => time, time_zone => 'America/Denver');
my $date = $dt->hms . " " . $dt->mdy;
my $mime = MIME::Lite->new(
    From    => ,
    To      => ,
    Subject => "R2M Snapshot $date",
    Type    => 'multipart/mixed',
    );

#Attach the tarball
$mime->attach(
    Type         => 'application/x-gzip',
    Path        => 'trunk.tar.gz',
    Filename    => 'trunk.tar.gz',
    Disposition => 'attachment'
   );

#Define the mail parameters
my $smtp_server = 'smtp.gmail.com';
my $from_address = 'return.to.me.test@gmail.com';
my $password = 'return2me';
my $to_address = 'return.to.me.backup@gmail.com';
my $mail = $mime->as_string;

#Send the mail
sendMail($smtp_server, $from_address, $password, $to_address, $mail);

system 'rm trunk.tar.gz';

__END__

=head1 NAME

snapshot.pl

=head1 USAGE

C<bin/snapshot.pl>

=head1 DESCRIPTION

Create a gzipped tarball of the current source code, and mail it to a gmail account which stores backups.

=head1 DEPENDENCIES

=over

=item *

MIME::Lite

=item *

DateTime

=back
