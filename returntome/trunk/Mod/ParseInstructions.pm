package Mod::ParseInstructions;

use Exporter;

use Date::Manip;

@ISA = ("Exporter");
@EXPORT = qw(&parseInstructions &parseReturnWhen);

sub parseInstructions {
    my $instructions = shift;
    return 'NONE' if ($instructions eq 'NONE');
    #parse the instructions
    #print $instructions,"\n";
    my $date = ParseDate($instructions);
    #print $date,"\n";

    if (! $date) {
	$date = 'NONE';
    }

    return $date;
}
sub parseReturnWhen {
    my $date = shift;
    $date = ParseDate($date);
    return UnixDate($date,"%s");
}
1;
