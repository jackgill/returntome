package Mod::ParseMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Log::Log4perl;
#use Email::Simple;
use MIME::Parser;
use File::Path;
use Date::Manip;

our @ISA = ("Exporter");
our @EXPORT = qw(&parseMail &getDate &fromEpoch);

my $logger = Log::Log4perl->get_logger();

sub getDate {
    my $raw_message = shift;
    my $email = Email::Simple->new($raw_message);
    return $email->header('Date');
}

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
    my $body = 
	"From: return.to.me.test\@gmail.com\n" .
	"To: $from" .
	"Subject: $subject" ;    

    #determine if this messages is MIME formatted:
    if ($head->count('MIME-Version')) {
	my $mime_version = $head->get('MIME-Version',0);
	my $content_type = $head->get('Content-Type',0);
	
	if ($entity->is_multipart == 1) { #TO-DO check for undef case
	    my @parts = $entity->parts;
	    for my $part (@parts) {
		if ($part->effective_type eq 'text/plain') {
		    $return_time = &parseEntity($part);
		}
	    }
	} else {
	    if ($entity->effective_type eq 'text/plain') {
		$return_time = &parseEntity($entity);
	    } 
	}
	#Prepend MIME headers to mail:
	$body = 
	    "MIME-Version: $mime_version" . 
	    "Content-Type: $content_type" . 
	    $body;
    } else {
	$return_time = &parseEntity($entity);
    }
	
    $body = $body . "\n" . join('',@{$entity->body});
    rmtree("mimedump-tmp");

    #assemble the message
    my %message = (
	address => $from,
	body => $body,
	uid => $uid,
	return_time => $return_time,
	);

    return \%message;
}

sub parseEntity {
    my $entity = shift;
    my @text_lines = @{ $entity->body };
    my ($return_time, $lines_ref) = &parsePart(@text_lines);
    @text_lines = @$lines_ref;
    
    #Re-write the body, possibly including an error message:
    my $bh = $entity->bodyhandle;
    my $IO = $bh->open("w")      || die "open body: $!";
    $IO->print($_) for (@text_lines);
    $IO->close                  || die "close I/O handle: $!";

    return $return_time;
}

sub parsePart {
    my @part = @_;
    my $instructions;
    my $return_date;
    for my $line (@part) {
	#If we've already found the instructions, don't bother parsing:
	next if $instructions;
	$instructions = &parseLine($line);
	if ($instructions) {
	    $return_date = &parseInstructions($instructions);
	}
    }

    if  ($instructions) {
	$logger->debug("Instructions: $instructions");
	if ($return_date) {
	    $logger->debug("Return date: $return_date");
	} else {
	    unshift @part, "Sorry, we could not understand these instructions.\n";
	}
    } else {
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
	return undef;
    }
}
###########################################3
#Parse the instructions:
use Date::Manip;

sub parseInstructions {
    my $instructions = shift;
    my $date = ParseDate($instructions);    
    return undef unless $date;
    my $secs = UnixDate($date,"%s");
    return $secs;
}

use DateTime;

sub fromEpoch {
    my $epoch = shift;
    my $dt = DateTime->from_epoch( epoch => $epoch , time_zone => 'America/Denver');
    return $dt->hms . " " . $dt->mdy;
}

sub getReturnDate {
    my $text = shift;

    my @lines = split(/\r/,$text); #break it into lines
    my $instructions = 'NONE';

    #extract the instructions
    for my $line (@lines) {
	if ($line =~ /^(\s*(R2M|RETURNTOME):?)/i) {
	    $instructions = $line;
	    $instructions =~ s/\n//;
	    $instructions =~ s/$1//;
	}
    }
    if ($instructions eq 'NONE') {
	$logger->info('Could not find instructions!');
	return 'NONE'; 
    } else {
	$logger->info("Instructions: $instructions");
    }
    my $date = ParseDate($instructions);
    
    return 'NONE' unless $date;
    
    my $secs = UnixDate($date,"%s");

    return $secs;
}

1;
