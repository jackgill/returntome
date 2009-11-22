package Mod::TieSTDERR;

use 5.010;

use strict;
use warnings;

use Log::Log4perl;

sub TIEHANDLE {
    my $class = shift;
    bless [], $class;
}

sub PRINT {
    my $self = shift;
    my @lines = @_;
    chomp @lines;
    my $text = join '',@lines;
    my $logger = Log::Log4perl->get_logger();
    $logger->info('STDERR: ' . $text);
}

1;

=head1 NAME

Mod::TieSTDERR

=head1 SYNOPSIS

C<tie(*STDERR, 'Mod::TieSTDERR');>

=head1 DESCRIPTION

Tie STDERR to the Log4perl logger.

=head1 SUBROUTINES

=over

=item *

B<TIEHANDLE>

=item *

B<PRINT>

=back

=head1 DEPENDENCIES

=over

=item *

Log::Log4perl

=back
