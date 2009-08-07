#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use TieHandle;

tie(*STDERR, 'TieHandle');
warn "this is a warning\n";

