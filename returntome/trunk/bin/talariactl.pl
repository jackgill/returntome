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

        my @modes = qw (incoming outgoing archive);
        for my $mode (@modes) {
            open(STDIN, "echo '$key' |") or die "Couldn't open STDIN: $!\n";
            system "bin/talariad.pl archive";
            close STDIN;
        }
    }
    when ('stop') {
        my @pids = get_pids();

        kill 'SIGTERM', @pids;
    }
    when ('restart') {
        my @pids = get_pids();

        kill 'SIGHUP', @pids;
    }
}

sub get_pids {
    my @pids;
    my @files = qw(talariad_incoming.pid talariad_outgoing.pid talariad_archive.pid);

    for my $file (@files) {
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
