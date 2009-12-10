#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 4;
use Smart::Comments;

use Mod::Test;
use Mod::Conf;

BEGIN {
    use_ok('Mod::SendMail');
    use_ok('Mod::GetMail');
}

#Initalize logger:
Log::Log4perl::init('conf/log4perl_test.conf');

#Read conf variables:
my %conf = %{ getConf('conf/test.conf','foo') };

#Clear inbox:
getMail( @conf{'imap_server', 'imap_user', 'imap_pass'} );

#Create messages:
my @sent_messages = createMessages(2, 2, 'return.to.me.receive@gmail.com');

#Send messages:
my @sent_uids = sendMessages(@conf{'smtp_server', 'smtp_user' , 'smtp_pass'}, @sent_messages);

is(scalar @sent_uids, 2, 'Send Messages');

#Wait:
for (my $i = 0; $i < 15; $i++) { ### Waiting...  done
    sleep 1;
}
print "\n";

#Get messages:
my @got_messages = getMail( @conf{'imap_server', 'imap_user', 'imap_pass'} );

is(scalar @got_messages, 2, 'Received Messages');

for my $message (@got_messages) {
    #print $message;
    #print "\n",'-' x 78,"\n";
}
