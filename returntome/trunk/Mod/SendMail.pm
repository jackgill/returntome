package Mod::SendMail;

use warnings;
use strict;

use Exporter;
use Net::SMTP::SSL;
use Log::Log4perl;

our @ISA = ("Exporter");
our @EXPORT = qw(sendMessages sendMail);

sub sendMessages {
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
	} else {
	    $logger->error("Did not send message $uid.");
	    $logger->error($smtp_response);
	}
    }
    $smtp->quit;
    return @sent_uids;
}

sub sendMail {
    my ($smtp_server, $from_address, $password, $to_address, $mail) = @_;

    #Connect to the SMTP server:
    my $smtp;
    unless ($smtp = Net::SMTP::SSL->new($smtp_server, Port => 465, Debug => 0)) {
	die "Could not connect to SMTP server\n";
    }

    #Authenticate to the SMTP server:
    unless ($smtp->auth($from_address, $password)) {
	die "Could not authenticate to SMTP server\n";
    }

    #Send the mail
    $smtp->mail($from_address . "\n");
    $smtp->to($to_address . "\n");
    $smtp->data();
    $smtp->datasend($mail . "\n");
    $smtp->dataend();

    #Check the SMTP response:
    my $smtp_response = $smtp->message;
    unless ($smtp_response =~ /2.0.0 OK/) {
        $smtp->quit;
        die "Failed to send mail: $smtp_response\n";
    }
    $smtp->quit;
}

1;

=head1 NAME

Mod::SendMail

=head1 SYNOPSIS

    my %message = (
    address => 'foo@bar.com',
    mail => 'this is a mail message',
    uid => 00000001,
    );
    my @sent_uids = sendMail('smtp.gmail.com','return.to.me.test@gmail.com','password',\%message);

=head1 DESCRIPTION

This module connects and authenticates to a SMTP server using SSL. It then sends a series of emails. Any errors are logged.

=head1 SUBROUTINES

=over

=item *

B<sendMessages>

Send a list of messages. This function assumes that the Log4perl logger has already been initialized.

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

=item *

B<sendMail>

Send a single email.

I<Arguments:>

=over

=item *

name of SMTP server

=item *

login to SMTP server, assumed to be the same as the sending address

=item *

password to SMTP server

=item *

the address to send the mail to

=item *

the text of the mail

=back

=head1 DEPENDENCIES

=over

=item *

Net::SMTP::SSL

=item *

Log::Log4perl

=back
