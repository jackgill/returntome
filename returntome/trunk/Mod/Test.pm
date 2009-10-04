package Mod::Test;

use 5.010;

use warnings;
use strict;

use Exporter;
use Mod::DB;
use IO::Scalar;
use Time::Piece;
use MIME::Lite;
use Data::Dumper::Simple;
use DateTime;

our @ISA = qw(Exporter);
our @EXPORT = qw(&createMessages &createMail &printLine);
our @EXPORT_OK = qw(&sendMail &getMail);

my $logger = Log::Log4perl->get_logger();

sub sendMail {
    my $server = shift;
    my $user = shift;
    my $password = shift;
    my @messages = @_;

    #$logger->info('Called &Mod::Test::sendMessages with:');
    #$logger->info("\t\$server = $server");
    #$logger->info("\t\$user = $user");
    #$logger->info("\t\$password = $password");
    for (@messages) {
	my %message = %$_;
	$logger->info("Sent message " . $message{uid});
	#$logger->info(Dumper(%message));
    }
    my @unsent = ();
    return \@messages,\@unsent;
}

my $nGetMailCalls = 0;

sub getMail {
    #return () unless ($nGetMailCalls == 0);
    $logger->debug('Called &Mod::Test::getMail');
    my @mail = &createMail(2,2);
    return @mail;
}

sub createMessages {
    my $nMessages = shift;
    my $nMinutes = shift;

    my @messages;
    for (my $i = 0; $i < $nMessages; $i++) {
	my $return_time = time + int(rand($nMinutes * 60));
	my $dt = DateTime->from_epoch( epoch => $return_time, time_zone => 'America/Denver');
	my $body = "R2M: " . $dt->hms . " " . $dt->mdy . "\nbody $i";
	push @messages, {uid => &getUID, 
			 address => 'return.to.me.receive@gmail.com',
			 mail => "To: return.to.me.receive\@gmail.com\nFrom: return.to.me.test\@gmail.com\nSubject: subject ${i}\n\nR2M: " . $dt->hms . " " . $dt->mdy . "\nbody $i",
	};
    }
    return @messages;
}

sub createMail {
    my $nMail = shift;
    my $nMinutes = shift;
    my @mail;
    for (my $i = 0; $i < $nMail; $i++) {
	my $return_time = time + int(rand($nMinutes * 60));
	my $dt = DateTime->from_epoch( epoch => $return_time, time_zone => 'America/Denver');
	my $body = "R2M: " . $dt->hms . " " . $dt->mdy . "\nbody $i";
	my $msg = MIME::Lite->new(
	    From    => 'return.to.me.receive@gmail.com',
	    To      => 'return.to.me.test@gmail.com',
	    Subject => 'subject $i',
	    Type    => 'multipart/alternative',
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
	
