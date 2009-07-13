package R2M::SendMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Net::SMTP::SSL;

our @ISA = ("Exporter");
our @EXPORT = qw(&sendMessages &sendMail);

sub sendMessages {
    for (@_) {
	my %message = %$_;
	#print Dumper(%message);
	my $address = $message{'from'};
	my $subject = $message{'subject'};
	my $body = $message{'body'};
	
	$subject = "Returned To You: $subject";

	&sendMail($address, $subject, $body,'return.to.me.test@gmail.com','return2me');
    }
}

sub sendMail {
    my $to = shift;
    my $subject = shift;
    my $body = shift;
    my $from = shift;
    my $password = shift;

    
    my $smtp;
    
    if (not $smtp = Net::SMTP::SSL->new('smtp.gmail.com', Port => 465, Debug => 0)) {
	die "Could not connect to server\n";
    }
    
    $smtp->auth($from, $password) or die "Authentication failed!\n";
    
    $smtp->mail($from . "\n");
    my @recepients = split(/,/, $to);
    foreach my $recp (@recepients) {
	$smtp->to($recp . "\n");
    }
    $smtp->data();
    $smtp->datasend("From: " . $from . "\n");
    $smtp->datasend("To: " . $to . "\n");
    $smtp->datasend("Subject: " . $subject . "\n");
    $smtp->datasend("\n");
    $smtp->datasend($body . "\n");
    $smtp->dataend();


    $smtp->quit;
}

1;
