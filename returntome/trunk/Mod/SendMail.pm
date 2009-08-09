package Mod::SendMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Net::SMTP::SSL;

our @ISA = ("Exporter");
our @EXPORT = qw(&sendMessages);

sub sendMessages {
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
    if (not $smtp = Net::SMTP::SSL->new($server, Port => 465, Debug => 1)) {
	$error = "Could not connect to SMTP server";
    }

    if ($error) {
	$logger->error($error);
	my @uids;
	return [],\@messages;
    }

    #Authenticate to the SMTP server:
    $smtp->auth($from, $password) or $error = "Authentication failed";

    #Return all messages if we couldn't connect or authenticate to the SMTP server:
    #EVIL code dup!
    if ($error) {
	$logger->error($error);
	my @uids;
	return [],\@messages;
    }



    #Send the messages
    for (@messages) {
	my %message = %$_;

	my $address = $message{'address'};
	my $subject = $message{'subject'};
	my $body = $message{'body'};
	my $uid = $message{'uid'};

	$logger->info("Sending message:");
	$logger->info(Dumper(%message));

	#TODO: check return value on these?
	$smtp->mail($from . "\n");
	$smtp->to($address . "\n");
	$smtp->data();
	#Gmail rewrites these headers anyway:
#	$smtp->datasend("From: " . "ReturnToMe" . "\r");
#	$smtp->datasend("To: " . $address . "\r");
	$smtp->datasend("Subject: " . $subject . "\n");
	$smtp->datasend("\n");
	$smtp->datasend($body . "\n");
	$smtp->dataend();
	my $smtp_response = $smtp->message;
	if ($smtp_response =~ /2.0.0 OK/) {
	    push @sent_messages, \%message;
	} else {
	    $logger->info("Error sending message!");
	    $logger->info($smtp_response);
	    push @unsent_messages, \%message;
	}
    }
    $smtp->quit;
    return \@sent_messages,\@unsent_messages;
}

1;
