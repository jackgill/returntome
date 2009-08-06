package MyModule;

use Exporter;

@ISA = ("Exporter");
@EXPORT = qw(&hello);
print "foo\n";
sub hello {
    print "Hello, module!\n";
}
1;
