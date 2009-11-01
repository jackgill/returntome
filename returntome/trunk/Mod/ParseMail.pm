package Mod::ParseMail;

use warnings;
use strict;

use Exporter;

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

    Extract the return time from the email. 
    Add error messages or ads as necessary.
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
    
    #TODO: raw message should be saved.

    #Create the parser:
    my $parser = new MIME::Parser;

    #Set up the temporary directory the parser will write to:
    my $tmp_dir = '/tmp/mimedump/';
    (-d $tmp_dir) or mkdir $tmp_dir,0755 or die "mkdir: $!"; #TODO: this directory should be permanent
    (-w $tmp_dir) or die "can't write to directory";
    $parser->output_dir($tmp_dir);

    #parse the mail:
    my $entity = $parser->parse_data($raw_message);    

    #Check the parser for errors:
    my $results  = $parser->results;
    my @msgs = $results->msgs;
    $logger->info($_) for (@msgs);    
    
    #get the headers:
    my $head = $entity->head;
    my $subject = $head->get('Subject',0);
    my $from = $head->get('From',0);

    #Either epoch seconds or undef:
    my $return_time;

    #Initialize mail with basic headers:
    my $mail = 
	"From: return.to.me.test\@gmail.com\n" .
	"To: $from" .
	"Subject: R2M: $subject" ;    

    #determine if this messages is MIME formatted:
    if ($head->count('MIME-Version')) {#Message is MIME formatted
	#Add MIME headers to mail:
	$mail .= 
	    "MIME-Version: " . $head->get('MIME-Version',0) .
	    "Content-Type: " . $head->get('Content-Type',0);

	my $effective_type = $entity->effective_type;
	if ($effective_type eq 'multipart/mixed') { #we have attachments
	    my @parts = $entity->parts;
	    for my $part (@parts) {
		#skip over attachments:
		if (my $disp = $part->head->get('Content-Disposition')) {
		    next if $disp =~ /attachment/;
		}
		if ($part->effective_type eq 'multipart/alternative') {
		    $return_time = &parseMulti($part);
		    last;
		}
		if ($part->effective_type eq 'text/plain') {
		    $return_time = &parseText($part);
		    last;
		}
	    }
	} elsif ($effective_type eq 'multipart/alternative') { #text/plain and text/html only
	    $return_time = &parseMulti($entity);
	} elsif ($entity->effective_type eq 'text/plain') { #text/plain only
	    $return_time = &parseText($entity);
	}

    } else {#Message is not MIME formatted
	$return_time = &parseText($entity);
    }
	
    #Add the parsed MIME entity to the mail
    $mail .= "\n" . join('',@{ $entity->body });

    #assemble the message
    my %message = (
	mail => $mail,
	uid => $uid,
	return_time => $return_time,
	);

    return \%message;
}

=item parseMulti($entity)
    
    Parse a multipart/alternative MIME entity.
    Arguments: a reference to the MIME entity.
    Returns: either undef or the return time in epoch seconds.
    Note that this function alters the MIME entity to include error messages or ads.

=cut

sub parseMulti {
    my $entity = shift;
    my @parts = $entity->parts;

    #multipart/alternative contains text/plain and text/html:
    my $plain_part;
    my $html_part;

    #strategy for parsing multipart/alternative messages:
    #1) parse text/plain part
    #2) any error messages in text/plain part are then copied to text/html part
    #3) an ad is appened to text/html part

    #Find the text/plain and text/html parts:
    for my $part (@parts) {
	if ($part->effective_type eq 'text/plain') {
	    $plain_part = $part;
	}
	if ($part->effective_type eq 'text/html') {
	    $html_part = $part;
	}
    }
    
    #Parse the text/plain part:
    my $return_time = &parseText($plain_part);

    #Modify the text/html part with error messages & ads:
    my @html_lines = &readEntity($html_part);

    unless ($return_time) {#If parsing failed, the first line of text/plain is an error message:
	#Get error message:
	my @plain_lines = &readEntity($plain_part);
	my $error_message = $plain_lines[0];
	chomp $error_message;
	#Prepend it to html part:
	unshift @html_lines, "<b>$error_message</b><br><br>\n";
    } else {#If parsing succeeded, append an ad:
	push @html_lines, '-' x 70 . '<br>',&getAd;
    }

    &writeEntity($html_part,\@html_lines);

    return $return_time;
}

=item parseText($entity)

    Parse a text/plain MIME entity for intructions.
    Arguments: A reference to the MIME entity.
    Returns: Either undef or the return time in epoch seconds.
    Note that this subroutine modifies the MIME entity to include an error message if necessary.

=cut

sub parseText {
    my $entity = shift;

    #Read message:
    my @lines = &readEntity($entity);

    my $instructions; #e.g. R2M: tomorrow
    my $return_time; #either undef or epoch seconds
    
    #look for instructions:
    for (@lines) {
	if (/^(\s*(R2M|RTM|RETURNTOME):?)/i) {
	    my $flag = $1;
	    my $instructions = $_;
	    chomp $instructions;# =~ s/\n//;
	    $instructions =~ s/$flag//;
	    last;
	}
    }

    if  ($instructions) { #instructions were found
	$logger->debug("Instructions: $instructions");
	$return_time = &parseInstructions($instructions);
	if ($return_time) { #instructions parsing succeeded:
	    $logger->debug("Return time: $return_time");	    
	} else { #instructions parsing failed, add an error message:
	    $logger->debug("Could not understand instructions");
	    unshift @lines, "Sorry, we could not understand these instructions.\n\n";
	}
    } else {#instructions were not found, add an error message:
	$logger->debug("Could not find instructions");
	unshift @lines, "Sorry, we could not find instructions in this message.\n\n";
    }
    
    #Add the possibly modified body to the MIME entity:
    &writeEntity($entity,\@lines);

    return $return_time;
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
