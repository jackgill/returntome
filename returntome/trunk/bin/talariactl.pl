#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::Crypt;

if (scalar @ARGV != 1) {
    die "Usage: $0 (start|stop|restart)\n";
}

given($ARGV[0]) {
    when ('start') {
        my $key = getCheckedKey('conf/key_digest.conf');

        open(STDIN, "echo '$key' |") or die "Couldn't open STDIN: $!\n";
        system 'bin/talariad.pl incoming';
        close STDIN;

        open(STDIN, "echo '$key' |") or die "Couldn't open STDIN: $!\n";
        system 'bin/talariad.pl outgoing';
        close STDIN;

        open(STDIN, "echo '$key' |") or die "Couldn't open STDIN: $!\n";
        system 'bin/talariad.pl archive';
        close STDIN;
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
    open(my $in,'<','talariad_incoming.pid') or die "Couldn't open talaria_incoming.pid: $!\n";
    my $pid_incoming = <$in>;
    close $in;

    open($in,'<','talariad_outgoing.pid') or die "Couldn't open talaria_outgoing.pid: $!\n";
    my $pid_outgoing = <$in>;
    close $in;

    open($in,'<','talariad_archive.pid') or die "Couldn't open talaria_archive.pid: $!\n";
    my $pid_archive = <$in>;
    close $in;

    return ($pid_incoming, $pid_outgoing, $pid_archive);
}

=head1 NAME

=head1 USAGE

=head1 DESCRIPTION

=head1 DEPENDENCIES
