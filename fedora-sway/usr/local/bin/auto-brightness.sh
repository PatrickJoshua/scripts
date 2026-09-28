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

# --- Sway Wallpaper Helper Function ---
update_sway_wallpaper() {
    local MODE=$1 # "bat" or "ac"
    local USER_NAME="pa3k"
    local UID_VAL=1000

    # Locate active Sway socket
    local SOCK
    SOCK=$(ls -t /run/user/${UID_VAL}/sway-ipc.*.sock 2>/dev/null | head -n 1)

    if [[ "$MODE" == "bat" ]]; then
        # Update user session environment
        sudo -u "$USER_NAME" env XDG_RUNTIME_DIR="/run/user/${UID_VAL}" systemctl --user set-environment SWAY_ON_BATTERY=1 2>/dev/null || true
        # Set swaybg to solid black color
        if [[ -n "$SOCK" && -S "$SOCK" ]]; then
            sudo -u "$USER_NAME" env SWAYSOCK="$SOCK" swaymsg "output * bg #000000 solid_color" >/dev/null 2>&1
        fi
    elif [[ "$MODE" == "ac" ]]; then
        # Update user session environment
        sudo -u "$USER_NAME" env XDG_RUNTIME_DIR="/run/user/${UID_VAL}" systemctl --user unset-environment SWAY_ON_BATTERY 2>/dev/null || true
        # Call the Bing wallpaper service (with script fallback)
        if sudo -u "$USER_NAME" env XDG_RUNTIME_DIR="/run/user/${UID_VAL}" systemctl --user is-active --quiet sway-session.service 2>/dev/null; then
            sudo -u "$USER_NAME" env XDG_RUNTIME_DIR="/run/user/${UID_VAL}" systemctl --user start bing-wallpaper.service >/dev/null 2>&1 || \
            ( [[ -n "$SOCK" && -S "$SOCK" ]] && sudo -u "$USER_NAME" env SWAYSOCK="$SOCK" /home/${USER_NAME}/.config/sway/scripts/bing-wallpaper.sh >/dev/null 2>&1 )
        elif [[ -n "$SOCK" && -S "$SOCK" ]]; then
            sudo -u "$USER_NAME" env SWAYSOCK="$SOCK" /home/${USER_NAME}/.config/sway/scripts/bing-wallpaper.sh >/dev/null 2>&1
        fi
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

    # Set wallpaper to solid black on battery
    update_sway_wallpaper "bat"
    
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

    # Restore Bing wallpaper service on AC
    update_sway_wallpaper "ac"
    
    # Update tmux to performance mode (2 seconds)
    update_tmux 2 "2s"
fi
