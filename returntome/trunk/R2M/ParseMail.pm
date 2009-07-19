package R2M::ParseMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
#use Log::Log4perl;
#use Email::Simple;
use MIME::Parser;
use File::Path;
use Date::Manip;

our @ISA = ("Exporter");
our @EXPORT = qw(&parseMail &getDate);

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

 
    #extract the messages fields from the parsed mail
    my $head = $entity->head;
    my $subject = $head->get('Subject',0);
    my $from = $head->get('From',0);
    my $body = join '', @{$entity->body}; #TO-DO check to see if this is unmodified by the parser
    my $text = 'none';
    if ($entity->is_multipart == 1) { #TO-DO check for undef case
	my @parts = $entity->parts;
	for my $part (@parts) {
	    #print "Part: ",$part->effective_type,"\n";
	    if ($part->effective_type eq 'text/plain') {
		$text = join '', @{$part->body}; 
	    }
	}
    } else {
	if ($entity->effective_type eq 'text/plain') {
	    $text = $body;
	}
    }


    rmtree("mimedump-tmp");

    my $return_time = &getReturnDate($text);

    #assemble the message
    my %message = (
	address => $from,
	subject => $subject,
	body => $body,
	uid => $uid,
	return_time => $return_time,
	);

    return \%message;
}

sub getReturnDate {
    my $text = shift;

    my @lines = split(/\r/,$text); #break it into lines
    my $instructions = 'NONE';

    #extract the instructions
    for my $line (@lines) {
	#print $line;
	if ($line =~ /^\s*(R2M|RETURNTOME):?/i) {
	    $line =~ s/\n//; #be smarter about this and the above line
	    $instructions = $line;
	    $instructions =~ s/^\s*(R2M|RETURNTOME):?//;
	}
	 
    }

    return 'NONE' if ($instructions eq 'NONE');

    my $date = ParseDate($instructions);
    
    return 'NONE' unless $date;
    
    my $secs = UnixDate($date,"%s");

    return $secs;
}

1;
