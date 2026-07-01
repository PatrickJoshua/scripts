#!/bin/bash

# Function to pause and exit
pause_and_exit() {
    local exit_code=$1
    echo ""
    read -n 1 -s -r -p "Press any key to dismiss..."
    echo ""
    exit "$exit_code"
}

# Ensure the script is run with sudo/root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script requires administrative privileges. Requesting sudo..."
   exec sudo "$0" "$@"
fi

PSTATE_FILE="/sys/devices/system/cpu/intel_pstate/max_perf_pct"

if [[ ! -f "$PSTATE_FILE" ]]; then
    echo "Error: intel_pstate driver not found."
    pause_and_exit 1
fi

CURRENT_VAL=$(cat "$PSTATE_FILE")
VALUE=$1

# If no argument is provided, prompt the user
if [[ -z "$VALUE" ]]; then
    if [[ -f "/etc/cpu_cap.conf" ]]; then
        CURRENT_VAL=$(cat "/etc/cpu_cap.conf")
    fi
    echo "Current persistent Battery CPU cap: $CURRENT_VAL%"
    read -p "Enter new persistent Battery CPU cap (1-100): " VALUE
fi

# Validate that the input is an integer between 1 and 100
if ! [[ "$VALUE" =~ ^[0-9]+$ ]] || (( VALUE < 1 || VALUE > 100 )); then
    echo "Error: Invalid input. Please provide an integer between 1 and 100."
    pause_and_exit 1
fi

# Save the desired battery limit persistently
SAVED_CAP_FILE="/etc/cpu_cap.conf"
echo "$VALUE" > "$SAVED_CAP_FILE"
echo "Persistent battery CPU cap saved as $VALUE% to $SAVED_CAP_FILE."

# Clean up old tmpfiles.d persistent config if it exists
if [[ -f "/etc/tmpfiles.d/cpu-cap.conf" ]]; then
    rm -f "/etc/tmpfiles.d/cpu-cap.conf"
fi

# Detect current power source and apply the appropriate limit and TuneD profile
if grep -q "1" /sys/class/power_supply/*/online 2>/dev/null; then
    # Currently on AC Mode -> always 100% and throughput-performance
    echo "100" > "$PSTATE_FILE"
    tuned-adm profile throughput-performance 2>/dev/null || tuned-adm profile balanced
    echo "System is currently on AC power. Applied 100% (uncapped) CPU limit and 'throughput-performance' TuneD profile."
else
    # Currently on Battery Mode -> apply user's desired cap and switch to non-blocking profile (balanced or powersave)
    echo "$VALUE" > "$PSTATE_FILE"
    if (( VALUE >= 40 )); then
        tuned-adm profile balanced
    else
        tuned-adm profile powersave
    fi
    echo "System is currently on Battery. Applied $VALUE% CPU cap and synchronized TuneD profile."
fi

echo "Active TuneD power profile synced to: $(tuned-adm active | awk '{print $NF}')"
