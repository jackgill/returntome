package Mod::SendMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Net::SMTP::SSL;

use Mod::ParseMail;

our @ISA = ("Exporter");
our @EXPORT = qw(&sendMail);

=head1 NAME

    Mod::SendMail

=cut

=head1 SYNOPSIS
    
    my %message = (
    address => foo,
    mail=> foo,
    );
my ($sent_ref,$unsent_ref) = &sendMail('smtp.gmail.com','return.to.me.test@gmail.com','password',\%messages);


=cut

=head1 DESCRIPTION

    This module connects to a SMTP server using SSL. 

=cut

=head1 FUNCTIONS

=over 

=item sendMail(smtp server, sending address, password, messages)

    Send a list of messages. This function assumes that the Log4perl logger has already been initialized.

    Arguments: The server name, login, and password are the first 3 arguments. Further arguments are assumed to be hashrefs representing messages. Each message must contain an 'address' field, which is the address to which the message will be sent.
    Returns: A list of two array refs. The first is a reference to an array of successfully sent messages, the second is a reference to an array of messages which were not sent.

=cut


sub sendMail {
    my $smtp_server = shift;
    my $sending_address = shift;
    my $password = shift;
    my @messages = @_;
    return unless @messages;

    my $logger = Log::Log4perl->get_logger();
    my $smtp;

    #Return values:
    my @unsent_messages;
    my @sent_messages;

    #Connect to the SMTP server:
    unless ($smtp = Net::SMTP::SSL->new($smtp_server, Port => 465, Debug => 0)) {
	$logger->error("Could not connect to SMTP server");
	return [],\@messages; 
    } 

    #Authenticate to the SMTP server:
    unless ($smtp->auth($sending_address, $password)) {
	$logger->error("Could not authenticate to SMTP server");
	return [],\@messages;
    }

    #Send the messages
    for (@messages) {
	my %message = %$_;

	my $address = $message{address};
	my $mail = $message{mail};

	#TODO: check return value on these?
	$smtp->mail($sending_address . "\n");
	$smtp->to($address . "\n");
	$smtp->data();
	$smtp->datasend($mail . "\n");
	$smtp->dataend();

	#Check the SMTP response:
	my $smtp_response = $smtp->message;
	if ($smtp_response =~ /2.0.0 OK/) {
	    push @sent_messages, \%message;
	} else {
	    $logger->error($smtp_response);
	    push @unsent_messages, \%message;
	}
    }
    $smtp->quit;
    return \@sent_messages,\@unsent_messages;
}

=back

=cut

1;
