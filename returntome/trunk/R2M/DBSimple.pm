package R2M::DBSimple;

use strict;
use warnings;

use Exporter;

use Data::Dumper::Simple;
use Storable;

our @ISA = ("Exporter");
our @EXPORT = qw(&putMessage &getMessage);

sub putMessage {
    my %message = %{ shift @_ };
    #print Dumper(%message);
    my $uid = $message{'uid'};
    store \%message, "/home/jack/returntome/sandbox/Messages/message_$uid.stored";
}

sub getMessage {
    my $uid = shift;
    my %message = %{ retrieve "/home/jack/returntome/sandbox/Messages/message_$uid.stored" };
    return \%message;
}

1;
