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
our @EXPORT = qw(&createMessages);

=head1 NAME

    Mod::Test

=cut

=head1 SYNOPSIS

    my @messages = &createMessages($nMessages,$nMinutes);

=cut

=head1 DESCRIPTION

    A collection of routines used for testing.

=cut

=head1 FUNCTIONS

=over 

=cut

my $logger = Log::Log4perl->get_logger();

=item createMessages(nMessages, nMinutes)

    Generate new messages. 

    Arguments: the number of messages to be generated, and the number of minutes into the future for which the return times will be generated. The last two messages will have no instructions.
    Returns: A list of message hash refs.

=cut

sub createMessages {
    my $nMessages = shift;
    my $nMinutes = shift;
    my $to = shift;
    my @messages;
    for (my $i = 0; $i < $nMessages; $i++) {
	my $return_time = time + $nMessages * 15 + int(rand($nMinutes * 60));
	my $dt = DateTime->from_epoch( epoch => $return_time, time_zone => 'America/Denver');
	my $body = "R2M: " . $dt->hms . " " . $dt->mdy . "\nbody $i";
	if ($i >= ($nMessages - 2)) {	
	    $body = "no instructions here...";
	    $return_time = time + $nMessages * 15;
	}
	my $msg = MIME::Lite->new(
	    From    => 'return.to.me.receive@gmail.com',
	    To      => $to,
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
	my %message = (
	    mail => $msg->as_string,
	    return_time => $return_time,
	    uid => &getUID,
	    );
	push @messages, \%message;
    }
    return @messages;
}

=back

=cut

1;
	
