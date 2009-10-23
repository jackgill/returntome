#!/bin/bash

tar -cf Talaria.tar bin/Talaria.pl bin/encrypt.pl bin/decrypt.pl Mod/* cgi/*
sftp rtmadmin@rtmserver <<EOF
cd deploy
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