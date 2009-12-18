#!/bin/bash

#create tarball for deployment
tar -cf Talaria.tar bin/* lib/R2M/* cgi/* t/*

#put tarball on test host
sftp rtmadmin@rtmserver <<EOF
cd deploy
put Talaria.tar
bye
EOF

#Remove tarball on local host
rm Talaria.tar

#remove old files and unpack tarball on test host
ssh rtmadmin@rtmserver <<EOF
cd deploy
rm -rf bin
rm -rf cgi
rm -rf lib
rm -rf t
tar -xf Talaria.tar
rm Talaria.tar
logout
EOF
