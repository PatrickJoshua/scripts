#!/bin/bash

# Give the system a brief moment to register the hardware state change
sleep 1

if [ "$1" == "bat" ]; then
    # Unplugged: dim the screen
    /usr/bin/brightnessctl set 1
elif [ "$1" == "ac" ]; then
    # Plugged in: brighten the screen
    /usr/bin/brightnessctl set 30%
fi
