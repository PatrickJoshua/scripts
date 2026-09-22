#!/bin/bash

# xtunnel_macbook.sh
# Purpose: Establishes a secure SSH reverse tunnel to the MacBook and inhibits
# system sleep, lock, and screen power-off on the local Sway compositor while active.
#
# Execution Method:
# - Launches the underlying tunnel script ('tunnel_macbook.sh') in a headless and
#   non-interactive mode using the '-xn' flags (skipping all prompts/user interaction).
#
# Mechanisms:
# - systemd-inhibit: Inhibits logind/systemd sleep and suspend actions.
# - pkill -STOP/-CONT swayidle: Pauses the Sway idle daemon to completely inhibit 
#   Wayland-level screen blanking, locking, and display power management (DPMS) timeouts.

# Get the directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Pause swayidle to prevent any Wayland-level screen off or screen locking timeouts
pkill -STOP swayidle

# Ensure swayidle is resumed when this script exits, is killed, or gets interrupted
cleanup() {
    pkill -CONT swayidle
}
trap cleanup EXIT INT TERM HUP QUIT

# Run the tunnel script wrapped with systemd-inhibit to block logind suspension/sleep
systemd-inhibit --what=idle:sleep --who="Mac Tunnel" --why="SSH active" "$DIR/tunnel_macbook.sh" -xn "$@"
