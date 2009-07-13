package R2M::GetMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Net::IMAP::Simple::SSL;
use Email::Simple;
use Carp;

our @ISA = ("Exporter");
our @EXPORT = qw(&getMail);

sub getMail {
    #Login information:
    my $server = 'imap.gmail.com';
    my $user = 'return.to.me.test@gmail.com';
    my $pass = 'return2me';
    
    #Create the IMAP client
    my $imap = Net::IMAP::Simple::SSL->new($server);
    
    #Log in to the IMAP server
    $imap->login($user => $pass) or croak "Login failed: " . $imap->errstr . "\n";
    
    #open the inbox
    my $nMessages = $imap->select('INBOX');
    unless ($nMessages) {
	#my $logger = Log::Log4perl->get_logger();
	#$logger->info("Couldn't open inbox");
	return ();
    }
    my @raw_messages;
    for (my $iMessage = 1; $iMessage <= $nMessages; $iMessage++) {
	my $message = $imap->get( $iMessage );
	$imap->delete($iMessage);
	my $raw_message = join '' , @$message;
	push @raw_messages, $raw_message;
    }
    #close the IMAP client
    $imap->quit;

    return @raw_messages;
}

1;
