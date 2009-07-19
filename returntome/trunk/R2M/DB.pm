package R2M::DB;

use 5.010;

use strict;
use warnings;

use Exporter;
use Carp;
use DBI;

our @ISA = qw(Exporter);
our @EXPORT = qw(&clearMessages &showMessages &getMessages &putMessages);

my $db = 'mysql:database=ReturnToMe';
my $user = 'root';
my $password = 'foo';

sub clearMessages {
    my $dbh = DBI->connect("DBI:$db",$user,$password) or croak "DB: Couldn't connect to database: " . DBI->errstr;
    my $sth = $dbh->prepare("DELETE FROM Messages") or die "Couldn't prepare statement: " . $dbh->errstr; #this returns a table with one column. Each row is the name of a column in $table_name
    $sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
    $dbh->disconnect;
}

sub showMessages {
    my $dbh = DBI->connect("DBI:$db",$user,$password) or croak "DB: Couldn't connect to database: " . DBI->errstr;
    my $sth = $dbh->prepare("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns where TABLE_NAME = 'Messages'") or die "Couldn't prepare statement: " . $dbh->errstr; #this returns a table with one column. Each row is the name of a column in $table_name
    $sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
    my @col_refs = @{ $sth->fetchall_arrayref }; #this is an array of references to arrays
    my @col_names; #this will hold the names of the columns
    for my $col_ref (@col_refs) {
	my @row = @$col_ref; #get the array which is a row in the schema table
	my $col_name = $row[0]; #get the first (and only) column in the row
	push @col_names, $col_name;
    }
    my $format = "%-30s | " x @col_names;
    printf $format,@col_names;
    print "\n","-" x (33*@col_names),"\n";
    
    #Now get the entire table:
    $sth = $dbh->prepare("SELECT * FROM Messages") or die "Couldn't prepare statement: " . $dbh->errstr;
    $sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
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
	my $address = $message{'from'};
	my $subject = $message{'subject'};
	my $body = $message{'body'};
	my $sth = $dbh->prepare("INSERT INTO Messages VALUES ('$uid','$address','$subject','$body');") or croak "DB: Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute() or croak("DB: Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
    }
    $dbh->disconnect;
}

sub getMessages {
    my $dbh = DBI->connect("DBI:$db",$user,$password) or croak "DB: Couldn't connect to database: " . DBI->errstr;    
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
