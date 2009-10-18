#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Pod::Simple::HTMLBatch;

my $batchconv = Pod::Simple::HTMLBatch->new;
my @search_dirs = qw(Mod bin);
my $output_dir = 'doc';
$batchconv->batch_convert( \@search_dirs, $output_dir );
