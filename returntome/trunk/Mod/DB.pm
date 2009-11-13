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
our @EXPORT = qw(&connect &disconnect &getSchemas &resetDB &putUnparsedMessages &putParsedMessages &getMessageByUID &deleteMessageByUID &getMessagesByTime &deleteMessagesByTime &getUID &getTable);

=head1 NAME

    DB.pm

=cut

=head1 SYNOPSIS

    &Mod::DB::connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});

    &putMessages($table_name,@messages);
    my %message = &getMessageByUID('UnparsedMessages','000000000');
    my @messages = &getMessagesByTime(time);

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
    $dbh = DBI->connect("DBI:$db",$user,$pass,{PrintError => 0}) or $logger->error("DB: Couldn't connect to database: " . DBI->errstr); 
}

=item disconnect

    Disconnect from the database.

=cut

sub disconnect {
    $sth->finish if $sth;
    $dbh->disconnect;
    $logger->debug("Disconnected from database.");
}

=item sql(statement)

    Execute a generic SQL statement. The text of the statement is sent to the logger.

=cut

sub sql {
    my $statement = shift;
    $sth = $dbh->prepare($statement) or $logger->error("Error preparing statement " . $sth->{Statement} . ": " . $sth->errstr);
    $sth->execute() or $logger->error("Error executing statement " . $sth->{Statement} . ": " . $sth->errstr);
}

=item getSchemas

    Get the schemas for the various database tables.
    Arguments: None.
    Returns: A hashref whose referent maps table names to strings describing the columns suitable for use in a MAKE TABLE statement.

=cut

sub getSchemas {
    #Parsed messages have a return time:
    my $parsed_schema = "(uid INTEGER(9) ZEROFILL PRIMARY KEY, return_time INTEGER(10),mail LONGBLOB)";
    #Unparsed messages do not:
    my $unparsed_schema = "(uid INTEGER(9) ZEROFILL PRIMARY KEY, mail LONGBLOB)";
    my %schemas = (
	'ParsedMessages' => $parsed_schema,
	'SentMessages' => $parsed_schema,
	'UnsentMessages' => $parsed_schema,
	'UnparsedMessages' => $unparsed_schema,
	'RawMessages' => $unparsed_schema,
	'UID' => "(uid INTEGER(9) ZEROFILL)",
	);
    return \%schemas
} 

=item resetDB

    Drop all tables, then create all tables.
    Arguments: None.
    Returns: None.

=cut

sub resetDB {
    my %schemas = %{ &getSchemas };
    for my $table (keys %schemas) {
	&sql("DROP TABLE IF EXISTS $table"); 
	&sql("CREATE TABLE $table $schemas{$table}");
    }
    &sql("INSERT INTO UID VALUES ('000000000');");
}

=item putParsedMessages(table name, messages)

    Insert a list of messages into the specified table.
    Arguments: The first argument is the name of the table. All subsequent arguments should be message hashrefs.
    Returns: None.

=cut

sub putParsedMessages {
    my $table = shift;
    for (@_) {
	#Get message and extract fields:
	my %message = %$_;
	my $uid = $message{'uid'};
	my $return_time = $message{'return_time'};
	$return_time = 0 unless $return_time;
	my $mail = $message{'mail'};

	#Insert message into table using parameterized query:
	my $put_msg = $dbh->prepare("INSERT INTO $table VALUES (?,?,?);");
	if($put_msg) {
	    $put_msg->execute($uid,$return_time,$mail) or $logger->error("Error executing statement " . $put_msg->{Statement} . ": " . $put_msg->errstr);
	} else  {
	    $logger->error("Error preparing statement " . $put_msg->{Statement} . ": " . $put_msg->errstr);
	}
    }
}

sub putUnparsedMessages {
    my $table = shift;
    for (@_) {
	#Get message and extract fields:
	my %message = %$_;
	my $uid = $message{'uid'};
	my $mail = $message{'mail'};

	#Insert message into table using parameterized query:
	my $put_msg = $dbh->prepare("INSERT INTO $table VALUES (?,?);");
	if($put_msg) {
	    $put_msg->execute($uid,$mail) or $logger->error("Error executing statement " . $put_msg->{Statement} . ": " . $put_msg->errstr);
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
    my %message = %{ $sth->fetchrow_hashref };
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
    
    my $hash_ref;
    while ($hash_ref = $sth->fetchrow_hashref) {
	my %message = %$hash_ref;
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

    #Get the entire table:
    &sql("SELECT * FROM $table_name");
    my @table = @{ $sth->fetchall_arrayref }; #this is an array of array refs
 
    #Get the column names:
    #this returns a table with one column. Each row is the name of a column in $table_name
    &sql("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns where TABLE_NAME = '$table_name'");  
    my @rows = @{ $sth->fetchall_arrayref }; #this is an array of array refs
    my @col_names; 
    push @col_names, $_->[0] for @rows; #Get the first column of the row

    #Add the column names to the table:
    unshift @table, \@col_names;

    return \@table;
}

=back

=cut

1;
