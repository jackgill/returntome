use warnings;
use strict;

use Tk;
use Tk::DialogBox;

use Time::localtime;

our $showing = 0;
our $last_click = time;

my $main = MainWindow->new(-title => "Stop Work");
my $dialog = $main->DialogBox( -title => "Stop Working!",
			       -buttons => ["Dismiss"],
    );
$dialog->add("Label", -text => "Stop working!")->pack();
#$dialog->add("Label", -text => "Stop working!")->pack();
my $start_time = &getCurrentTime;
$main->Label( -text => "You started work at $start_time")->pack();
$main->Button( -text => "Quit", -command => sub {exit})->pack(-side => "left");
$main->Button( -text => "Reset", -command => sub {$last_click = time})->pack(-side => "left");
#my $opts = $dialog->ConfigSpecs();

my @children = $dialog->children();
#for (@children) {
#    print $_->name,"\n";
#    my $opts = $_->ConfigSpecs();
#    my %opts = %$opts;
#    for (keys %opts) {
#	print "$_ = %opts{$_}\n";
#    }
#}

&start;
MainLoop;

sub start {
    my $main_ref = shift;
    while(1) {
	if ((time - $last_click) == (60*30)) {
	    if ($showing == 0) {
		&showDialog;
	    }
	}
	$main->update();
    }   
}


sub showDialog{
    $showing = 1;
    while ($showing == 1) {
	my @children = $dialog->children();
	my $top = $children[0];
	my $stop_time = &getStopTime;
	$top->configure(-label => "You can go back to work at $stop_time");
	$main->focusForce();
	my $button = $dialog->Show;
	if ($button eq "Dismiss") {
	    $last_click = time;
	    $showing = 0
	}
    }
}

sub getStopTime {
    my $time = localtime(time);
    my $hour = $time->hour;

    my $min = $time->min;
    $min += 5;
    if ($min > 59) {
	$min -= 60;
	$hour += 1;
    }
    $hour -= 12 if $hour > 12;	
    $hour = 12 if $hour == 0;
    my $display = sprintf "$hour:%02g",$min;
    return $display;
}

sub getCurrentTime{
    my $time = localtime(time);
    my $hour = $time->hour;
    my $min = $time->min;
    $hour -= 12 if $hour > 12;	
    $hour = 12 if $hour == 0;
    my $display = sprintf "$hour:%02g",$min;
    return $display;
}
