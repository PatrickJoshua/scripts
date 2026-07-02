#!/bin/bash

# Configuration
BLANK_TIMEOUT_BAT=2     # Screen blanking after 2 minutes on battery
BLANK_TIMEOUT_AC=0      # Screen blanking disabled (0) on AC
SUSPEND_TIMEOUT_BAT=600 # Suspend after 10 minutes of inactivity on battery (600 seconds)
CHECK_INTERVAL=15       # Interval in seconds to check idle states

# Helper to log messages to system journal
log_message() {
    logger -t tty-battery-manager "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_message "TTY Battery Power Manager service started."

while true; do
    # 1. Detect if running on battery
    # Checking ADP1 first, falling back to general search
    if [ -f /sys/class/power_supply/ADP1/online ]; then
        ac_online=$(cat /sys/class/power_supply/ADP1/online)
    else
        # Fallback if ADP1 is not present
        if grep -q "1" /sys/class/power_supply/*/online 2>/dev/null; then
            ac_online=1
        else
            ac_online=0
        fi
    fi

    if [ "$ac_online" = "0" ]; then
        on_battery=true
    else
        on_battery=false
    fi

    # 2. Check if Sway is running
    if pgrep -x "sway" >/dev/null; then
        sway_running=true
    else
        sway_running=false
    fi

    # 3. Handle console blanking configuration (only if Sway is NOT running)
    if [ "$sway_running" = false ]; then
        if [ "$on_battery" = true ]; then
            # On battery: Ensure blanking is set to 2 minutes
            current_blank=$(cat /sys/module/kernel/parameters/consoleblank 2>/dev/null)
            expected_blank=$((BLANK_TIMEOUT_BAT * 60))
            if [ "$current_blank" != "$expected_blank" ]; then
                log_message "On battery (raw TTY). Setting console blanking to ${BLANK_TIMEOUT_BAT} minutes."
                # \e[9;X] sets screen blank timeout in minutes. \e[14;X] sets DPMS powerdown in minutes.
                echo -ne "\e[9;${BLANK_TIMEOUT_BAT}]\e[14;${BLANK_TIMEOUT_BAT}]" > /dev/tty0 2>/dev/null
            fi
        else
            # On AC: Ensure blanking is disabled or set to AC default
            current_blank=$(cat /sys/module/kernel/parameters/consoleblank 2>/dev/null)
            expected_blank=$((BLANK_TIMEOUT_AC * 60))
            if [ "$current_blank" != "$expected_blank" ]; then
                log_message "On AC power. Disabling console blanking."
                echo -ne "\e[9;${BLANK_TIMEOUT_AC}]\e[14;${BLANK_TIMEOUT_AC}]" > /dev/tty0 2>/dev/null
            fi
        fi
    fi

    # 4. Handle suspension on battery if Sway is NOT running
    if [ "$on_battery" = true ] && [ "$sway_running" = false ]; then
        active_tty=$(cat /sys/class/tty/tty0/active 2>/dev/null)
        
        # Check if the active tty is a virtual console (tty1-tty6)
        if [[ "$active_tty" =~ ^tty[0-9]+$ ]]; then
            tty_device="/dev/${active_tty}"
            if [ -c "$tty_device" ]; then
                last_access=$(stat -c %X "$tty_device" 2>/dev/null)
                current_time=$(date +%s)
                idle_seconds=$((current_time - last_access))

                if [ "$idle_seconds" -ge "$SUSPEND_TIMEOUT_BAT" ]; then
                    # Double check conditions right before suspending
                    if [ -f /sys/class/power_supply/ADP1/online ]; then
                        ac_still_online=$(cat /sys/class/power_supply/ADP1/online)
                    else
                        ac_still_online=$(grep -q "1" /sys/class/power_supply/*/online 2>/dev/null && echo 1 || echo 0)
                    fi

                    if [ "$ac_still_online" = "0" ] && ! pgrep -x "sway" >/dev/null; then
                        log_message "System idle for ${idle_seconds}s on raw TTY (${active_tty}) and battery. Suspending now..."
                        systemctl suspend
                        # Sleep a bit extra after resuming to let hardware re-initialize
                        sleep 10
                    fi
                fi
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
