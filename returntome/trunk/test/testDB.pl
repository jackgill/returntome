#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use DBI;

use Mod::Test;
use Mod::Conf;
use Mod::Crypt;

#Conf variables:
my $key_digest = 'conf/key_digest';
my $conf_file = "conf/talaria.conf";

#Get encryption key:
my $key = &getCheckedKey($key_digest);

#Read encrypted conf file:
my %conf = %{ &getConf($conf_file, $key) };

#Connect to DB:
my $dbh = DBI->connect(
    "DBI:mysql:database=$conf{db_server}",
    $conf{db_user},
    $conf{db_pass},
    {PrintError => 0, RaiseError => 1}
);

#Run tests:
populateDB();

#Disconnect from the DB:
$dbh->disconnect();

#############################################33
#Testing subroutines

sub populateDB {
    #Prepare SQL statements:
    my $create_entry = $dbh->prepare("INSERT INTO Messages VALUES (NULL, ?, NOW(), ?, NULL)");
    my $store_raw = $dbh->prepare("INSERT INTO RawMail VALUES (?, AES_ENCRYPT(?,?))");

    #Generate messages:
    my @messages = &createMessages(2,2,'foo@bar.com');

    for my $message (@messages) {
	#Unpack message:
	my $mail = $message->{mail};
	my $return_time = $message->{return_time};
	my $address = $message->{address};

	#Create a new entry in Messages and store raw mail:
	$create_entry->execute($address, $return_time);
	my $uid = $dbh->last_insert_id(undef,undef,undef,undef);
	$store_raw->execute($uid, $mail, $key);
    }

    #Should fail due to foreign key constraint:
    $store_raw->execute('8','maiiiiil',$key);
}
