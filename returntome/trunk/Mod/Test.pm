package Mod::Test;

use 5.010;

use warnings;
use strict;

use Exporter;
use Mod::UID;
use IO::Scalar;
use Time::Piece;
use MIME::Lite;
use Data::Dumper::Simple;
use DateTime;

our @ISA = qw(Exporter);
our @EXPORT = qw(&createMessages &createMail &createReturnWhen &getMail &sendMessages);

sub sendMessages {
    my $from = shift;
    my $password = shift;
    my @messages = @_;
    my $logger = Log::Log4perl->get_logger();
    $logger->info('Called &sendMessages with:');
    $logger->info("\t\$from = $from");
    $logger->info("\t\$password = $password");
    for (@messages) {
	my %message = %$_;
	$logger->info(Dumper(%message));
    }
}
#my $nGetMailCalls = 0;
sub getMail {
#    return () unless ($nGetMailCalls == 0);
     my @mail = &createMail(2);
     return @mail;
}
sub createMessages {
    my @messages;
    for my $uid (@_) {
	my $now = localtime;
	my $wait =  int(rand(2 * 60));
	my $return_time = $now + $wait;
	my $return_when =$return_time->datetime;
	push @messages, {uid => $uid, 
			 address => 'return.to.me.receive@gmail.com',
			 subject => "subject line", 
			 body => "Mod: $return_when \r\nbody of message",
	};
    }
    return @messages;
}

sub createMail {
    my $nMail = shift;
    my @mail;
    for (my $i = 0; $i < $nMail; $i++) {
	my $return_time = time + int(rand(2 * 60));
	my $dt = DateTime->from_epoch( epoch => $return_time, time_zone => 'America/Denver');
	my $body = "Mod: " . $dt->hms . " " . $dt->mdy . "\r\nbody of message";
	my $msg = MIME::Lite->new(
	    From    => 'return.to.me.receive@gmail.com',
	    To      => 'return.to.me.test@gmail.com',
	    Subject => 'subject line',
	    Type    => 'multipart/mixed',
	    );
	$msg->attach(
	    Type     => 'text/plain',
	    Data     => $body,
	    );
	$msg->attach(
	    Type => 'text/html',
	    Data => '<br>' . $body . '<br>',
	    );
	push @mail, $msg->as_string;
    }
    return @mail;
}

sub printLine {
    my $line = shift;
    my @bytes = unpack("C*",$line);
    print @bytes,"\n";
}

1;
	
