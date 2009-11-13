#!/bin/bash

tar -cf Talaria.tar bin/* Mod/* cgi/*
sftp rtmadmin@rtmserver <<EOF
cd deploy
rm bin/*
rmdir bin
rm Mod/*
rmdir Mod
rm cgi/*
rmdir cgi
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