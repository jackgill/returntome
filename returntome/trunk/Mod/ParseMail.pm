package Mod::ParseMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Log::Log4perl;
use MIME::Parser;
use File::Path;

our @ISA = ("Exporter");
our @EXPORT = qw(&parseMail &fromEpoch &parseInstructions);

my $logger = Log::Log4perl->get_logger();

sub parseMail {
    my $raw_message = shift;
    my $uid = shift;
    
    #parse the mail:
    my $parser = new MIME::Parser;
    (-d "mimedump-tmp") or mkdir "mimedump-tmp",0755 or die "mkdir: $!";
    (-w "mimedump-tmp") or die "can't write to directory";
    $parser->output_dir("mimedump-tmp");
    my $entity = $parser->parse_data($raw_message);    
    
    
    #get the headers:
    my $head = $entity->head;
    my $subject = $head->get('Subject',0);
    my $from = $head->get('From',0);

    my $return_time;
    my $mail = 
	"From: return.to.me.test\@gmail.com\n" .
	"To: $from" .
	"Subject: $subject" ;    

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
    rmtree("mimedump-tmp");


    #TODO: check that $return_time is EITHER undef OR
    #a valid epoch time

    #assemble the message
    my %message = (
	address => $from,
	mail => $mail,
	uid => $uid,
	return_time => $return_time,
	);

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
	unshift @html_lines, "<b>$error_message</b><br>\n";
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
    }
    return $return_time;
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
	    unshift @part, "Sorry, we could not understand these instructions.\n";
	}
    } else {
	$logger->debug("Could not find instructions");
	unshift @part, "Sorry, we could not find instructions in this message.\n";
    }

    return $return_date, \@part;
}

sub parseLine {
    my $line = shift;
    #print "Parsing line: $line";
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

use DateTime;

sub fromEpoch {
    my $epoch = shift;
    my $dt = DateTime->from_epoch( epoch => $epoch , time_zone => 'America/Denver');
    return $dt->hms . " " . $dt->mdy;
}

1;
