#!/bin/bash

ssh rtmadmin@RTMSERVER <<EOF
svnadmin dump svn > repository
gzip repository
./mailAttachment.pl repository.gz application/x-gzip
rm repository.gz
logout
EOF
