#!/bin/bash

tar -cf Talaria.tar bin/* Mod/* cgi/* t/*
sftp rtmadmin@rtmserver <<EOF
cd deploy
rm bin/*
rmdir bin
rm Mod/*
rmdir Mod
rm cgi/*
rmdir cgi
rm t/*
rmdir t
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