#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use MIME::Parser;
use File::Path;

#Read in the mail:
open(IN,"<mail.txt") or die "Couldn't open mail";
my @lines = <IN>;
close IN;
my $raw_message = join '', @lines;

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

#get the body:
print '-' x 20," BEFORE:\n";
my @body_lines =  @{$entity->body};
my $body = join '', @body_lines; 
print $body;



#determine if this messages is MIME formatted:
if ($head->count('MIME-Version')) {
    my $mime_version = $head->get('MIME-Version',0);
    my $content_type = $head->get('Content-Type',0);
    if ($entity->is_multipart == 1) { 
	for my $part ($entity->parts) {
	    if ($part->effective_type =~ /text\/plain/) {
		&parseEntity($part);
	    }
	}
    }
}


print '-' x 20," AFTER:\n";
@body_lines =  @{$entity->body};
$body = join '', @body_lines; 
print $body;

rmtree("mimedump-tmp");

sub parseEntity {
    my $part = shift;
    my @text_lines = @{ $part->body };
    unshift @text_lines, "a mod!\n";
    my $bh = $part->bodyhandle;
    my $IO = $bh->open("w")      || die "open body: $!";
    $IO->print($_) for (@text_lines);
    $IO->close                  || die "close I/O handle: $!";
}
