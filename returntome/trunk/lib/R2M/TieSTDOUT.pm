package Mod::TieSTDOUT;

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
    $logger->info('STDOUT: ' . $text);
}

1;

=head1 NAME

Mod::TieSTDOUT

=head1 SYNOPSIS

C<tie(*STDOUT, 'Mod::TieSTDOUT');>

=head1 DESCRIPTION

Tie STDOUT to the Log4perl logger.

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
