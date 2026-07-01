#!/bin/bash

# Define the battery threshold path
BATT_PATH="/sys/class/power_supply/BAT1/charge_control_end_threshold"

# Read battery threshold (Fallback to 100 if the path is temporarily unavailable)
if [[ -f "$BATT_PATH" ]]; then
    batt_cap=$(cat "$BATT_PATH")
else
    batt_cap="100"
fi

# Read the physical AC adapter state directly from the kernel
# '1' means plugged in, '0' means unplugged
if grep -q "1" /sys/class/power_supply/*/online 2>/dev/null; then
    # Plugged in (AC Mode)
    waybar_output="{\"text\": \"⚡Turbo🔋${batt_cap}%🛡️\", \"tooltip\": \"Power: AC Mode\nCPU uncapped\nBattery Charge Cap: ${batt_cap}%\", \"class\": \"ac\"}"
    tmux_output="🛇  ${batt_cap}"
else
    # Unplugged (BAT Mode)
    # Get active percentage from intel_pstate
    cpu_cap=$(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct)
    # Get current tuned profile
    active_profile=$(tuned-adm active | awk '{print $NF}')
    
    waybar_output="{\"text\": \"${cpu_cap}%🔋${batt_cap}%🛡️\", \"tooltip\": \"Power: BAT Mode\nProfile: ${active_profile}\nCPU capped at ${cpu_cap}%\nBattery Charge Cap: ${batt_cap}%\", \"class\": \"bat\"}"
    tmux_output="🛇  ${batt_cap} ${cpu_cap}"
fi

# Switch output based on the optional --tmux flag
if [[ "$1" == "--tmux" ]]; then
    echo "$tmux_output"
else
    echo "$waybar_output"
fi
