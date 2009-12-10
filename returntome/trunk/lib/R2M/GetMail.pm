package Mod::GetMail;

use warnings;
use strict;

use Exporter;
use Net::IMAP::Simple::SSL;

our @ISA = qw(Exporter);
our @EXPORT = qw(getMail);

sub getMail {
    my ($server, $user, $pass, $keep) = @_;

    my $logger = Log::Log4perl->get_logger();

    if ( !($server && $user && $pass) ) {
	$logger->error("GetMail did not receive necessary arguments.");
	return;
    }

    #Create the IMAP client
    my $imap = Net::IMAP::Simple::SSL->new($server);

    if( !$imap ) {
	$logger->error("Could not connect to IMAP server.");
	return;
    }

    #Log in to the IMAP server
    if( !$imap->login($user, $pass) ) {
	$logger->error("Could not login to IMAP server: " . $imap->errstr);
	return;
    }

    #Open the inbox
    my $nMessages = $imap->select('INBOX');
    if ( !$nMessages ) {
	return;
    }

    #Retrieve and delete the messages:
    my @messages;
    for (my $iMessage = 1; $iMessage <= $nMessages; $iMessage++) {
	my $message = $imap->get( $iMessage );
	$imap->delete($iMessage) unless $keep;
	my $message_string = join '' , @{ $message };
	push @messages, $message_string;
    }

    #close the IMAP client
    $imap->quit;

    return @messages;
}

1;

=head1 NAME

Mod::GetMail

=head1 SYNOPSIS

C<my @mail = getMail('imap.gmail.com','foo@bar.com','password');>

=head1 DESCRIPTION

Contact an IMAP server using SSL and retrieve messages. Retrieved messages are deleted from the server.

=head1 SUBROUTINES

=over

=item *

B<getMail>

I<Arguments:>

=over

=item *

IMAP server name

=item *

login to IMAP server

=item *

password to IMAP server

=item *

I<Optional:> 1 to keep messages on server, 0 to delete them.

=back

I<Returns:>

=over

=item *

A list of strings, each one containing the text of an email.

=back

=back

=head1 DEPENDENCIES

=over

=item *

Net::IMAP::Simple::SSL

=back
