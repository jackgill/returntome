#!/bin/bash

sftp -b /dev/stdin 192.168.1.10 <<EOF
user rtmadmin AIM - 9 Sidewinder
put foo.txt
bye
EOF

