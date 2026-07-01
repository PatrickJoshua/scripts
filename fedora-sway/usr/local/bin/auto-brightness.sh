#!/bin/bash

# Give the system a brief moment to register the hardware state change
sleep 1

PSTATE_FILE="/sys/devices/system/cpu/intel_pstate/max_perf_pct"
SAVED_CAP_FILE="/etc/cpu_cap.conf"

# Default fallback cap if file doesn't exist
BAT_CAP=100
if [[ -f "$SAVED_CAP_FILE" ]]; then
    BAT_CAP=$(cat "$SAVED_CAP_FILE")
fi

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
elif [ "$1" == "ac" ]; then
    # Plugged in: brighten the screen
    /usr/bin/brightnessctl set 30%
    
    # Remove CPU limit (always 100 on AC)
    if [[ -f "$PSTATE_FILE" ]]; then
        echo "100" > "$PSTATE_FILE"
    fi
    # Switch TuneD profile to high performance on AC
    tuned-adm profile throughput-performance 2>/dev/null || tuned-adm profile balanced
fi
