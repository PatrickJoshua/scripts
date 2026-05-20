#!/bin/bash

# Configuration
NOTIFY_PORT=10000
HOST="GLMACM1492118.local"

# Start notification listener in background
(
    while true; do
        # ncat listens for a message, outputs it, then exits, loop restarts it
        msg=$(ncat -l -p $NOTIFY_PORT)
        if [ -n "$msg" ]; then
            notify-send "Mac Status" "$msg"
        fi
    done
) &
LISTENER_PID=$!

# Ensure the listener is killed when this script exits
trap "kill $LISTENER_PID 2>/dev/null; exit" EXIT INT TERM

if ! ping -c 1 -W 2 "$HOST" &> /dev/null; then
    HOST="192.168.1.215"
fi

echo "Connecting to $HOST..."

# Added -R $NOTIFY_PORT:localhost:$NOTIFY_PORT for reverse tunnel
autossh -M 0 -t -D 8080 -L 5900:localhost:5900 -R $NOTIFY_PORT:localhost:$NOTIFY_PORT -c chacha20-poly1305@openssh.com -o "ServerAliveInterval 30" -o "ServerAliveCountMax 300" "a10017780@$HOST" "sudo ~/Desktop/scripts/disable-sleep.sh ; exit"
