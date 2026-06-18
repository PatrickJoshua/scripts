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
    echo "Current CPU max performance: $CURRENT_VAL%"
    read -p "Enter new CPU max performance value (1-100): " VALUE
fi

# Validate that the input is an integer between 1 and 100
if ! [[ "$VALUE" =~ ^[0-9]+$ ]] || (( VALUE < 1 || VALUE > 100 )); then
    echo "Error: Invalid input. Please provide an integer between 1 and 100."
    pause_and_exit 1
fi

# Apply the percentage cap to the kernel
echo "$VALUE" > "$PSTATE_FILE"
echo "Successfully updated CPU maximum performance to $VALUE%."

# Sync with tuned-ppd via powerprofilesctl
if (( VALUE >= 80 )); then
    powerprofilesctl set performance 2>/dev/null || powerprofilesctl set balanced
elif (( VALUE >= 40 )); then
    powerprofilesctl set balanced
else
    powerprofilesctl set power-saver
fi

echo "Active D-Bus power profile synced to: $(powerprofilesctl get)"

# pause_and_exit 0
