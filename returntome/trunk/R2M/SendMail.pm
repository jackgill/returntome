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
    my $smtp;
    
    if (not $smtp = Net::SMTP::SSL->new('smtp.gmail.com', Port => 465, Debug => 1)) {
	die "Could not connect to server\n";
    }
    
    $smtp->auth($from, $password) or die "Authentication failed!\n";
    for (@messages) {
	my %message = %$_;
	#print Dumper(%message);
	my $address = $message{'from'};
	my $subject = $message{'subject'};
	my $body = $message{'body'};
	my $uid = $message{'uid'};



	$smtp->mail($from . "\n");
	$smtp->to($address . "\n");
	$smtp->data();
	$smtp->datasend("From: " . $from . "\n");
	$smtp->datasend("To: " . $address . "\n");
	$smtp->datasend("Subject: " . $subject . "\n");
	$smtp->datasend("\n");
	$smtp->datasend($body . "\n");
	$smtp->dataend();
	my $logger = Log::Log4perl->get_logger();
	$logger->info("Sent message $uid");
	$logger->info(Dumper(%message));
    }
    $smtp->quit;
}

1;
