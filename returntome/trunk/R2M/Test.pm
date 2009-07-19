package R2M::Test;

use 5.010;

use warnings;
use strict;

use Exporter;
use R2M::UID;
use IO::Scalar;
use Date::Manip;
use Time::Piece;
use MIME::Lite;
use Data::Dumper::Simple;

our @ISA = qw(Exporter);
our @EXPORT = qw(&createMessages &createMail &createReturnWhen &getMail &sendMessages);

sub sendMessages {
    my $from = shift;
    my $password = shift;
    my @messages = @_;
    my $logger = Log::Log4perl->get_logger();
    $logger->info('Called &sendMessages with:');
    $logger->info("\t\$from = $from");
    $logger->info("\t\$password = $password");
    for (@messages) {
	my %message = %$_;
	$logger->info(Dumper(%message));
    }
}
my $nGetMailCalls = 0;
sub getMail {
    return () unless ($nGetMailCalls == 0);
    my @uids;
    for (my $i = 0; $i < 2; $i++) {
	push @uids, &getUID;
    }
    my @messages = &createMessages(@uids);
    my @mail = &createMail(@messages);
    return @mail;
}
sub createMessages {
    my @messages;
    for my $uid (@_) {
	my $now = localtime;
	my $wait =  int(rand(2 * 60));
	my $return_time = $now + $wait;
	my $return_when =$return_time->datetime;
	push @messages, {uid => $uid, 
			 from => 'return.to.me.receive@gmail.com',
			 subject => "subject $uid", 
			 body => "R2M: $return_when \r\nbody $uid",
	};
    }
    return @messages;
}

sub createMail {
    my @mail;
    for (@_) {
	my %message = %$_;
	my $msg = MIME::Lite->new(
	    From    => $message{'from'},
	    To      => 'return.to.me.test@gmail.com',
	    Subject => $message{'subject'},
	    Type    => 'multipart/mixed',
	    );
	$msg->attach(
	    Type     => 'text/plain',
	    Data     => $message{'body'},
	    );
	$msg->attach(
	    Type => 'text/html',
	    Data => '<br>' . $message{'body'} . '<br>',
	    );
	push @mail, $msg->as_string;
    }
    return @mail;
}

sub createReturnWhen {
    my $nMessages = 10;
    open(OUT,">return-when.txt") or die "couldn't open return-when.txt for output.\n"; #in the future, open for appending    
    printf OUT "%-9s  %-16s\n",'UID','Date'; #in the future, only print these once
    printf OUT "%-9s  %-16s\n",'-'x9,'-'x16;
    for (my $i = 0; $i < $nMessages; $i++) {
	#some time in the next 5 min:
	my $now_time = localtime;
	my $return_time = $now_time + int(rand(5 * 60));
	my $return_when = ParseDate($return_time->datetime);
	print OUT &getUID,"  ",$return_when,"\n";
    }
    close OUT;
}
1;
	
