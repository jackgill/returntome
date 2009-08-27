#!/bin/bash

tar -cf Talaria.tar Talaria.pl Mod/*
sftp rtmadmin@rtmserver <<EOF
cd deploy
rm Mod/*
rmdir Mod
rm *
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