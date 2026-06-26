#!/bin/bash

# Check if swayidle is running and stop it to prevent sleep/lock during VNC
if pgrep -xu "$USER" swayidle >/dev/null; then
    WAS_SWAYIDLE_RUNNING=1
    pkill -xu "$USER" swayidle
else
    WAS_SWAYIDLE_RUNNING=0
fi

cleanup() {
    # Remove traps to prevent recursion/double invocation
    trap - EXIT INT TERM HUP QUIT

    # Restore swayidle if it was running before
    if [ "$WAS_SWAYIDLE_RUNNING" -eq 1 ]; then
        SWAYIDLE_CONFIG="$HOME/.config/sway/config.d/90-swayidle.conf"
        if [ -f "$SWAYIDLE_CONFIG" ]; then
            CMD=$(sed -n '/exec swayidle/,$p' "$SWAYIDLE_CONFIG" | sed 's/exec //')
            CMD_SINGLE_LINE=$(echo "$CMD" | tr '\n' ' ' | tr -d '\\')
            if [ -n "$CMD_SINGLE_LINE" ]; then
                swaymsg exec "$CMD_SINGLE_LINE" >/dev/null 2>&1
            else
                swaymsg exec "swayidle -w" >/dev/null 2>&1
            fi
        else
            swaymsg exec "swayidle -w" >/dev/null 2>&1
        fi
    fi
}

# Trap exits and standard signals to ensure cleanup is run
trap cleanup EXIT INT TERM HUP QUIT

# Start wayvnc with lid-close and system sleep/suspend inhibited
systemd-inhibit --what=handle-lid-switch:sleep --why="VNC Session Active" --who="start-vnc-tailscale.sh" --mode=block wayvnc $(tailscale ip -4) 5900
