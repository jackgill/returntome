package Mod::SendMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Net::SMTP::SSL;

our @ISA = ("Exporter");
our @EXPORT = qw(&sendMail);

sub sendMail {
    my $server = shift;
    my $from = shift;
    my $password = shift;
    my @messages = @_;
    return unless @messages;

    my $logger = Log::Log4perl->get_logger();
    my $smtp;
    my $error;

    #Return values:
    my @unsent_messages;
    my @sent_messages;

    #Connect to the SMTP server:
    unless ($smtp = Net::SMTP::SSL->new($server, Port => 465, Debug => 1)) {
	$logger->("Could not connect to SMTP server");
	return [],\@messages; #Return all messages if we couldn't connect to the SMTP server:
    } 

    #Authenticate to the SMTP server:
    unless ($smtp->auth($from, $password)) {
	$logger->error("Could not authenticate to SMTP server");
	return [],\@messages;
    }

    #Send the messages
    for (@messages) {
	my %message = %$_;

	my $address = $message{'address'};
#	my $subject = $message{'subject'};
	my $body = $message{'body'};
	my $uid = $message{'uid'};

	$logger->debug("Sending message:");
	$logger->debug(Dumper(%message));

	#TODO: check return value on these?
	$smtp->mail($from . "\n");
	$smtp->to($address . "\n");
	$smtp->data();
	#Gmail rewrites these headers anyway:
#	$smtp->datasend("From: " . "ReturnToMe" . "\r");
#	$smtp->datasend("To: " . $address . "\r");
#	$smtp->datasend("Subject: " . $subject . "\n");
#	$smtp->datasend("\n");
	$smtp->datasend($body . "\n");
	$smtp->dataend();
	my $smtp_response = $smtp->message;
	if ($smtp_response =~ /2.0.0 OK/) {
	    $logger->info("Successfully sent message $uid.");
	    push @sent_messages, \%message;
	} else {
	    $logger->error("Error sending message $uid:");
	    $logger->error($smtp_response);
	    push @unsent_messages, \%message;
	}
    }
    $smtp->quit;
    return \@sent_messages,\@unsent_messages;
}

1;
