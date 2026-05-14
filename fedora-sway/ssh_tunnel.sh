#!/bin/bash
autossh -M 0 -N -D 8080 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" a10017780@192.168.1.215
