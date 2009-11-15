cd ..
tar -cf trunk.tar trunk
gzip trunk.tar
mv trunk.tar.gz trunk
cd trunk
bin/mailAttachment.pl trunk.tar.gz application/x-gzip
rm trunk.tar.gz
