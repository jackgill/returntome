#!/usr/bin/perl

use 5.010;
use strict;
use warnings;

use R2M::Crypt;

if (scalar @ARGV != 1) {
    die "Usage: $0 (start|stop|restart)\n";
}

given($ARGV[0]) {
    when ('start') {
        my $key = get_checked_key('conf/key_digest.conf');

        open(STDOUT, '>', '/dev/null'  ) or die "Couldn't open STDOUT: $!\n";
        for my $mode (qw (incoming outgoing archive)) {
            open(STDIN , "echo '$key' |") or die "Couldn't open STDIN: $!\n";
            system "bin/talariad.pl $mode";
            close STDIN;
        }
        close STDOUT;
    }
    when ('stop') {
        kill 'SIGTERM', get_pids();
    }
    when ('restart') {
        kill 'SIGHUP', get_pids();
    }
}

sub get_pids {
    my @pids;

    for my $file (qw(talariad_incoming.pid talariad_outgoing.pid talariad_archive.pid)) {
        open(my $in, '<', $file) or die "Couldn't open $file $!\n";
        my $pid = <$in>;
        close $in;
        push @pids, $pid;
    }

    return @pids;
}

=head1 NAME

talariactl.pl

=head1 USAGE

C<talariactl.pl (start|stop|restart)>

=head1 DESCRIPTION

Start, stop, or restart all 3 Talaria daemons.

=head1 DEPENDENCIES

=over

=item *

R2M::Crypt

=back
