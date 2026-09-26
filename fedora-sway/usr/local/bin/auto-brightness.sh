#!/bin/bash

# Give the system a brief moment to register the hardware state change
sleep 1

PSTATE_FILE="/sys/devices/system/cpu/intel_pstate/max_perf_pct"
SAVED_CAP_FILE="/etc/cpu_cap.conf"
TMUX_USER="pa3k"

# Default fallback cap if file doesn't exist
BAT_CAP=100
if [[ -f "$SAVED_CAP_FILE" ]]; then
    BAT_CAP=$(cat "$SAVED_CAP_FILE")
fi

# --- Tmux Helper Function ---
update_tmux() {
    local INTERVAL=$1
    local LABEL=$2
    
    # Only attempt to update if pa3k has an active tmux session
    if sudo -u "$TMUX_USER" tmux has-session 2>/dev/null; then
        sudo -u "$TMUX_USER" tmux set -g status-interval "$INTERVAL"
        sudo -u "$TMUX_USER" tmux set -g status-right " $LABEL #{?#{==:#{client_termname},linux},#(~/scripts/fedora-sway/tmux/tmux-status-bar-stats.sh tty),#(~/scripts/fedora-sway/tmux/tmux-status-bar-stats.sh)} %m/%d %H:%M"
        #sudo -u "$TMUX_USER" tmux refresh-client -S
    fi
}

if [ "$1" == "bat" ]; then
    # Unplugged: dim the screen
    /usr/bin/brightnessctl set 1
    
    # Switch TuneD profile to battery-friendly one first (balanced or powersave)
    # This prevents throughput-performance from blocking max_perf_pct writes
    if [[ -f "$PSTATE_FILE" ]]; then
        if (( BAT_CAP >= 40 )); then
            tuned-adm profile balanced
        else
            tuned-adm profile powersave
        fi
        # Apply battery CPU limit
        echo "$BAT_CAP" > "$PSTATE_FILE"
    fi

    # Set MSI EC fan profile to silent / super_battery for quiet / 0-RPM operation
    if [[ -d "/sys/devices/platform/msi-ec" ]]; then
        echo "super_battery" > /sys/devices/platform/msi-ec/preset 2>/dev/null || true
        echo "silent" > /sys/devices/platform/msi-ec/fan_mode 2>/dev/null || true
    fi
    
    # Update tmux to ultra battery-saving mode (5 minutes)
    update_tmux 300 "5m"

elif [ "$1" == "ac" ]; then
    # Plugged in: brighten the screen
    /usr/bin/brightnessctl set 30%
    
    # Remove CPU limit (always 100 on AC)
    if [[ -f "$PSTATE_FILE" ]]; then
        echo "100" > "$PSTATE_FILE"
    fi
    # Switch TuneD profile to high performance on AC
    tuned-adm profile throughput-performance 2>/dev/null || tuned-adm profile balanced

    # Restore MSI EC fan profile to balanced / auto
    if [[ -d "/sys/devices/platform/msi-ec" ]]; then
        echo "balanced" > /sys/devices/platform/msi-ec/preset 2>/dev/null || true
        echo "auto" > /sys/devices/platform/msi-ec/fan_mode 2>/dev/null || true
    fi
    
    # Update tmux to performance mode (2 seconds)
    update_tmux 2 "2s"
fi
