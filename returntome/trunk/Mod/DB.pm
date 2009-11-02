package Mod::DB;

use 5.010;

use strict;
use warnings;

use Exporter;
use DBI;
use Log::Log4perl;
use Carp;

use Mod::Crypt;

our @ISA = qw(Exporter);
our @EXPORT = qw(&connect &disconnect &getSchemas &makeTables &clearTables &showTables &putMessages &getMessageByUID &deleteMessageByUID &getMessagesByTime &deleteMessagesByTime &getUID &getTable);

=head1 NAME

    DB.pm

=cut

=head1 SYNOPSIS

    &Mod::DB::connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});
    &putMessages($table_name,@messages);
    my @messages = &getMessages('UnparsedMessages','000000000','000000001');
    my @messages_to_send = &getMessagesToSend(time);
    &Mod::DB::disconnect;

=cut

=head1 DESCRIPTION

    This module is the interface to the database.

=cut

=head1 FUNCTIONS

=over 

=cut


#Global variables...ugh
my $sth; #DBI statement handle
my $dbh; #DBI database handle
my $logger = Log::Log4perl->get_logger();

=item connect(database name, user name, password)

    Connect to the database.

=cut

sub connect {
    my ($db, $user, $pass) = @_;
    $dbh = DBI->connect("DBI:$db",$user,$pass) or $logger->error("DB: Couldn't connect to database: " . DBI->errstr); 
    $logger->debug("Connected to database.");
}

=item disconnect

    Disconnect from the database.

=cut

sub disconnect {
    $sth->finish;
    $dbh->disconnect;
    $logger->debug("Disconnected from database.");
}

=item sql(statement)

    Execute a generic SQL statement. The text of the statement is sent to the logger.

=cut

sub sql {
    my $statement = shift;
    $logger->debug($statement);
    $sth = $dbh->prepare($statement) or $logger->error("Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
    $sth->execute() or $logger->error("Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
}

=item getSchemas

    Get the schemas for the various database tables.
    Arguments: None.
    Returns: A hashref whose referent maps table names to strings describing the columns suitable for use in a MAKE TABLE statement.

=cut

my @message_tables = ('UnparsedMessages','ParsedMessages','SentMessages','UnsentMessages'); #EVIL violation of DRY
sub getSchemas {
    my $message_schema = "(uid INTEGER(9) ZEROFILL PRIMARY KEY, return_time INTEGER(10),mail LONGBLOB)";
    my %schemas = (
	'ParsedMessages' => $message_schema,
	'UnparsedMessages' => $message_schema,
	'SentMessages' => $message_schema,
	'UnsentMessages' => $message_schema,
	'UID' => "(uid INTEGER(9) ZEROFILL)",
	);
    return \%schemas
} 


=item makeTables

    Delete all existing tables and create new ones.
    Arguments: None.
    Returns: None.

=cut

sub makeTables {
    my %schemas = %{ &getSchemas };
    for my $table (keys %schemas) {
	&sql("DROP TABLE $table"); #TODO add "if exists $table"
	&sql("CREATE TABLE $table $schemas{$table}");
    }
    &sql("INSERT INTO UID VALUES ('000000000');");
}

=item clearTables

    DEPRECATED as redundant with &makeTables.
    Clear all tables.
    Arguments: None.
    Returns: None.

=cut

sub clearTables {
    for (@message_tables) {
	&sql("DELETE FROM $_");
    }
    &sql("UPDATE UID SET uid = 000000000;");
}

=item showTables(key)

    DEPRECATED in favor of cgi/viewDB (&Mod::DB::getTable)
    Print the contents of all the message tables to STDOUT. Calls &showTable.
    Arguments: Encryption key
    Returns: None.

=cut

sub showTables {
    my $key = shift;
    for (@message_tables) {
	print "$_:\n";
	&showTable($_,$key);
    }
}

=item showTable(table name, encryption key)

    DEPRECATED in favor of cgi/viewDB (&Mod::DB::getTable)
    Print the contents of the specified table to STDOUT.
    Arguments: Table name, encryption key.
    Returns: None.

=cut

use Text::Wrap;
sub showTable {
    my $table = shift;
    my $key = shift;

    #Get the column names:
    #Get a table with one column. Each row is the name of a column in $table
    &sql("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns where TABLE_NAME = '$table'");  
    my @col_refs = @{ $sth->fetchall_arrayref }; #this is an array of references to arrays
    my @col_names; #this will hold the names of the columns
    for my $col_ref (@col_refs) {
	my @row = @$col_ref; #get the array which is a row in the schema table
	my $col_name = $row[0]; #get the first (and only) column in the row
	push @col_names, $col_name;
    }

    #Print the headers:
    my $format = "%-9s | %-10s | %-60s\n";
    printf $format,@col_names;
    print "-" x 88,"\n";

    #Now get the entire table:
    &sql("SELECT * FROM $table");
    my @row;
    while (@row = $sth->fetchrow_array()) {
	my $cipher_last = pop @row;
	my $plain_last = &decrypt($key,$cipher_last);
	$Text::Wrap::columns = 60;
	my $wrapped_last =  wrap('', ' ' x 25, $plain_last);
	printf $format,@row, $wrapped_last;
    }
}

=item putMessages(table name, messages)

    Insert a list of messages into the specified table.
    Arguments: The first argument is the name of the table. All subsequent arguments should be message hashrefs.
    Returns: None.

=cut

sub putMessages {
    my $table = shift;
    for (@_) {
	my %message = %$_;
	my $uid = $message{'uid'};
	my $return_time = $message{'return_time'};
	$return_time = 0 unless $return_time;
	my $mail = $message{'mail'};
	my $put_msg = $dbh->prepare("INSERT INTO $table VALUES (?,?,?);");
	if($put_msg) {
	$put_msg->execute($uid,$return_time,$mail) or $logger->error("Error executing statement " . $put_msg->{Statement} . ": " . $put_msg->errstr);
	} else  {
	    $logger->error("Error preparing statement " . $put_msg->{Statement} . ": " . $put_msg->errstr);
	}

    }
}

=item getMessageByUID(table name, uid)

    Retrieve the message with the specified UID from the specified table.
    Arguments: The first argument is the name of the table. All subsequent arguments should be UIDs.
    Returns: The message hash as a list.

=cut

sub getMessageByUID {
    my $table_name = shift;
    my $uid = shift;

    &sql("SELECT * FROM $table_name WHERE UID = $uid;");
    my @row = $sth->fetchrow_array();
    my %message = &rowToMessage(@row);
    return %message;
}

=item deleteMessageByUID(table name, uid)

    Delete the specified message from the specified table.
    Arguments: table name, UID.
    Returns: None.

=cut

sub deleteMessageByUID {
    my $table_name = shift;
    my $uid = shift;
    &sql("DELETE FROM $table_name WHERE UID = $uid;");
}

=item getMessagesByTime(table name, time)

    Retrieve all messages from the specified table whose return time is less than the specified time.
    Arguments: Table name, time in epoch seconds.
    Returns: A list of message hashrefs.

=cut

sub getMessagesByTime {
    my $table_name = shift;
    my $return_time = shift;

    my @messages;

    &sql("SELECT * FROM $table_name WHERE return_time < $return_time;");
    
    my @row;
    while (@row = $sth->fetchrow_array()) {
	my %message = &rowToMessage(@row);
	push @messages, \%message;
    }

    return @messages;
}

=item deleteMessagesByTime(table name, time)
	
    Delete messages from the specified table whose return time is less than the given time.
    Arguments: Table name, time in epoch seconds.
    Returns: None.

=cut

sub deleteMessagesByTime {
    my $table_name = shift;
    my $delete_time = shift;
    &sql("DELETE FROM $table_name WHERE return_time < $delete_time;");    
}

=item rowToMessage(row)

    Convert a row from a message table to a message hash.
    Arguments: The row, as a list.
    Returns: The message hash, as a list.

=cut

sub rowToMessage {
    my @row = @_;
    my %message = (
	uid => $row[0],
	return_time => $row[1],
	mail => $row[2],
	);
    return %message;
}

=item getUID

    Get a Unique Identifier (UID): A nine digit integer guaranteed to be unique.
    Arguments: None.
    Returns: the UID.
  
=cut

sub getUID {
    &sql("SELECT uid FROM UID;");
    my @row = $sth->fetchrow_array();
    &sql("update UID SET uid = uid + 1;");
    return $row[0];
}

=item getTable(table name) 

    Get a 2D array represent the specified table. No decryption is performed.
    Arguments: Table name
    Returns: An array ref. Each element of the referent is an array ref to a row.

=cut

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

=back

=cut

1;
