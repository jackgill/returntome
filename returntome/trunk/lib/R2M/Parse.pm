package R2M::Parse;

#pragmas
use 5.010;
use warnings;
use strict;
use bytes;

#modules
use Exporter;
use Log::Log4perl;
use MIME::Parser;
use Date::Manip;
use R2M::Ad;
use Time::localtime;

our @ISA = qw(Exporter);
our @EXPORT = qw(parse_mail parseInstructions from_epoch);

my $logger = Log::Log4perl->get_logger();

sub parse_mail {
    my ($raw_mail, $from_address, $uid) = @_;

    #Create the parser:
    my $parser = new MIME::Parser;
    $parser->output_under('/tmp');

    #parse the mail:
    my $entity;
    eval {
        $entity = $parser->parse_data( $raw_mail );
    };

    #Check the parser for fatal errors
    if ($@) {
        $parser->filer->purge();
        die "MIME parser fatal error: $@\n";
    }

    #Check the parser for non fatal errors
    for my $error ($parser->results->msgs) {
        $logger->error("MIME parser error for message $uid:\n$error");
    }

    #get the headers
    my $head = $entity->head;
    my $subject = $head->get('Subject');
    if (!$subject) { #check for empty subject line
        $subject = "\n";
    }
    my $from = $head->get('From');


    #Initialize mail with basic headers:
    my $parsed_mail = 
	"From: $from_address\n" .
	"To: $from" .
	"Subject: $subject" ;    #TODO: What if subject is encoded? MIME::Head->decode('I_KNOW_WHAT_I_AM_DOING')

    #Find the text/plain and text/html parts of the message:
    my $text_plain;
    my $text_html;

    if ($head->count('MIME-Version')) {#Message is MIME formatted

	#Add MIME headers to mail:
	my @header_names = ('MIME-Version','Content-Type','Content-Transfer-Encoding');
	for my $header_name (@header_names) {
            my $header_value = $head->get($header_name);
            if ($header_value) {
                $parsed_mail .= "$header_name: $header_value";
            }
	}

	given($entity->effective_type) {
	    when('multipart/mixed') { #there are attachments
	      PARTS:
		for my $part ($entity->parts) {
		    if ($part->effective_type eq 'multipart/alternative') {
		      SUB_PARTS:
			for my $sub_part ($part->parts) {
			    $text_plain = $sub_part if ($sub_part->effective_type eq 'text/plain');
			    $text_html  = $sub_part if ($sub_part->effective_type eq 'text/html');
			}
			last PARTS;
		    }
		    if ($part->effective_type eq 'text/plain') {
			$text_plain = $part;
			last PARTS;
		    }
		}
	    }
	    when('multipart/alternative') { #text/plain and text/html only
		for my $part ($entity->parts) {
		    $text_plain = $part if ($part->effective_type eq 'text/plain');
		    $text_html  = $part if ($part->effective_type eq 'text/html');
		}
	    }
	    when('text/plain') { #text/plain only
		$text_plain = $entity;
	    }
	}
    }
    else { #Message is not MIME formatted
	$text_plain = $entity;
    }
    #TODO: what if plain text part is not found?

    #Process text/plain and text/html parts:
    my @plain_lines = readEntity($text_plain);
    my @html_lines = readEntity($text_html) if $text_html;

    my $error_message;
    my $return_time;

    #Look for instructions:
    my $instructions;
  LINE:
    for my $line (@plain_lines) {
	if ($line =~ /^ \s* (?: r2m | rtm | return \s* to \s* me) :? \s* (.+) \s* $/ixms) {
	    $instructions = $1;
	    last LINE;
	}
    }

    if ($instructions) { #instructions were found
        #Get return time
	$return_time = parseInstructions($instructions);

	if ($return_time) { #instructions parsing succeeded
	    #Check for return dates in the past
            if ($return_time lt from_epoch(time)) {
                $error_message = "You specified a return date in the past.";
            }

	    #Check for return dates too far in the future
            if ($return_time gt from_epoch(time + 60 * 60 * 24 * 365)) {
                $error_message = "Sorry, we do not accept messages with a return date more than a year in the future.";
            }
	}
        else { #instructions parsing failed
	    $error_message = "Sorry, we could not understand these instructions.";
	}
    }
    else { #instructions were not found
        $error_message = "Sorry, we could not find instructions in this message.";
    }

    #Check message size:
    if (length($raw_mail) > 8e6) {
        $error_message = "Sorry, your message size must be less than 8 MB.";
    }

    #Add an error message or an ad to the message as appropriate
    if ($error_message) {
        $return_time = undef; #to guarantee immediate return
	unshift @plain_lines, $error_message . "\n\n";
	unshift @html_lines, "<b>" . $error_message . "</b><br><br>\n\n";
    } else {
	unshift @plain_lines, getPlainAd() . "\n\n";
	unshift @html_lines, getHTMLAd() . ("-" x 70) . "<br><br>";
    }

    #Write the modified message:
    writeEntity($text_plain,\@plain_lines);
    writeEntity($text_html,\@html_lines) if $text_html;
    #TODO: check return value on above

    #Add the parsed MIME entity to the mail
    $parsed_mail .= "\n" . join('', @{ $entity->body } );

    #Format 'From' address for storage in DB
    chomp $from;
    if ($from =~ /<(.*?)>/) {
        $from = $1;
    }

    #assemble the message
    my %message = (
	mail => $parsed_mail,
	return_time => $return_time,
	address => $from,
        uid => $uid,
	);

    #Remove temp files created by parser
    $parser->filer->purge();

    return \%message;
}


sub readEntity {
    my $entity = shift;

    my $bh = $entity->bodyhandle;

    my @lines;

    #Open body handle for reading:
    my $io = $bh->open("r");
    if (not $io) {
	$logger->error("Could not open MIME entity body");
	return;
    }

    #Read from body handle:
    my $line;
    while (defined($line = $io->getline)) {
        push @lines, $line;
    }

    #Close body handle:
    if (not $io->close) {
	$logger->error("Could not close MIME entity body");
	return;
    }

    return @lines;
}

sub writeEntity {
    my ($entity, $lines_ref) = @_;

    my @lines = @{ $lines_ref };

    my $bh = $entity->bodyhandle;

    #Open body handle for writing:
    my $io = $bh->open("w");
    if (not $io) {
	$logger->error("Could not open MIME entity body");
	return 0;
    }

    #Write lines to body handle:
    for my $line (@lines) {
        $io->print($line);
    }

    #Close body handle:
    if (not $io->close) {
	$logger->error("Could not close MIME entity body");
	return 0;
    }

    #Return value for success:
    return 1;
}

sub parseInstructions {
    my $instructions = shift;

    my $result = ParseDate($instructions);
    return unless $result;

    my $date = UnixDate($result,"%Y-%m-%d %T");
    #my $epoch = UnixDate($result,"%s");

    return $date;
}

sub from_epoch {
    my $epoch = shift;
    return unless $epoch;

    my $tm = localtime($epoch);
    return sprintf("%4u-%02u-%02u %02u:%02u:%02u",
                   $tm->year + 1900,
                   $tm->mon + 1,
                   $tm->mday,
                   $tm->hour,
                   $tm->min,
                   $tm->sec);
}

1;

=head1 NAME

R2M::Parse -- parses emails.

=head1 SYNOPSIS

C<my %message = %{ parse_mail($raw_message, $from, $uid) };>

=head1 DESCRIPTION

Parses emails.

=head1 SUBROUTINES

=over

=item *

B<parse_mail>

Extract the return time from the email.
Add error messages or ads as necessary.

I<Arguments:>

=over

=item *

The email as a string

=item *

'From' address

=back

I<Returns:>

=over

=item *

A hashref to a message based on the email.
The message looks like:
    my %message = (
    mail => $mail,
    return_time => $return_time,
    address => $from,
    uid => $uid,
    );

=back

=item *

B<readEntity>

Get an array of lines representing the body of a MIME::Entity.

I<Arguments:>

=over

=item *

A reference to a MIME::Entity.

=back

I<Returns:>

=over

=item *

A array of lines representing the body of the MIME::Entity.

=back

=item *

B<writeEntity>

Write an array of lines to the body of a MIME::Entity.

I<Arguments:>

=over

=item *

A reference to a MIME::Entity

=item *

A reference to an array of lines.

=back

I<Returns:>

=over

=item *

1 if write succeeded, 0 if write failed.

=back

=item *

B<parseInstructions>

Extract a return time from the given instructions.

I<Arguments:>

=over

=item *

A string containing the instructions.

=back

I<Returns:>

=over

Either a time in epoch seconds or undef.

=back

=item *

B<fromEpoch>

Given a time in epoch seconds, return a formatted string representing that time.

I<Arguments:>

=over

=item *

Time in epoch seconds.

=back

I<Returns:>

=over

=item *

A formatted string representing the time.

=back

=back

=head1 DEPENDENCIES

=over

=item *

Log::Log4perl

=item *

MIME::Parser

=item *

bytes

=item *

Date::Manip

=item *

Time::localtime

=item *

R2M::Ad

=back
