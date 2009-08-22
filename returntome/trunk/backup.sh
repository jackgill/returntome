#!/bin/bash

ssh rtmadmin@192.168.1.10 <<EOF
svnadmin dump svn > repository
tar -cf repository.tar repository
gzip repository.tar
./mailTarball.pl repository.tar.gz
rm repository.tar.gz
rm repository
logout
EOF