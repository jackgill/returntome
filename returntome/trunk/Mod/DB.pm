package Mod::DB;

use 5.010;

use strict;
use warnings;

use Exporter;
use DBI;
use Log::Log4perl;

our @ISA = qw(Exporter);
our @EXPORT = qw(&connect &disconnect &makeTables &clearTables &showTables &putMessages &getMessages &getMessagesToSend);
use Carp;

#Global variables...ugh
my $sth; #DBI statement handle
my $dbh; #DBI database handle
my $logger = Log::Log4perl->get_logger();

sub connect {
    my %config; #stores config variables
    #read config file:
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
    #TODO: check that these get set correctly!
    my $db = "mysql:database=" . $config{database};
    my $user = $config{username};
    my $password = $config{password};
    $dbh = DBI->connect("DBI:$db",$user,$password) or $logger->error("DB: Couldn't connect to database: " . DBI->errstr); 
    $logger->debug("Connected to database.");
}

sub disconnect {
    $dbh->disconnect;
    $logger->debug("Disconnected from database.");
}

sub sql {
    my $statement = shift;
    $logger->debug($statement);
    $sth = $dbh->prepare($statement) or $logger->error("Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
    $sth->execute() or $logger->error("Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
}

#TODO: Pass this in as an argument?
my @tables = ('ParsedMessages','UnparsedMessages','SentMessages','UnsentMessages');

sub makeTables {
    #TODO: declare return_time as in integer with the appropriate length for epoch seconds
    my $messages_schema = "(uid INTEGER(9) ZEROFILL, return_time VARCHAR(100),address VARCHAR(320),subject BLOB,body BLOB)";
    for my $table (@tables) {
	&sql("DROP TABLE $table");
	&sql("CREATE TABLE $table $messages_schema");
    }
}
sub clearTables {
    for my $table (@tables) {
	&sql("DELETE FROM $table");
    }
}

sub showTables {
    for my $table (@tables) {
	print "$table:\n";
	&showTable($table);
    }
}
sub showTable {
    my $table = shift;
    &sql("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns where TABLE_NAME = '$table'");  #this returns a table with one column. Each row is the name of a column in $table_name
    my @col_refs = @{ $sth->fetchall_arrayref }; #this is an array of references to arrays
    my @col_names; #this will hold the names of the columns
    for my $col_ref (@col_refs) {
	my @row = @$col_ref; #get the array which is a row in the schema table
	my $col_name = $row[0]; #get the first (and only) column in the row
	push @col_names, $col_name;
    }
    my $format = "%-20s | " x @col_names;
    printf $format,@col_names;
    print "\n","-" x (23*@col_names),"\n";
    
    #Now get the entire table:
    &sql("SELECT * FROM $table");
    my @row;
    while (@row = $sth->fetchrow_array()) {
	printf $format,@row;
	print "\n";
    }
}
sub putMessages {
    my $table = shift;
    for (@_) {
	my %message = %$_;
	my $uid = $message{'uid'};
	my $return_time = $message{'return_time'};
	my $address = $message{'address'};
	my $subject = $message{'subject'};
	my $body = $message{'body'};
	&sql("INSERT INTO $table VALUES ('$uid','$return_time','$address','$subject','$body');");
    }
}

sub getMessages {
    my $table = shift;
    my @uids = @_;
    my @messages;
    for my $uid (@uids) {
	&sql("SELECT * FROM $table WHERE UID = $uid;");
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
	&sql("DELETE FROM $table WHERE UID = $uid;");
    }
    return @messages;
}

sub getMessagesToSend {
    my $return_time = shift;

    my @messages;

    &sql("SELECT * FROM ParsedMessages WHERE return_time < $return_time;");
    
    my @row;
    while (@row = $sth->fetchrow_array()) {
	my %message = (
	    uid => $row[0],
	    return_time => $row[1],
	    address => $row[2],
	    subject => $row[3],
	    body => $row[4],
	    );
	push @messages, \%message;
    }
    #delete the messages:
    &sql("DELETE FROM ParsedMessages WHERE return_time < $return_time;");
    #TODO: Is there a more efficient way to do this?

    return @messages;
}
1;
