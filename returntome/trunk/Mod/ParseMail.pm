package Mod::ParseMail;

use warnings;
use strict;

use Exporter;

#use Data::Dumper::Simple;
use Log::Log4perl;
use MIME::Parser;
use File::Path;
use Email::Simple;

use Mod::Ad;

our @ISA = ("Exporter");
our @EXPORT = qw(&parseMail &fromEpoch &parseInstructions &getHeader &now);

=head1 NAME

    Mod::ParseMail

=cut

=head1 SYNOPSIS

    my %message = %{ &parseMail($raw_message,$uid) };

=cut

=head1 DESCRIPTION

    Parses emails.

=cut

=head1 FUNCTIONS

=over 

=cut

my $logger = Log::Log4perl->get_logger();

=item getHeader(mail, header name) 

    Extract the specified header from the given email.

=cut

sub getHeader {
    my $text = shift;
    my $header = shift;
    my $email = Email::Simple->new($text);
    return $email->header($header);
}

=item parseMail(raw message, uid)

    Arguments: The email as a string, and a UID
    Returns: A hashref to a message based on the email.
    The message looks like:
    my %message = (
	mail => $mail,
	uid => $uid,
	return_time => $return_time,
	);

=cut

sub parseMail {
    my $raw_message = shift;
    my $uid = shift;
    
    #parse the mail:
    my $parser = new MIME::Parser;
    my $tmp_dir = '/tmp/mimedump/';
    (-d $tmp_dir) or mkdir $tmp_dir,0755 or die "mkdir: $!";
    (-w $tmp_dir) or die "can't write to directory";
    $parser->output_dir($tmp_dir);
    my $entity = $parser->parse_data($raw_message);    
    
    
    #get the headers:
    my $head = $entity->head;
    my $subject = $head->get('Subject',0);
    my $from = $head->get('From',0);

    my $return_time;
    my $mail = 
	"From: return.to.me.test\@gmail.com\n" .
	"To: $from" .
	"Subject: R2M: $subject" ;    

    #determine if this messages is MIME formatted:
    if ($head->count('MIME-Version')) {#Is MIME formatted
	my $mime_version = $head->get('MIME-Version',0);
	my $content_type = $head->get('Content-Type',0);
	my $effective_type = $entity->effective_type;
	if ($effective_type eq 'multipart/mixed') { #we have attachments
	    my @parts = $entity->parts;
	    for my $part (@parts) {
		#skip over attachments:
		if (my $disp = $part->head->get('Content-Disposition')) {
		    next if $disp =~ /attachment/;
		}
		if ($part->effective_type eq 'text/plain') {
		    $return_time = &parseEntity($part);
		}
		if ($part->effective_type eq 'multipart/alternative') {
		    $return_time = &parseMulti($part);
		}
	    }
	} elsif ($effective_type eq 'multipart/alternative') { #just text/plain and text/html
	    $return_time = &parseMulti($entity);
	} elsif ($entity->effective_type eq 'text/plain') { #just text/plain
	    $return_time = &parseEntity($entity);
	}
	#Prepend MIME headers to mail:
	$mail = 
	    "MIME-Version: $mime_version" . 
	    "Content-Type: $content_type" . 
	    $mail;
    } else {#Not MIME formatted
	$return_time = &parseEntity($entity);
    }
	
    $mail = $mail . "\n" . join('',@{$entity->body});
    rmtree($tmp_dir);

    #TODO: check that $return_time is EITHER undef OR
    #a valid epoch time

    #assemble the message
    my %message = (
	mail => $mail,
	uid => $uid,
	return_time => $return_time,
	);

    #If parsing failed, store the raw message:
    #TODO: check that this works
#    unless ($return_time) {
#	%message{mail} = $raw_message;
#    }

    return \%message;
}

sub parseMulti {
    my $entity = shift;
    my @parts = $entity->parts;
    my $plain_part;
    my $html_part;
    #strategy for parsing multipart/alternative messages:
    #parse text/plain part
    #any error messages in text/plain part are then copied
    #to text/html part

    for my $part (@parts) {
	if ($part->effective_type eq 'text/plain') {
	    $plain_part = $part;
	}
	if ($part->effective_type eq 'text/html') {
	    $html_part = $part;
	}
    }
    my $return_time = &parseEntity($plain_part);
    unless ($return_time) {#if we couldn't parse it, copy over the error message
	my @plain_lines = @{ $plain_part->body };
	my $error_message = $plain_lines[0];
	my @html_lines = @{ $html_part->body };
	chomp $error_message;
	unshift @html_lines, "<b>$error_message</b><br><br>\n";

	my $bh = $html_part->bodyhandle;
	my $IO = $bh->open("w");
	if (not $IO) {
	    $logger->error("Could not open MIME entity body");
	    return;
	}
	$IO->print($_) for (@html_lines);
	my $close = $IO->close; 
	if (not $close) { #TODO: check that this works correctly
	    $logger->error("Could not close MIME entity body");
	    return;
	}
    } else { #parsed messages get ads
	&appendAd($html_part);
    }

    return $return_time;
}

sub appendAd {
    my $entity = shift;
    my @lines = @{ $entity->body };
    
    push @lines, '-' x 70 . '<br>',&getAd;
    my $bh = $entity->bodyhandle;
    my $IO = $bh->open("w");
    if (not $IO) {
	$logger->error("Could not open MIME entity body");
	return;
    }
    $IO->print($_) for (@lines);
    my $close = $IO->close; 
    if (not $close) { #TODO: check that this works correctly
	$logger->error("Could not close MIME entity body");
	return;
    }
}

sub parseEntity {
    my $entity = shift;
    my @text_lines = @{ $entity->body };
    my ($return_time, $lines_ref) = &parsePart(@text_lines);
    @text_lines = @$lines_ref;
    
    #Re-write the body, possibly including an error message:
    my $bh = $entity->bodyhandle;
    my $IO = $bh->open("w");
    if (not $IO) {
	$logger->error("Could not open MIME entity body");
	return;
    }

    $IO->print($_) for (@text_lines);
    my $close = $IO->close; 
    if (not $close) { #TODO: check that this works correctly
	$logger->error("Could not close MIME entity body");
	return;
    }
    return $return_time;
}

sub parsePart {
    my @part = @_;
    my $instructions;
    my $return_date;
    
    #look for instructions:
    for my $line (@part) {
	$instructions = &parseLine($line);
	last if $instructions; #stop looking if instructions were found
    }

    if  ($instructions) {
	$logger->debug("Instructions: $instructions");
	$return_date = &parseInstructions($instructions);
	if ($return_date) {
	    $logger->debug("Return date: $return_date");
	    
	} else {
	    $logger->debug("Could not understand instructions");
	    unshift @part, "Sorry, we could not understand these instructions.\n\n";
	}
    } else {
	$logger->debug("Could not find instructions");
	unshift @part, "Sorry, we could not find instructions in this message.\n\n";
    }

    return $return_date, \@part;
}

sub parseLine {
    my $line = shift;
    #TODO: The regex below needs to be extended to deal with html messages correctly.
    #it needs to ignore leading and trailing html tags (use non-greedy quantifiers inside < >)
    if ($line =~ /^(\s*(R2M|RETURNTOME):?)/i) {
	my $flag = $1;
	my $instructions = $line;
	$instructions =~ s/\n//;
	$instructions =~ s/$flag//;
	return $instructions;
    } else {
	return;
    }
}

###########################################3
#Parse the instructions:
use Date::Manip;

sub parseInstructions {
    my $instructions = shift;
    my $date = ParseDate($instructions);    
    return unless $date;
    my $secs = UnixDate($date,"%s");
    return $secs;
}

=item fromEpoch(time)

    Given a time in epoch seconds, return a formatted string representing that time. For safety, the call to DateTime is wrapped in an eval block.

=cut
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

=item now

    Return a string containing the current time.

=cut

sub now {
    my $dt = DateTime->from_epoch( epoch => time , time_zone => 'America/Denver');
    return $dt->hms . " " . $dt->mdy;
}

=back

=cut

1;
