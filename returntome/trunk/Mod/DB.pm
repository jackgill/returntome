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
our @EXPORT = qw(&connect &disconnect &getSchemas &resetDB &createEntry &storeMail &retrieveMail &getTable);

my $dbh; #DBI database handle
my $logger = Log::Log4perl->get_logger();

sub connect {
    my ($server, $user, $pass) = @_;
    $dbh = DBI->connect("DBI:mysql:database=$server",$user,$pass,{PrintError => 0, RaiseError => 1});
}

sub disconnect {
    $dbh->disconnect;
}

sub getSchemas {
    my %schemas = (
	Messages => 
	"(" .
	"uid INTEGER(9) ZEROFILL NOT NULL AUTO_INCREMENT" . 
	", " .
	"address VARCHAR(320) NULL" . 
	", " .
	"received_time DATETIME" . 
	", " .
	"return_time DATETIME" . 
	", " .
	"sent_time DATETIME" . 
	", " .	
	"PRIMARY KEY (uid)" .
	")", 
	RawMail => 
	"(" .
	"uid INTEGER(9) ZEROFILL NOT NULL" 
	. ", " .
	"mail MEDIUMBLOB NOT NULL" . 
	", " .
	"PRIMARY KEY (uid)" .
	")",
	ParsedMail => 
	"(" .
	"uid INTEGER(9) ZEROFILL NOT NULL" . 
	", " .
	"mail MEDIUMBLOB NOT NULL" . 
	", " .
	"PRIMARY KEY (uid)" .
	")",
	);
    return \%schemas
} 

sub resetDB {
    my %schemas = %{ &getSchemas };
    for my $table (keys %schemas) {
	$dbh->do("DROP TABLE IF EXISTS $table"); 
	$dbh->do("CREATE TABLE $table $schemas{$table}");
    }
}

sub createEntry {
    my ($address, $return_time) = @_;

    #Create new entry in Messages table using parameterized query:
    my $uid;
    $dbh->do("INSERT INTO Messages VALUES (NULL, '$address', NOW(), '$return_time', NULL)");
    my $uid = $dbh->last_insert_id(undef,undef,undef,undef);

    return $uid;
}

sub storeMail {
    my ($table, $uid, $mail, $key) = @_;

    #Encrypt mail and insert into table using parameterized query:

    my $sth = $dbh->prepare("INSERT INTO $table VALUES (?, AES_ENCRYPT(?,?));");
    $sth->execute($uid,$mail,$key) 
}

sub retrieveMail {
    my ($table, $uid, $key) = @_; 
    
    my $sth = $dbh->prepare("SELECT AES_DECRYPT((SELECT mail FROM $table WHERE uid = $uid),'$key')");
    $sth->execute();
    my $mail = $sth->fetchrow_array();

    return $mail;
}

=item deleteMessageByUID(table name, uid)

    Delete the specified message from the specified table.
    Arguments: table name, UID.
    Returns: None.

=cut

sub deleteMessageByUID {
    my $table_name = shift;
    my $uid = shift;
    $dbh->do("DELETE FROM $table_name WHERE UID = $uid;");
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

    #&sql("SELECT * FROM $table_name WHERE return_time < $return_time;");
    
    my $hash_ref;
    #while ($hash_ref = $sth->fetchrow_hashref) {
#	my %message = %$hash_ref;
#	push @messages, \%message;
#    }

    return @messages;
}

=item getTable(table name) 

    Get a 2D array represent the specified table. No decryption is performed.
    Arguments: Table name
    Returns: An array ref. Each element of the referent is an array ref to a row.

=cut

sub getTable {
    my $table_name = shift;

    #Get the entire table:
#    &sql("SELECT * FROM $table_name");
#    my @table = @{ $sth->fetchall_arrayref }; #this is an array of array refs
 
    #Get the column names:
    #this returns a table with one column. Each row is the name of a column in $table_name
#    &sql("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns where TABLE_NAME = '$table_name'");  
#    my @rows = @{ $sth->fetchall_arrayref }; #this is an array of array refs
#    my @col_names; 
#    push @col_names, $_->[0] for @rows; #Get the first column of the row

#    #Add the column names to the table:
#    unshift @table, \@col_names;

#    return \@table;
}



1;

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

=item connect(database name, user name, password)

    Connect to the database.

=cut

=item disconnect

    Disconnect from the database.

=cut

=item getSchemas

    Get the schemas for the various database tables.
    Arguments: None.
    Returns: A hashref whose referent maps table names to strings describing the columns suitable for use in a MAKE TABLE statement.

=cut

=item resetDB

    Drop all tables, then create all tables.
    Arguments: None.
    Returns: None.

=cut

=item storeMail

=cut

=item retrieveMail

=cut

=back

=cut
