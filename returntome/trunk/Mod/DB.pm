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
our @EXPORT = qw(&connect &disconnect &getSchemas &resetDB &createEntry &storeMail &retrieveMail &deleteRow &getMessagesToReturn &markAsSent);

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
    $dbh->do("INSERT INTO Messages VALUES (NULL, ?, NOW(), ?, NULL)",undef, $address, $return_time);
    my $uid = $dbh->last_insert_id(undef,undef,undef,undef);

    return $uid;
}

sub storeMail {
    my ($table, $uid, $mail, $key) = @_;
    $dbh->do("INSERT INTO $table VALUES ($uid, AES_ENCRYPT(?,?))",undef,$mail,$key);
}

sub retrieveMail {
    my ($table, $uid, $key) = @_; 

    my $mail = $dbh->selectrow_array("SELECT AES_DECRYPT((SELECT mail FROM $table WHERE uid = $uid),'$key')");

    return $mail;
}

sub deleteRow {
    my $table_name = shift;
    my $uid = shift;
    $dbh->do("DELETE FROM $table_name WHERE UID = $uid;");
}

sub getMessagesToReturn {
    my $key = shift;
    my @rows = $dbh->selectall_arrayref("SELECT Messages.uid, AES_DECRYPT(ParsedMail.mail, '$key') AS mail FROM Messages INNER JOIN ParsedMail WHERE Messages.uid = ParsedMail.uid AND Messages.return_time < NOW()", { Slice => {} });
    return @rows
}

sub markAsSent {
    my $uid = shift;
    $dbh->do("UPDATE Messages SET sent_time = NOW() WHERE uid = '$uid'");
}

=item getTable(table name) 

    Get a 2D array represent the specified table. No decryption is performed.
    Arguments: Table name
    Returns: An array ref. Each element of the referent is an array ref to a row.

=cut



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

=item deleteMessageByUID(table name, uid)

    Delete the specified message from the specified table.
    Arguments: table name, UID.
    Returns: None.

=cut

=back

=cut
