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
our @EXPORT = qw(&connect &disconnect &makeTables &clearTables &showTables &putMessages &getMessages &getMessagesToSend &getUID &getTable &getSchemas &purgeSentMessages);

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

my @message_tables = ('UnparsedMessages','ParsedMessages','SentMessages','UnsentMessages'); #EVIL violation of DRY
sub getSchemas {
    my $message_schema = "(uid INTEGER(9) ZEROFILL, return_time INTEGER(10),mail BLOB)";
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
    my %schemas = %{ &getSchemas };
    for my $table (keys %schemas) {
	&sql("DROP TABLE $table");
	&sql("CREATE TABLE $table $schemas{$table}");
    }
    &sql("INSERT INTO UID VALUES ('000000000');");
}

sub clearTables {
    for (@message_tables) {
	&sql("DELETE FROM $_");
    }
    &sql("UPDATE UID SET uid = 000000000;");
}

sub showTables {
    my $key = shift;
    for (@message_tables) {
	print "$_:\n";
	&showTable($_,$key);
    }
}
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

sub putMessages {
    my $table = shift;
    for (@_) {
	my %message = %$_;
	my $uid = $message{'uid'};
	my $return_time = $message{'return_time'};
	$return_time = 0 unless $return_time;
	my $mail = $message{'mail'};
	#$logger->debug("INSERT INTO $table VALUES ('$uid','$return_time','$mail');");
	my $put_msg = $dbh->prepare("INSERT INTO $table VALUES (?,?,?);");
	if($put_msg) {
	$put_msg->execute($uid,$return_time,$mail) or $logger->error("Error executing statement " . $put_msg->{Statement} . ": " . $put_msg->errstr);
	} else  {
	    $logger->error("Error preparing statement " . $put_msg->{Statement} . ": " . $put_msg->errstr);
	}

    }
}

sub getMessages {
    my $table = shift;
    #TODO: error checking: make sure $table is a valid table name
    my @uids = @_;
    my @messages;
    for my $uid (@uids) {
	&sql("SELECT * FROM $table WHERE UID = $uid;");
	my @row = $sth->fetchrow_array();
	my %message = (
	    uid => $row[0],
	    return_time => $row[1],
	    mail => $row[2],
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
	    mail => $row[2],
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
