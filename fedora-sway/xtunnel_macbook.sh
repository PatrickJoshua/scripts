#!/bin/bash

# Configuration
NOTIFY_PORT=10000
HOST="GLMACM1492118.local"

# Parse arguments
SCRIPT_ARGS=""
while getopts "x" opt; do
  case $opt in
    x)
      SCRIPT_ARGS="-x"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Ensure port is free before starting
fuser -k ${NOTIFY_PORT}/tcp 2>/dev/null
pkill -f "ncat -l -p $NOTIFY_PORT" 2>/dev/null

# Start notification listener in background
(
    while true; do
        # ncat listens for a message, outputs it, then exits, loop restarts it
        msg=$(ncat -l -p $NOTIFY_PORT)
        if [ -n "$msg" ]; then
            notify-send -t 300000 "MacBook Air M4 15\" Status" "$msg"
        fi
    done
) &
LISTENER_PID=$!

# Ensure the listener and its child processes are killed when this script exits
cleanup() {
    kill $LISTENER_PID 2>/dev/null
    pkill -P $LISTENER_PID 2>/dev/null
    pkill -f "ncat -l -p $NOTIFY_PORT" 2>/dev/null
    fuser -k ${NOTIFY_PORT}/tcp 2>/dev/null
    exit
}
trap cleanup EXIT INT TERM HUP QUIT

if ! ping -c 1 -W 2 "$HOST" &> /dev/null; then
    HOST="192.168.1.215"
fi

echo "Connecting to $HOST..."

# Added -R $NOTIFY_PORT:localhost:$NOTIFY_PORT for reverse tunnel
autossh -M 0 -t -D 8080 -L 5900:localhost:5900 -R $NOTIFY_PORT:localhost:$NOTIFY_PORT -c chacha20-poly1305@openssh.com -o "ServerAliveInterval 30" -o "ServerAliveCountMax 300" "a10017780@$HOST" "echo '[][]' | sudo -S ~/Desktop/scripts/disable-sleep.sh $SCRIPT_ARGS ; exit"
