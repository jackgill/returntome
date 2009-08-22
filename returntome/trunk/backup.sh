#!/bin/bash

ssh rtmadmin@192.168.1.10 <<EOF
svnadmin dump svn > repository
gzip repository
./svn/returntome/trunk/mailTarball.pl repository.gz
logout
EOF