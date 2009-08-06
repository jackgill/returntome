package Mod::UID;

use 5.010;

use strict;
use warnings;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(&getUID);

my $num = 0;

sub getUID {
    my $uid = sprintf "%09d", $num;
    $num++;
    return $uid;
}


1;
