#!/bin/bash

# Configuration
NOTIFY_PORT=10000
#HOST="GLMACM1492118.local"
HOST="pa3k.local"
RETRY=1

# Parse arguments
SCRIPT_ARGS=""
NON_INTERACTIVE=0
SKIP_PROMPTS=0
while getopts "xn" opt; do
  case $opt in
    x)
      SCRIPT_ARGS="$SCRIPT_ARGS -x"
      SKIP_PROMPTS=1
      ;;
    n)
      SCRIPT_ARGS="$SCRIPT_ARGS -n"
      NON_INTERACTIVE=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

if [ $NON_INTERACTIVE -eq 1 ] && [ $SKIP_PROMPTS -eq 0 ]; then
  echo "Error: The -n (non-interactive) flag requires the -x (skip prompts) flag." >&2
  exit 1
fi

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
    RETRY=0
    trap - EXIT INT TERM HUP QUIT # Prevent recursion
    kill $LISTENER_PID 2>/dev/null
    pkill -P $LISTENER_PID 2>/dev/null
    pkill -f "ncat -l -p $NOTIFY_PORT" 2>/dev/null
    fuser -k ${NOTIFY_PORT}/tcp 2>/dev/null
    if [ -n "$SSH_PID" ]; then
        kill $SSH_PID 2>/dev/null
    fi

    # Prompt to sleep the Mac server if interactive
    if [ "$NON_INTERACTIVE" -eq 0 ] && [ "$SKIP_PROMPTS" -eq 0 ] && [ -t 0 ]; then
        echo -e "\n"
        read -p "Sleep Mac server ($HOST)? [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Sleeping Mac server..."
            ssh "a10017780@$HOST" "echo '[][]' | sudo -S pmset -a disablesleep 0 && echo '[][]' | sudo -S pmset sleepnow"
        fi
    fi

    exit 0
}
trap cleanup EXIT INT TERM HUP QUIT

if [ -n "$1" ]; then
    HOST="$1"
#elif ! ping -c 1 -W 2 "$HOST" &> /dev/null; then
#    HOST="192.168.1.215"
fi

while [ $RETRY -eq 1 ]; do
    echo "Connecting to $HOST..."

    # Using ssh directly (autossh is redundant since we have a loop and it handles signals poorly)
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
        ssh -tt -D 8080 -L 5900:localhost:5900 -R $NOTIFY_PORT:localhost:$NOTIFY_PORT -c chacha20-poly1305@openssh.com -o "ServerAliveInterval 30" -o "ServerAliveCountMax 300" "a10017780@$HOST" "echo '[][]' | sudo -S ~/Desktop/scripts/disable-sleep.sh $SCRIPT_ARGS ; exit" < /dev/null &
        SSH_PID=$!
        wait $SSH_PID
        EXIT_CODE=$?
        SSH_PID=""
    else
        ssh -tt -D 8080 -L 5900:localhost:5900 -R $NOTIFY_PORT:localhost:$NOTIFY_PORT -c chacha20-poly1305@openssh.com -o "ServerAliveInterval 30" -o "ServerAliveCountMax 300" "a10017780@$HOST" "echo '[][]' | sudo -S ~/Desktop/scripts/disable-sleep.sh $SCRIPT_ARGS ; exit"
        EXIT_CODE=$?
    fi

    # If the process was interrupted (SIGINT is 130, etc.) or retry was disabled by trap
    if [ $EXIT_CODE -gt 128 ] || [ $RETRY -eq 0 ]; then
        break
    fi

    echo "Connection lost or closed. Retrying in 5 seconds..."
    # Allow breaking the loop during the wait
    if read -t 5 -n 1 -p "(Press any key to cancel retry) "; then
        echo ""
        break
    fi
    echo ""
done
