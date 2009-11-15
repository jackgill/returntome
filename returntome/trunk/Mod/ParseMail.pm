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
our @EXPORT = qw(&getHeader &parseMail &parseInstructions &fromEpoch &now);


my $logger = Log::Log4perl->get_logger();

use Email::Simple;

sub getHeader {
    my $text = shift;
    my $header = shift;
    croak "null argument!" unless ($text && $header);
    my $email = Email::Simple->new($text);
    return $email->header($header);
}

sub parseMail {
    my $raw_mail = shift;
    my $outgoing = shift;

    #Create the parser:
    my $parser = new MIME::Parser;

    #Set up the temporary directory the parser will write to:
    my $tmp_dir = '/tmp/mimedump/';

    (-d $tmp_dir) or mkdir $tmp_dir,0755 or die "mkdir: $!"; #TODO: this directory should be permanent
    rmtree( $tmp_dir, {keep_root => 1} );
    (-w $tmp_dir) or die "can't write to directory";
    $parser->output_dir($tmp_dir);

    #parse the mail:
    my $entity = $parser->parse_data($raw_mail);

    #Check the parser for errors:
    my $results  = $parser->results;
    my @msgs = $results->msgs;
    $logger->error("Parser Error: $_") for (@msgs);    
    
    #get the headers:
    my $head = $entity->head;
    my $subject = $head->get('Subject',0);
    $subject = "\n" unless $subject;
    my $from = $head->get('From',0);

    #Initialize mail with basic headers:
    my $parsed_mail = 
	"From: $outgoing\n" .
	"To: $from" .
	"Subject: R2M: $subject" ;    #TODO: What if subject is encoded? MIME::Head->decode('I_KNOW_WHAT_I_AM_DOING')

    #Find the text/plain and text/html parts of the message:
    my $text_plain;
    my $text_html;

    if ($head->count('MIME-Version')) {#Message is MIME formatted
	#Add MIME headers to mail:
	my @headers = ('MIME-Version','Content-Type','Content-Transfer-Encoding');
	for my $header (@headers) {
	    $parsed_mail .= "$header: " . $head->get($header);
	}

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
    } else {#Message is not MIME formatted
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
	    $error_message = "You specified a return date in the past." if ($return_time < time);

	    #Check for return dates too far in the future:
	    $error_message = "Sorry, we do not accept messages with a return date more than a year in the future." if ($return_time > time + 60 * 60 * 24 * 365);
	} else {#instructions parsing failed
	    $error_message = "Sorry, we could not understand these instructions.";
	}
    } else {#instructions were not found, add an error message:
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

    #Add the parsed MIME entity to the mail
    $parsed_mail .= "\n" . join('',@{ $entity->body });

    #assemble the message
    my %message = (
	raw_mail => $raw_mail,
	parsed_mail => $parsed_mail,
	return_time => $return_time,
	address => $from,
	);

    return \%message;
}


sub readEntity {
    my $entity = shift;
    my $bh = $entity->bodyhandle;

    my @lines; 
    my $io = $bh->open("r");
    if (not $io) {
	$logger->error("Could not open MIME entity body");
	return ();
    }
    while (defined($_ = $io->getline)) { push @lines, $_ }
    if (not $io->close) {
	$logger->error("Could not close MIME entity body");
	return ();	
    } 
    return @lines;
}

sub writeEntity {
    my $entity = shift;
    my $line_ref = shift;
    my @lines = @$line_ref;

    my $bh = $entity->bodyhandle;
    my $io = $bh->open("w");
    if (not $io) {
	$logger->error("Could not open MIME entity body");
	return 0;
    }
    $io->print($_) for (@lines);
    if (not $io->close) {
	$logger->error("Could not close MIME entity body");
	return 0;	
    } 
    return 1;
}


use Date::Manip;

sub parseInstructions {
    my $instructions = shift;
    my $date = ParseDate($instructions);    
    return unless $date;
    my $secs = UnixDate($date,"%s");
    return $secs;
}


use DateTime;

sub fromEpoch {
    my $epoch = shift;
    my $dt;
    eval {$dt = DateTime->from_epoch( epoch => $epoch , time_zone => 'America/Denver');};
    if ($@) {
	$logger->error($@);
	return "error";
    } else {
	return $dt->hms . " " . $dt->mdy;
    }
}


sub now {
    return &fromEpoch(time);
}


1;

=head1 NAME

    Mod::ParseMail

=cut

=head1 SYNOPSIS

    my %message = %{ &parseMail($raw_message, $from) };

=cut

=head1 DESCRIPTION

    Parses emails.

=cut

=head1 FUNCTIONS

=over 

=cut

=item getHeader(mail, header name) 

    Extract the specified header from the given email.

=cut

=item parseMail(raw message, uid)

    Extract the return time from the email. 
    Add error messages or ads as necessary.
    Arguments: The email as a string, UID, 'From' address
    Returns: A hashref to a message based on the email.
    The message looks like:
    my %message = (
    mail => $mail,
    return_time => $return_time,
    address => $from,
    );

=cut

=item readEntity(MIME entity)
    
    Get an array of lines representing the body of a MIME::Entity.
    Arguments: A reference to a MIME::Entity.
    Returns: A array of lines.

=cut

=item writeEntity(entity, lines_ref)

    Write an array of lines to the body of a MIME::Entity.
    Arguments: A reference to a MIME::Entity, a reference to an array of lines.
    Returns: 1 if write succeeded, 0 if write failed.

=cut

=item parseInstructions(instructions)

    Extract a return time from the given instructions.
    Arguments: A string containing the instructions.
    Returns: Either a time in epoch seconds or undef.

=cut

=item fromEpoch(time)

    Given a time in epoch seconds, return a formatted string representing that time. For safety, the call to DateTime is wrapped in an eval block.

=cut

=item now

    Return a string containing the current time.

=cut

=back

=cut
