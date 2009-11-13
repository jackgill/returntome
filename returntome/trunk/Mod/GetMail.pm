package Mod::GetMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Net::IMAP::Simple::SSL;
use Email::Simple;

our @ISA = ("Exporter");
our @EXPORT = qw(&getMail);

sub getMail {
    #Login information:
    my $server = shift;
    my $user = shift;
    my $pass = shift;
    my $keep = shift;

    my $logger = Log::Log4perl->get_logger();

    #$logger->debug("Called Mod::GetMail::getMail");
    unless ($server && $user && $pass) {
	$logger->error("GetMail did not receive necessary arguments.");
	return ();
    }
    
    #Create the IMAP client
    my $imap = Net::IMAP::Simple::SSL->new($server);
    
    unless($imap) {
	$logger->error("Could not connect to IMAP server.");
	return ();
    }
    
    #Log in to the IMAP server
    unless ($imap->login($user => $pass)) {
	$logger->error("Could not login to IMAP server: " . $imap->errstr);
	return ();
    }

    #open the inbox
    my $nMessages = $imap->select('INBOX');
    unless ($nMessages) {
	#$logger->info("Couldn't open inbox");
	return ();
    }

    my @raw_messages;
    for (my $iMessage = 1; $iMessage <= $nMessages; $iMessage++) {
	my $message = $imap->get( $iMessage );
	$imap->delete($iMessage) unless $keep;
	my $raw_message = join '' , @$message;
	push @raw_messages, $raw_message;
    }

    #close the IMAP client
    $imap->quit;

    return @raw_messages;
}

1;
