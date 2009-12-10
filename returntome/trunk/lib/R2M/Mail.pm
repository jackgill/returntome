package R2M::Mail;

use strict;
use warnings;

use Exporter;
use Net::IMAP::Simple::SSL;
use Net::SMTP::SSL;
use Log::Log4perl;

our @ISA = qw(Exporter);
our @EXPORT = qw(get_mail send_mail);

sub get_mail {
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

sub send_mail {
    my $smtp_server = shift;
    my $sending_address = shift;
    my $password = shift;
    my @messages = @_;
    return unless @messages;

    #Get the logger:
    my $logger = Log::Log4perl->get_logger();

    #We will return a list of UIDs for messages we sent successfully:
    my @sent_uids;

    #Connect to the SMTP server:
    my $smtp;
    unless ($smtp = Net::SMTP::SSL->new($smtp_server, Port => 465, Debug => 0)) {
	$logger->error("Could not connect to SMTP server");
	return;
    }

    #Authenticate to the SMTP server:
    unless ($smtp->auth($sending_address, $password)) {
	$logger->error("Could not authenticate to SMTP server");
	return;
    }

    #Send the messages
    for my $message (@messages) {

        my $address = $message->{address};
	my $mail = $message->{mail};
	my $uid = $message->{uid};
	$uid = '(NO UID)' unless $uid;

	unless ($address) {
	    $logger->error("Address is null for message $uid.");
	    next;
	}

	#TODO: check return value on these?
	$smtp->mail($sending_address . "\n");
	$smtp->to($address . "\n");
	$smtp->data();
	$smtp->datasend($mail . "\n");
	$smtp->dataend();

	#Check the SMTP response:
	my $smtp_response = $smtp->message;
	if ($smtp_response =~ /2.0.0 OK/) {
	    push @sent_uids, $uid;
	}
        else {
	    $logger->error("Did not send message $uid: $smtp_response");
	}
    }
    $smtp->quit;
    return @sent_uids;
}

1;

=head1 NAME

R2M::Mail -- Retrieve mail using IMAP, and send mail using SMTP.

=head1 SYNOPSIS

C<my @mail = get_mail('imap.domain.tld','address@domain.tld','password');>
 my %message = (
  address => 'address@domain.tld',
  mail => 'From: To: Subject: etc',
  uid => 00000001,
 );
 my @sent_uids = sendMessages('smtp.domain.tld','address@domain.tld','password',\%message);

=head1 DESCRIPTION

=head1 SUBROUTINES

=over

=item B<get_mail>

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

=item B<send_mail>

Send a list of messages.

I<Arguments:>

=over

=item *

name of SMTP server

=item *

login to SMTP server

=item *

password to SMTP server

=item *

Additional arguments are assumed to be hashrefs representing messages. Each message hash must contain these  keys:
              'address' -- the address to which the mail will be sent
              'mail'    -- the text of the mail
              'uid'     -- this used for logging, and the return value. If this field is undefined, the string '(NO UID)' is used in its place.

=back

I<Returns:>

=over

=item *

A list of uids corresponding to messages which were successfully sent.

=back

=back

=head1 DEPENDENCIES

=over

=item *

Net::IMAP::Simple::SSL

=item *

Net::SMTP::SSL

=item *

Log::Log4perl

=back
