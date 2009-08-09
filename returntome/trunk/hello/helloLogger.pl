#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Log::Log4perl;

Log::Log4perl::init('log4perl.conf');

my $logger = Log::Log4perl->get_logger('debug');
$logger->info('This is an info statement');
$logger->debug('This is a debug statement');
