#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use MIME::Lite;
use DateTime;
use Net::SMTP::SSL;
use Net::SSH qw(sshopen2);

die "Usage: $0 (snapshot|repository)\n" unless (scalar @ARGV == 1);

my $mode = $ARGV[0];
my $file;
my $subject;

given($mode) {
    when('snapshot') {
        #Create a gzipped tarball of the current source code:
        $file = 'trunk.tar.gz';
        $subject = 'Snapshot';
        chdir('..') or die "Couldn't cd ..\n";
        system 'tar -cf trunk.tar trunk';
        system 'gzip trunk.tar';
        system 'mv trunk.tar.gz trunk';
        chdir('trunk') or die "Couldn't cd to trunk\n"
    }
    when('repository') {
        $file = 'repository.gz';
        $subject = 'Backup';
        sshopen2('rtmadmin@rtmserver', *READER, *WRITER, 'svnadmin dump --quiet svn | gzip') || die "ssh: $!";

        open(my $out, '>', $file) or die "Couldn't open $file: $!\n";
        while (<READER>) {
            print $out $_;
        }
        close(READER);
        close(WRITER);
        close $out;
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
    Path        => $file,
    Filename    => $file,
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

unlink $file;

print "Backup successful.\n";

__END__

=head1 NAME

backup.pl -- Create a backup, and mail it to a gmail account.

=head1 USAGE

C<bin/backup.pl (snapshot|repository)>

=head1 DESCRIPTION

A 'snapshot' backup  A 'repository' backup  In either case, the gzipped file is then mailed as an attachment to the gmail backup accoun.t

Mode:

=over

=item B<snapshot>

Creates a gzipped tarball of the trunk of the local working copy.

=item B<repository>

ssh's into the subversion repository host, dumps the repository as a plain text file and pipes it through gzip.

=back

=head1 DEPENDENCIES

=over

=item *

MIME::Lite

=item *

DateTime

=item *

Net::SMTP::SSL

=item *

Net::SSH

=back
