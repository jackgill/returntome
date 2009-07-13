package R2M::DB;

use 5.010;

use strict;
use warnings;

use Exporter;
use Carp;
use DBI;

our @ISA = qw(Exporter);
our @EXPORT = qw(&getMessages &putMessages);

sub putMessages {
    my $dbh = DBI->connect('DBI:mysql:database=ReturnToMe','root','foo') or croak "DB: Couldn't connect to database: " . DBI->errstr;
    for (@_) {
	my %message = %$_;
	my $uid = $message{'uid'};
	my $address = $message{'from'};
	my $subject = $message{'subject'};
	my $body = $message{'body'};
	my $sth = $dbh->prepare("INSERT INTO Messages VALUES ('$uid','$address','$subject','$body');") or croak "DB: Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
    }
    $dbh->disconnect;
}

sub getMessages {
    $dbh = DBI->connect('DBI:mysql:database=ReturnToMe','root','foo') or croak "DB: Couldn't connect to database: " . DBI->errstr;
    my @messages;
    for (@_) {
	my $uid = $_;
	my $sth = $dbh->prepare("SELECT * FROM Messages WHERE UID = $uid;") or croak "DB: Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
	my @row = $sth->fetchrow_array();
	my %message = (
	    uid => $row[0],
	    from => $row[1],
	    subject => $row[2],
	    body => $row[3],
	);
	push @messages, \%message;
	#delete the message:
	$sth = $dbh->prepare("DELETE FROM Messages WHERE UID = $uid;") or croak "DB: Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
    }
    $dbh->disconnect;
    return @messages;
}

1;
