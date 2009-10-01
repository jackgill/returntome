#!/bin/bash

tar -cf Talaria.tar bin/Talaria.pl Mod/* cgi/*
sftp rtmadmin@rtm.dyndns.org <<EOF
cd deploy
rm Mod/*
rmdir Mod
rm cgi/*
rmdir cgi
rm *
put Talaria.tar
bye
EOF
rm Talaria.tar
ssh rtmadmin@rtm.dyndns.org <<EOF
cd deploy
tar -xf Talaria.tar
rm Talaria.tar
logout
EOF