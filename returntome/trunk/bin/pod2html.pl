#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Pod::Simple::HTMLBatch;

#TODO: roll my own index page to separate programs from modules

my $batchconv = Pod::Simple::HTMLBatch->new;
my @search_dirs = qw(lib/R2M bin);
my $output_dir = 'doc';
my $html_start = <<'END_HTML';
<html>
  <head><title>Return To Me POD</title></head>
  <body class='contentspage'>
  <h1>Return To Me POD</h1>

END_HTML

$batchconv->verbose(0); #No output on STDOUT
$batchconv->contents_page_start($html_start);
$batchconv->batch_convert( \@search_dirs, $output_dir );

=head1 NAME

makeDoc.pl

=head1 USAGE

C<bin/pod2html.pl>

=head1 DESCRIPTION

This script translates all POD in the lib/R2M and bin subdirectories to html.

=head1 DEPENDENCIES

=over

=item *

Pod::Simple::HTMLBatch

=back
