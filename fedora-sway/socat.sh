#!/bin/bash

IP=192.168.1.155
#IP=10.32.213.82
#IP=192.168.254.114

socat TCP-LISTEN:8080,bind=127.0.0.1,fork,reuseaddr TCP:${IP}:1088
