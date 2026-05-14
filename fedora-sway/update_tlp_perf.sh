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

CONFIG_FILE="/etc/tlp.conf"

# Check if the file exists early so we can read the current value
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found."
    pause_and_exit 1
fi

# Get current value
CURRENT_VAL=$(grep "^#\?CPU_MAX_PERF_ON_BAT=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ' | tail -n 1)
if [[ -z "$CURRENT_VAL" ]]; then
    CURRENT_VAL="Not set"
fi

VALUE=$1

# If no argument is provided, prompt the user
if [[ -z "$VALUE" ]]; then
    echo "Current CPU_MAX_PERF_ON_BAT: $CURRENT_VAL"
    read -p "Enter new CPU max performance value on battery (1-100): " VALUE
fi

# Validate that the input is an integer between 1 and 100
if ! [[ "$VALUE" =~ ^[0-9]+$ ]] || (( VALUE < 1 || VALUE > 100 )); then
    echo "Error: Invalid input. Please provide an integer between 1 and 100."
    pause_and_exit 1
fi

# Use sed to update the value. It handles both commented and uncommented lines.
if grep -q "^#\?CPU_MAX_PERF_ON_BAT=" "$CONFIG_FILE"; then
    sed -i "s/^#\?CPU_MAX_PERF_ON_BAT=.*/CPU_MAX_PERF_ON_BAT=$VALUE/" "$CONFIG_FILE"
    echo "Successfully updated CPU_MAX_PERF_ON_BAT to $VALUE in $CONFIG_FILE"
else
    echo "CPU_MAX_PERF_ON_BAT=$VALUE" >> "$CONFIG_FILE"
    echo "Added CPU_MAX_PERF_ON_BAT=$VALUE to $CONFIG_FILE"
fi

# Apply the new thresholds to the hardware immediately
echo "Applying new threshold via TLP..."
tlp start

#pause_and_exit 0
