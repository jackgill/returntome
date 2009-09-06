package Mod::UID;

use 5.010;

use strict;
use warnings;

use Exporter;

use Mod::DB;

our @ISA = qw(Exporter);
our @EXPORT = qw(&getUID);


our $num = 0;
sub getUID {
    my $uid = sprintf "%09d", $num;
    $num++;
    return $uid;
}


1;
