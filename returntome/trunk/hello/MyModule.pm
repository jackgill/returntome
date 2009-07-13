package MyModule;

use Exporter;

@ISA = ("Exporter");
@EXPORT = qw(&hello);
sub hello {
    print "Hello, module!\n";
}
1;
