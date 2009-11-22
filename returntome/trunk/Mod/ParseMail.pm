package Mod::ParseMail;

use warnings;
use strict;

use Exporter;

use Log::Log4perl;
use MIME::Parser;
use File::Path;
use Mod::Ad;
use Switch;
use bytes;
use Carp;
use File::Path;

our @ISA = ("Exporter");
our @EXPORT = qw(getHeader parseMail parseInstructions fromEpoch);

my $logger = Log::Log4perl->get_logger();

use Email::Simple;

sub getHeader {
    my ($text, $header_name)  = @_;

    #Parse the mail:
    my $email = Email::Simple->new( $text );

    #Get header value:
    my $header_value = $email->header( $header_name );

    return $header_value;
}

sub parseMail {
    my ($raw_mail, $from_address) = @_;

    #Create the parser:
    my $parser = new MIME::Parser;

    #Set up the temporary directory the parser will write to:
    my $tmp_dir = '/tmp/mimedump/';

    if ( !(-d $tmp_dir) ) { #if the temp dir doesn't exits, create it
        mkdir($tmp_dir, 0755) or die "Couldn't create $tmp_dir: $!"; #TODO: this directory should be permanent
    }
    else {                  #if it does, empty it
        rmtree( $tmp_dir, {keep_root => 1} );
    }

    #Set parser to write to temporary directory:
    $parser->output_dir($tmp_dir);

    #parse the mail:
    my $entity = $parser->parse_data( $raw_mail );

    #Check the parser for errors:
    my $results  = $parser->results;
    my @msgs = $results->msgs;
    $logger->error("Parser Error: $_") for (@msgs);

    #get the headers:
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
	my @headers = ('MIME-Version','Content-Type','Content-Transfer-Encoding');
	for my $header_name (@headers) {
            my $header_value = $head->get($header_name);
            if ($header_value) {
                $parsed_mail .= "$header_name: " . $head->get($header_name);
            }
	}

        #TODO: rewrite using given-when?
	switch($entity->effective_type) {
	    case 'multipart/mixed' { #there are attachments
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
	    case 'multipart/alternative' { #text/plain and text/html only
		for my $part ($entity->parts) {
		    $text_plain = $part if ($part->effective_type eq 'text/plain');
		    $text_html  = $part if ($part->effective_type eq 'text/html');
		}
	    }
	    case 'text/plain' { #text/plain only
		$text_plain = $entity;
	    }
	}
    }
    else {#Message is not MIME formatted
	$text_plain = $entity;
    }

    #Process text/plain and text/html parts:
    my @plain_lines = &readEntity($text_plain);
    my @html_lines = &readEntity($text_html) if $text_html;

    my $error_message;
    my $return_time;

    #Look for instructions:
    my $instructions;
    for my $line (@plain_lines) {
	if ($line =~ /^ \s* (?: r2m | rtm | return \s* to \s* me) :? \s* (.+) \s* $/ixms) {
	    $instructions = $1;
	    last;
	}
    }

    if  ($instructions) { #instructions were found
	$return_time = &parseInstructions($instructions);

	if ($return_time) {#instructions parsing succeeded
	    #Check for return dates in the past:
            if ($return_time lt fromEpoch(time)) {
                $error_message = "You specified a return date in the past.";
            }

	    #Check for return dates too far in the future:
            if ($return_time gt fromEpoch(time + 60 * 60 * 24 * 365)) {
                $error_message = "Sorry, we do not accept messages with a return date more than a year in the future.";
            }
	}
        else {#instructions parsing failed
	    $error_message = "Sorry, we could not understand these instructions.";
	}
    }
    else {#instructions were not found, add an error message:
        $error_message = "Sorry, we could not find instructions in this message.";
    }

    #Check message size:
    $error_message = "Sorry, your message size must be less than 8 MB." if (length($raw_mail) > 8e6);

    #Add an error message or an ad to the message as appropriate:
    if ($error_message) {
	unshift @plain_lines, $error_message . "\n\n";
	unshift @html_lines, "<b>" . $error_message . "</b><br><br>\n\n";
    } else {
	unshift @plain_lines, &getPlainAd . "\n\n";
	unshift @html_lines, &getHTMLAd . ("-" x 70) . "<br><br>";
    }

    #Write the modified message:
    &writeEntity($text_plain,\@plain_lines);
    &writeEntity($text_html,\@html_lines) if $text_html;
    #TODO: check return value on above

    #Add the parsed MIME entity to the mail
    $parsed_mail .= "\n" . join('',@{ $entity->body });

    chomp $from;

    #assemble the message
    my %message = (
	mail => $parsed_mail,
	return_time => $return_time,
	address => $from,
	);

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


use Date::Manip;

sub parseInstructions {
    my $instructions = shift;

    my $result = ParseDate($instructions);
    return unless $result;

    my $date = UnixDate($result,"%Y-%m-%d %T");
    #my $epoch = UnixDate($result,"%s");

    return $date;
}


use DateTime;

sub fromEpoch {
    my $epoch = shift;
    return unless $epoch;

    #TODO: more input validation?

    my $dt = DateTime->from_epoch( epoch => $epoch , time_zone => 'America/Denver');
    return $dt->ymd . " " . $dt->hms;
}

1;

=head1 NAME

Mod::ParseMail

=head1 SYNOPSIS

C<my %message = %{ &parseMail($raw_message, $from) };>

=head1 DESCRIPTION

Parses emails.

=head1 SUBROUTINES

=over

=item *

B<getHeader>

Extract the specified header from the given email.

I<Arguments:>

=over

=item *

mail

=item *

header name

=back

I<Returns:>

=over

=item *

the content of the header

=back

=item *

B<parseMail>

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

Given a time in epoch seconds, return a formatted string representing that time. For safety, the call to DateTime is wrapped in an eval block.

I<Arguments:>

=over

=item *

Time in epoch seconds.

=back

I<Returns:>

=over

=item *

A formatted string represent the time.

=back

=back

=head1 DEPENDENCIES

=over

=item *

Log::Log4perl

=item *

MIME::Parser

=item *

File::Path

=item *

Mod::Ad

=item *

Switch

=item *

bytes

=item *

File::Path

=item *

Email::Simple

=item *

Date::Manip

=item *

DateTime

=back
