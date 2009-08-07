package Mod::TieHandle;

use 5.010;

use strict;
use warnings;

#use Exporter;

#our @ISA = qw(Exporter);
#our @EXPORT = qw();
use Log::Log4perl;
    
sub TIEHANDLE {
    my $class = shift;
    bless [], $class;
}

sub PRINT {
    my $self = shift;
    my $text = join '',@_;
    my $logger = Log::Log4perl->get_logger();
    $logger->info('STDERR: ' . $text);
}


1;
