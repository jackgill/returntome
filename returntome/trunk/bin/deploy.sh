#!/bin/bash

tar -cf Talaria.tar bin/* Mod/* cgi/* t/*
sftp rtmadmin@rtmserver <<EOF
cd deploy
rm -rf bin
rm -rf Mod
rm -rf cgi
rm -rf t
put Talaria.tar
bye
EOF
rm Talaria.tar
ssh rtmadmin@rtmserver <<EOF
cd deploy
tar -xf Talaria.tar
rm Talaria.tar
logout
EOF