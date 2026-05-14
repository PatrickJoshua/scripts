#!/bin/bash

ssh -ND8080 -c chacha20-poly1305@openssh.com -o ServerAliveInterval=30 a10017780@192.168.1.215 &
# autossh -M 0 -N -D 8080 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 300" a10017780@192.168.1.215 &
