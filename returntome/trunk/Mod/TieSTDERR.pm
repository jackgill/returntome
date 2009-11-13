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
