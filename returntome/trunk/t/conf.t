#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Test::More tests => 2;

use_ok('Mod::Conf') or exit;

my %conf_expected = (
          'db_user' => 'root',
          'db_pass' => 'foo',
          'db_server' => 'ReturnToMe',
          'imap_user' => 'return.to.me.receive@gmail.com',
          'imap_server' => 'imap.gmail.com',
          'interval' => '60',
          'smtp_pass' => 'return2me',
          'db_key' => 'foo',
          'smtp_server' => 'smtp.gmail.com',
          'smtp_user' => 'return.to.me.receive@gmail.com',
          'imap_pass' => 'return2me',
          'admin_address' => 'jack@jackmgill.com'
        );


my %conf_got = %{ getConf('conf/test.conf','foo') };

is(%conf_got, %conf_expected, 'conf/test.conf');
