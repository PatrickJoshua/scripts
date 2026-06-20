#!/bin/bash
# ~/scripts/mode-check.sh
# Checks current time and applies the correct light/dark mode

HOUR=$(date +%H)

if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
    /home/pa3k/light-mode.sh
else
    /home/pa3k/dark-mode.sh
fi
