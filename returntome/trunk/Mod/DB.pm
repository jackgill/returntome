package Mod::DB;

use 5.010;

use strict;
use warnings;

use Exporter;
use DBI;
use Log::Log4perl;

our @ISA = qw(Exporter);
our @EXPORT = qw(&connect &disconnect &makeTables &clearTables &showTables &putMessages &getMessages &getMessagesToSend &getUID &getTable &getSchemas);
use Carp;

#Global variables...ugh
my $sth; #DBI statement handle
my $dbh; #DBI database handle
my $logger = Log::Log4perl->get_logger();

sub connect {
    my ($db, $user, $pass) = @_;
    $dbh = DBI->connect("DBI:$db",$user,$pass) or $logger->error("DB: Couldn't connect to database: " . DBI->errstr); 
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

sub getSchemas {
    my $message_schema = "(uid INTEGER(9) ZEROFILL, return_time INTEGER(10),address VARCHAR(320),mail BLOB)";
    my %schemas = (
	'ParsedMessages' => $message_schema,
	'UnparsedMessages' => $message_schema,
	'SentMessages' => $message_schema,
	'UnsentMessages' => $message_schema,
	'UID' => "(uid INTEGER(9) ZEROFILL)",
	);
    return \%schemas
} 

sub makeTables {
    my %schemas = %{ &getTables };
    for my $table (keys %schemas) {
	&sql("DROP TABLE $table");
	&sql("CREATE TABLE $table $schemas{$table}");
    }
}

sub clearMessageTables {
    my @tables = ('UnparsedMessages,','ParsedMessages','SentMessages','UnsentMessages'); #EVIL violation of DRY
    for my $table (@tables) {
	&sql("DELETE FROM $table");
    }
    &resetUID;
}

sub resetUID {
    &sql("UPDATE UID SET uid = 000000000;");
}

sub showTables {
    my @tables = keys %{ &getSchemas };
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
	$return_time = 0 unless $return_time;
	my $address = $message{'address'};
	my $mail = $message{'mail'};
	&sql("INSERT INTO $table VALUES ('$uid','$return_time','$address','$mail');");
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
	    mail => $row[3],
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
	    mail => $row[3],
	    );
	push @messages, \%message;
    }
    #delete the messages:
    &sql("DELETE FROM ParsedMessages WHERE return_time < $return_time;");
    #TODO: Is there a more efficient way to do this?

    return @messages;
}

sub purgeSentMessages {
    my $purge_time = shift;
    &sql("DELETE FROM SentMessages WHERE return_time < $purge_time;");    
}

sub getUID {
    &sql("SELECT * FROM UID;");
    my @row = $sth->fetchrow_array();
    &sql("update UID SET uid = uid + 1;");
    #return sprintf "%09d",$row[0];
    return $row[0];
}

sub getTable {
    my $table_name = shift;
    my @table;
    
    #this returns a table with one column. Each row is the name of a column in $table_name
    &sql("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns where TABLE_NAME = '$table_name'");  
    my @col_refs = @{ $sth->fetchall_arrayref }; #this is an array of references to arrays
    my @col_names; #this will hold the names of the columns
    for my $col_ref (@col_refs) {
	my @row = @$col_ref; #get the array which is a row in the schema table
	my $col_name = $row[0]; #get the first (and only) column in the row
	push @col_names, $col_name;
    }
    push @table, \@col_names;

    #Now get the entire table:
    &sql("SELECT * FROM $table_name");
    my @row;
    while (@row = $sth->fetchrow_array()) {
	my @this_row = @row;
	push @table, \@this_row;
    }
    return \@table;
}

1;
