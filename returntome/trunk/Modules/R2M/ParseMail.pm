package R2M::ParseMail;

use warnings;
use strict;

use Exporter;
use Data::Dumper::Simple;
use Log::Log4perl qw(get_logger);

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
    
    my $logger = get_logger();
    $logger->debug("Raw Message $uid:");
    $logger->debug($raw_message);

    #parse the email
    my $email = Email::Simple->new($raw_message);
    my $subject = $email->header('Subject');
    my $from = $email->header('From');
    if ($from =~ /<(.*)>/) {
	#$from = $1;
    }
    my $body = $email->body();

    my $content_type = $email->header('Content-Type');
    #print $content_type,"\n";
    if ($content_type) {
	if ($content_type =~ m/multipart\/alternative; boundary="(.+)"/) {
	    my $separator = $1;
	    #print $separator,"\n";
	    my @pieces = split(/--$1/,$body);
	    for my $piece (@pieces) {
		
		if ($piece =~ /Content-Type: text\/plain/) {
		    #print $piece;
		    my @lines = split (/\n/,$piece);
		    $body = '';
		    for my $line (@lines) {
			next if ($line =~ /^Content-Type:/);
			next if ($line =~ /^\r/);
			#printf "%vd\n",$line;
			$body .= $line . "\n";
		    }
		}
	    }
	}
    }
    #debug: get the header names
    #my @header_names = $email->header_names;
    #print Dumper(@header_names);

    my ($content_ref, $instructions) = &parseBody($body);
    my $content = join '', @$content_ref;
    #assemble the message
    my %message = (
	from => $from,
	subject => $subject,
	body => $content,
	uid => $uid,
	);
    

    $logger->debug('Extracted Message:');
    $logger->debug(Dumper(%message));
    $logger->debug('Instructions');
    $logger->debug($instructions);

    return \%message,$instructions;
}

sub parseBody {
    my $body = shift;

    my @lines = split(/\r/,$body); #break it into lines
    
    #split the body into 2 parts:
    my @content;
    my $instructions = 'NONE';

    #extract the instructions
    for my $line (@lines) {
	if ($line =~ /^\s*(R2M|RETURNTOME):?/i) {
	    $line =~ s/\n//; #be smarter about this and the above line
	    $instructions = $line;
	    $instructions =~ s/^\s*(R2M|RETURNTOME):?//;
	} else {
	    push @content,$line;
	}
    }

    return (\@content, $instructions);
}

1;
