#!/bin/bash

ssh rtmadmin@RTMSERVER <<EOF
./backup.pl repository
logout
EOF
