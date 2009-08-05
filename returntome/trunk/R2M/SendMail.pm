package R2M::SendMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Net::SMTP::SSL;

our @ISA = ("Exporter");
our @EXPORT = qw(&sendMessages);

sub sendMessages {
    my $from = shift;
    my $password = shift;
    my @messages = @_;
    return unless @messages;

    my $logger = Log::Log4perl->get_logger();
    my $smtp;
    my $error;

    #Connect to the SMTP server:
    if (not $smtp = Net::SMTP::SSL->new('smtp.gmail.com', Port => 465, Debug => 1)) {
	$error = "Could not connect to SMTP server";
    }

    #Authenticate to the SMTP server:
    $smtp->auth($from, $password) or $error = "Authentication failed";

    #Handle errors:
    if ($error) {
	$logger->error($error);
	return @messages;
    }

    #Send the messages
    for (@messages) {
	my %message = %$_;

	my $address = $message{'address'};
	my $subject = $message{'subject'};
	my $body = $message{'body'};

	$logger->info("Sending message:");
	$logger->info(Dumper(%message));

	$smtp->mail($from . "\r\n");
	$smtp->to($address . "\r\n");
	$smtp->data();
	$smtp->datasend("From: " . $from . "\r\n");
	$smtp->datasend("To: " . $address . "\r\n");
	$smtp->datasend("Subject: " . $subject . "\r\n");
	$smtp->datasend("\r\n");
	$smtp->datasend($body . "\r\n");
	$smtp->dataend();
    }
    $smtp->quit;
}

1;
