#!/bin/bash

batt_cap=$(grep -i "^STOP_CHARGE_THRESH_BAT1=" /etc/tlp.conf)
batt_cap="${batt_cap#*=}"

# Read the physical AC adapter state directly from the kernel
# '1' means plugged in, '0' means unplugged
if grep -q "1" /sys/class/power_supply/*/online 2>/dev/null; then
    # Plugged in (AC Mode)
    echo "{\"text\": \"⚡Turbo🔋${batt_cap}%🛡️\", \"tooltip\": \"TLP: AC Mode\nCPU uncapped\nBattery Charge Cap: ${batt_cap}\", \"class\": \"ac\"}"
else
    # Unplugged (BAT Mode)
    #cpu_cap='20'
    tlp_cap=$(grep -i "^CPU_MAX_PERF_ON_BAT=" /etc/tlp.conf)
    cpu_cap="${tlp_cap#*=}"
    echo "{\"text\": \"${cpu_cap}%🔋${batt_cap}%🛡️\", \"tooltip\": \"TLP: BAT Mode\nCPU capped at ${cpu_cap}%\nBattery Charge Cap: ${batt_cap}\", \"class\": \"bat\"}"
fi
