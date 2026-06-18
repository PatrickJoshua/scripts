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

BATT_SYSFS="/sys/class/power_supply/BAT1/charge_control_end_threshold"
CONF_FILE="/etc/battery_charge_thresh.conf"

if [[ ! -f "$BATT_SYSFS" ]]; then
    echo "Error: Battery charge threshold interface not found on this kernel/hardware."
    pause_and_exit 1
fi

CURRENT_VAL=$(cat "$BATT_SYSFS")
VALUE=$1

# If no argument is provided, prompt the user
if [[ -z "$VALUE" ]]; then
    echo "Current Battery Charge Cap: $CURRENT_VAL%"
    read -p "Enter new max charge threshold (10-100): " VALUE
fi

# Validate that the input is an integer between 10 and 100
if ! [[ "$VALUE" =~ ^[0-9]+$ ]] || (( VALUE < 10 || VALUE > 100 )); then
    echo "Error: Invalid input. Please provide an integer between 10 and 100."
    pause_and_exit 1
fi

# Apply to kernel immediately
echo "$VALUE" > "$BATT_SYSFS"

# Save for persistence
echo "$VALUE" > "$CONF_FILE"

echo "Successfully updated battery threshold to $VALUE%."

# pause_and_exit 0
