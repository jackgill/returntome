#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Data::Dumper::Simple;

use Mod::Crypt;
use Mod::Test;
use Mod::Conf;
use Mod::DB;

Log::Log4perl::init('conf/log4perl_test.conf');

my %conf = %{ &getConf("conf/test.conf") };
&connect("mysql:database=" . $conf{db_server},$conf{db_user},$conf{db_pass});

&main;
#&testEncryptMessages;
#&testDecryptMessages;

&disconnect;

sub main {
    my $key = &getCheckedKey('digest');
    my $plain_text = "This is some plain text.";
    my $encrypted = &encrypt($key, $plain_text);
    my $decrypted = &decrypt($key, $encrypted);
    print "key: $key\n";
    print "plain text: $plain_text\n";
    print "encrypted : $encrypted\n";
    print "decrypted : $decrypted\n";
}

sub testEncryptMessages {
    my $key = &getKey;
    my @plain_messages = &createMessages(2,2);
    my @cipher_messages = &encryptMessages($key,@plain_messages);
    print Dumper(@cipher_messages);
}

sub testDecryptMessages {
    my $key = &getKey;
    my @plain_messages = &createMessages(2,2);
    print Dumper(@plain_messages);
    my @cipher_messages = &encryptMessages($key,@plain_messages);
    print Dumper(@cipher_messages);
    my @decrypted_messages = &decryptMessages($key,@cipher_messages);
    print Dumper(@decrypted_messages);
}
