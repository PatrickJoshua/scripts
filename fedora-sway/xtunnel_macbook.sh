#!/bin/bash

# ssh -ND8080 -c chacha20-poly1305@openssh.com a10017780@192.168.1.215 &
#autossh -M 0 -N -D 8080 -c chacha20-poly1305@openssh.com -o "ServerAliveInterval 30" -o "ServerAliveCountMax 300" a10017780@192.168.1.215
#autossh -M 0 -N -D 8080 -L 5900:localhost:5900 -c chacha20-poly1305@openssh.com -o "ServerAliveInterval 30" -o "ServerAliveCountMax 300" a10017780@192.168.1.215
autossh -M 0 -t -D 8080 -L 5900:localhost:5900 -c chacha20-poly1305@openssh.com -o "ServerAliveInterval 30" -o "ServerAliveCountMax 300" a10017780@192.168.1.215 "sudo ~/Desktop/scripts/disable-sleep.sh ; exit"
