package Mod::DB;

use 5.010;

use strict;
use warnings;

use Exporter;
use Carp;
use DBI;

our @ISA = qw(Exporter);
our @EXPORT = qw(&clearMessages &showMessages &getMessages &putMessages &getReturnTimes &makeTable);


my $sth;
my %config;
open(CONFIG,"<conf/db.conf") or die "Couldn't open conf/db.conf: $!\n";
while (<CONFIG>) {
    chomp;                  # no newline
    s/#.*//;                # no comments
    s/^\s+//;               # no leading white
    s/\s+$//;               # no trailing white
    next unless length;     # anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);
    $config{$var} = $value;
}

#check that these get set correctly!
my $db = "mysql:database=" . $config{database};
my $user = $config{username};
my $password = $config{password};

sub makeTable {
    my $dbh = DBI->connect("DBI:$db",$user,$password) or croak "DB: Couldn't connect to database: " . DBI->errstr;
    
    $sth = $dbh->prepare("DROP TABLE Messages") or croak("DB: Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
    $sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
    #TODO declare return_time as in integer with the appropriate length for epoch seconds
    $sth = $dbh->prepare("CREATE TABLE Messages (uid INTEGER(9) ZEROFILL, return_time VARCHAR(100),address VARCHAR(320),subject BLOB,body BLOB)") or croak("DB: Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr); 
    $sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
    $dbh->disconnect;
}
sub clearMessages {
    my $dbh = DBI->connect("DBI:$db",$user,$password) or croak "DB: Couldn't connect to database: " . DBI->errstr;
    $sth = $dbh->prepare("DELETE FROM Messages") or croak("DB: Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
    $sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);    
    $dbh->disconnect;
}
sub getReturnTimes {
    my $dbh = DBI->connect("DBI:$db",$user,$password) or croak "DB: Couldn't connect to database: " . DBI->errstr;
    $sth = $dbh->prepare("SELECT uid, return_time FROM Messages") or croak("DB: Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
    $sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);    
    my @rows = @{ $sth->fetchall_arrayref };
    $dbh->disconnect;
    return @rows;
}
sub showMessages {
    my $dbh = DBI->connect("DBI:$db",$user,$password) or croak "DB: Couldn't connect to database: " . DBI->errstr;
    $sth = $dbh->prepare("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns where TABLE_NAME = 'Messages'") or croak("DB: Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);  #this returns a table with one column. Each row is the name of a column in $table_name
    $sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);    
    my @col_refs = @{ $sth->fetchall_arrayref }; #this is an array of references to arrays
    my @col_names; #this will hold the names of the columns
    for my $col_ref (@col_refs) {
	my @row = @$col_ref; #get the array which is a row in the schema table
	my $col_name = $row[0]; #get the first (and only) column in the row
	push @col_names, $col_name;
    }
    my $format = "%-20s | " x @col_names;
    printf $format,@col_names;
    print "\n","-" x (33*@col_names),"\n";
    
    #Now get the entire table:
    $sth = $dbh->prepare("SELECT * FROM Messages") or croak("DB: Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
    $sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
    my @row;
    while (@row = $sth->fetchrow_array()) {
	printf $format,@row;
	print "\n";
    }
    $dbh->disconnect;
}
sub putMessages {
    my $dbh = DBI->connect("DBI:$db",$user,$password) or croak "DB: Couldn't connect to database: " . DBI->errstr;
    for (@_) {
	my %message = %$_;
	my $uid = $message{'uid'};
	my $return_time = $message{'return_time'};
	my $address = $message{'address'};
	my $subject = $message{'subject'};
	my $body = $message{'body'};
	$sth = $dbh->prepare("INSERT INTO Messages VALUES ('$uid','$return_time','$address','$subject','$body');") or croak("DB: Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
	$sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
    }
    $dbh->disconnect;
}

sub getMessages {
    my $dbh = DBI->connect("DBI:$db",$user,$password) or croak "DB: Couldn't connect to database: " . DBI->errstr;    
    my @messages;
    for (@_) {
	my $uid = $_;
	$sth = $dbh->prepare("SELECT * FROM Messages WHERE UID = $uid;") or croak("DB: Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
	$sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
	my @row = $sth->fetchrow_array();
	my %message = (
	    uid => $row[0],
	    return_time => $row[1],
	    address => $row[2],
	    subject => $row[3],
	    body => $row[4],
	);
	push @messages, \%message;
	#delete the message:
	$sth = $dbh->prepare("DELETE FROM Messages WHERE UID = $uid;") or croak("DB: Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
	$sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
    }
    $dbh->disconnect;
    return @messages;
}

1;
