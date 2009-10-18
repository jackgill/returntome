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
our @EXPORT = qw(&createMail &printLine);
our @EXPORT_OK = qw(&sendMail &getMail);


=head1 NAME

    Mod::Test

=cut

=head1 SYNOPSIS



=cut

=head1 DESCRIPTION

    A collection of routines used for testing.

=cut

=head1 FUNCTIONS

=over 

=cut

my $logger = Log::Log4perl->get_logger();


=item sendMail(smtp server, sending address, password, messages)
    
    This method is used by Talaria's test mode. It is a dummy for
    &Mod::SendMail::sendMail. It simply logs the messages as sent.

=cut

sub sendMail {
    my $server = shift;
    my $user = shift;
    my $password = shift;
    my @messages = @_;

    for (@messages) {
	my %message = %$_;
	$logger->info("Sent message " . $message{uid});
	$logger->debug(Dumper(%message));
    }
    my @unsent = ();
    return \@messages,\@unsent;
}

=item getMail

    This method is used by Talaria's test mode. It is a dummy for
    &Mod::GetMail::getMail. It generates messages using &createMail.
    Each invocation returns two new messages with return times up to
    2 minutes in the future.

    Arguments: None.
    Returns: A list of scalars, each one being the text of an email.

=cut

sub getMail {
    $logger->debug('Called &Mod::Test::getMail');
    my @mail = &createMail(2,2);
    return @mail;
}

=item createMessages(nMessages, nMinutes)

    Generate new messages. 

    Arguments: the number of messages to be generated, and the number of minutes into the future for which the return times will be generated.
    Returns: A list of hash refs.
=cut

sub createMessages {
    my $nMessages = shift;
    my $nMinutes = shift;

    my @messages;
    for (my $i = 0; $i < $nMessages; $i++) {
	my $return_time = time + int(rand($nMinutes * 60));
	my $dt = DateTime->from_epoch( epoch => $return_time, time_zone => 'America/Denver');
	my $body = "R2M: " . $dt->hms . " " . $dt->mdy . "\nbody $i";
	my $uid = 0;#&getUID;
	push @messages, {uid => $uid, 
			 return_time => $return_time,
			 mail => "To: return.to.me.receive\@gmail.com\nFrom: return.to.me.test\@gmail.com\nSubject: subject ${i}\n\nR2M: " . $dt->hms . " " . $dt->mdy . "\nbody $i",
	};
    }
    return @messages;
}

=item createMail(nMessages, nMinutes)
    
    Generates emails.
=cut

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
	    Subject => "subject $i",
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
	
