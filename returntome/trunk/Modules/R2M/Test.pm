package R2M::Test;

use 5.010;
use Exporter;
use IO::Scalar;
use Date::Manip;
use Time::Piece;

@ISA = qw(Exporter);
@EXPORT = qw(&createMessages &createMail &createReturnWhen &getMessage);

sub createMessages {

    my @messages;
    for my $uid (@uids) {
	push @messages, {
	    uid => $uid,
	    from => 'return.to.me.receive@gmail.com',
	    subject => 'subject $uid',
	    body => 'RETURNTOME: 3:00 pm 06302009\rbody $uid',
	};
    }
    return @messages;
}

sub createMail {
    my @raw_messages;
    for my $uid (@_) {
	open(TEMPLATE,"<raw_message.txt") or die "Couldn't open template.\n";
	my $raw_message;
	my $h = IO::Scalar->new(\$raw_message);
	while (<TEMPLATE>) {
	    if (/(REPLACE<(\w+)>)/) {
		my $rep;
		if ($2 eq 'FROM') {
		    $rep = 'return.to.me.receive@gmail.com';
		}
		if ($2 eq 'SUBJECT') {
		    $rep = "This is the subject line for message $uid.";
		}
		if ($2 eq 'BODY') {
		    $rep = "RETURNTOME: 3:30pm 06-30-2009\rThis is the body for message $uid.";
		}
		s/$1/$rep/;
	    }
	    print $h $_;
	}
	push @raw_messages, $raw_message;
	$h->close;
    }
    return @raw_messages;
}

sub createReturnWhen {
    my $nMessages = 10;
    open(OUT,">return-when.txt") or die "couldn't open return-when.txt for output.\n"; #in the future, open for appending    
    printf OUT "%-9s  %-16s\n",'UID','Date'; #in the future, only print these once
    printf OUT "%-9s  %-16s\n",'-'x9,'-'x16;
    for ($i = 0; $i < $nMessages; $i++) {
	#some time in the next 5 min:
	my $now_time = localtime;
	my $return_time = $now_time + int(rand(5 * 60));
	$return_when = ParseDate($return_time->datetime);
	print OUT &getUID,"  ",$return_when,"\n";
    }
    close OUT;
}
sub getUID {
    state $num = 0;
    my $uid = sprintf "%09d", $num;
    $num++;
    return $uid;
}
sub getMessage {
    my $uid = shift;
    my %message = (uid => $uid);
    return \%message;
}
1;
	
