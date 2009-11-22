package Mod::Test;

use 5.010;

use warnings;
use strict;

use Exporter;

use MIME::Lite;
use DateTime;

our @ISA = qw(Exporter);
our @EXPORT = qw(&createMessages);

sub createMessages {
    my ($nMessages, $nMinutes, $to) = @_;

    my @messages;
    for (my $i = 0; $i < $nMessages; $i++) {

        #Determine when this message will be returned, in epoch sends
	my $return_time = time + $nMessages * 15 + int(rand($nMinutes * 60));

        #Parse the return time
	my $dt = DateTime->from_epoch( epoch => $return_time, time_zone => 'America/Denver');

        #Compose the body of the message
	my $body;

        #The last two messages will have no instructions
	if ($i >= ($nMessages - 2)) {
	    $body = "no instructions here...";
	    $return_time = time + $nMessages * 15;
	}
        else {
            $body = "R2M: " . $dt->hms . " " . $dt->mdy . "\nbody $i";
        }

        #Construct the MIME message
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

        #Construct the message hash
	my %message = (
	    mail => $msg->as_string,
	    return_time => $dt->ymd . " " . $dt->hms,
	    address => $to,
	    );

	push @messages, \%message;
    }

    return @messages;
}

1;

=head1 NAME

Mod::Test

=head1 SYNOPSIS

C<my @messages = &createMessages($nMessages,$nMinutes);>

=head1 DESCRIPTION

A collection of routines used for testing.

=head1 SUBROUTINES

=over

=item *

B<createMessages>

Generate new messages.
The last two messages will have no instructions.

I<Arguments:>

=over

=item *

The number of messages to be generated

=item *

The number of minutes into the future for which the return times will be generated.

=item *

The address to which the messages will be sent

=back

I<Returns:>

=over

=item *

A list of message hash refs.

=back

=back

=head1 DEPENDENCIES

=over

=item *

MIME::Lite

=item *

DateTime

=back

