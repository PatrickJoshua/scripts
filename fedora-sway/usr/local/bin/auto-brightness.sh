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

# --- Power Notification Helper Function ---
send_power_notification() {
    local MODE=$1 # "bat" or "ac"
    local USER_NAME="${TMUX_USER:-pa3k}"
    local UID_VAL=1000

    if id -u "$USER_NAME" >/dev/null 2>&1; then
        UID_VAL=$(id -u "$USER_NAME")
    fi

    local BATT_LEVEL="Unknown"
    if [[ -f /sys/class/power_supply/BAT1/capacity ]]; then
        read -r BATT_LEVEL < /sys/class/power_supply/BAT1/capacity 2>/dev/null
    elif compgen -G "/sys/class/power_supply/BAT*/capacity" >/dev/null 2>&1; then
        read -r BATT_LEVEL < /sys/class/power_supply/BAT*/capacity 2>/dev/null
    fi

    local TITLE=""
    local BODY=""
    local ICON=""

    if [[ "$MODE" == "ac" ]]; then
        local CHARGE_CAP="100"
        if [[ -f /sys/class/power_supply/BAT1/charge_control_end_threshold ]]; then
            read -r CHARGE_CAP < /sys/class/power_supply/BAT1/charge_control_end_threshold 2>/dev/null
        elif [[ -f /etc/battery_charge_thresh.conf ]]; then
            read -r CHARGE_CAP < /etc/battery_charge_thresh.conf 2>/dev/null
        fi

        TITLE="Power Connected (AC)"
        BODY="Battery: ${BATT_LEVEL}%\nCharge Cap: ${CHARGE_CAP}%"
        ICON="ac-adapter"

    elif [[ "$MODE" == "bat" ]]; then
        local CPU_CAP=""
        if [[ -f "$PSTATE_FILE" ]]; then
            read -r CPU_CAP < "$PSTATE_FILE" 2>/dev/null
        elif [[ -f "$SAVED_CAP_FILE" ]]; then
            read -r CPU_CAP < "$SAVED_CAP_FILE" 2>/dev/null
        else
            CPU_CAP="$BAT_CAP"
        fi

        # Power draw calculation from tmux-status-bar-stats.sh
        local BATT_VOLT=""
        local BATT_CURR=""
        local POWER_DRAW="0W"
        read -r BATT_VOLT < /sys/class/power_supply/BAT1/voltage_now 2>/dev/null
        read -r BATT_CURR < /sys/class/power_supply/BAT1/current_now 2>/dev/null

        if [[ -n "$BATT_VOLT" && -n "$BATT_CURR" && "$BATT_VOLT" -gt 0 && "$BATT_CURR" -gt 0 ]]; then
            local POWER_UW=$(( (BATT_VOLT / 1000) * (BATT_CURR / 1000) ))
            local POWER_W=$(( POWER_UW / 1000000 ))
            local POWER_DEC=$(( (POWER_UW % 1000000) / 100000 ))
            POWER_DRAW="${POWER_W}.${POWER_DEC}W"
        fi

        TITLE="Power Disconnected (Battery)"
        BODY="Battery: ${BATT_LEVEL}%\nPower Consumption: ${POWER_DRAW}\nCPU Cap: ${CPU_CAP}%"
        ICON="battery"
    fi

    local DBUS_BUS="/run/user/${UID_VAL}/bus"
    if [[ -S "$DBUS_BUS" ]]; then
        if [[ "$EUID" -eq 0 ]]; then
            sudo -u "$USER_NAME" env XDG_RUNTIME_DIR="/run/user/${UID_VAL}" DBUS_SESSION_BUS_ADDRESS="unix:path=${DBUS_BUS}" notify-send -a "Power Manager" -i "$ICON" -h string:x-canonical-private-synchronous:power_event "$TITLE" "$BODY" >/dev/null 2>&1 || true
        else
            env XDG_RUNTIME_DIR="/run/user/${UID_VAL}" DBUS_SESSION_BUS_ADDRESS="unix:path=${DBUS_BUS}" notify-send -a "Power Manager" -i "$ICON" -h string:x-canonical-private-synchronous:power_event "$TITLE" "$BODY" >/dev/null 2>&1 || true
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

    # Notify on power source change
    send_power_notification "bat"

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

    # Notify on power source change
    send_power_notification "ac"
fi
