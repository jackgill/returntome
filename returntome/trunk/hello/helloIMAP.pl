#!/usr/bin/perl

use strict;
use warnings;

use Net::IMAP::Simple::SSL;
use Email::Simple;

my $server = 'imap.gmail.com';
my $user = 'return.to.me.test@gmail.com';
my $pass = 'return2me';

my $imap = Net::IMAP::Simple::SSL->new($server);

# Log on
if(!$imap->login($user => $pass)){
    print STDERR "Login failed: " . $imap->errstr . "\n";
    exit(64);
}

# Print the subject's of all the messages in the INBOX
my $nm = $imap->select('INBOX');

for(my $i = 1; $i <= $nm; $i++){
    if($imap->seen($i)){
	print "*";
    } else {
	print " ";
    }
    
    my $es = Email::Simple->new(join '', @{ $imap->top($i) } );
    
    printf("[%03d] %s\n", $i, $es->header('Subject'));
}

$imap->quit;
