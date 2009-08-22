#!/bin/bash

tar -cf Talaria.tar Talaria.pl Mod/* conf/*
sftp rtmadmin@192.168.1.10 <<EOF
cd deploy
rm conf/*
rmdir conf
rm Mod/*
rmdir Mod
rm *
put Talaria.tar
bye
EOF
rm Talaria.tar
ssh rtmadmin@192.168.1.10 <<EOF
cd deploy
tar -xf Talaria.tar
logout
EOF