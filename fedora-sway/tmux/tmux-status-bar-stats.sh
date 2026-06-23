#!/bin/bash

# --- Battery & Power ---
BATT_LEVEL=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null)
BATT_STATUS=$(cat /sys/class/power_supply/BAT1/status)
if [[ "$BATT_STATUS" == "Not charging" ]]; then
	BATT_STATUS=""
elif [[ "$BATT_STATUS" == "Charging" ]]; then
	BATT_STATUS=""
else
	BATT_STATUS=""
fi

# Calculate power draw (Watts = (I * V) / 10^12) using current_now and voltage_now
POWER_DRAW=$(awk '{if (NR==1) i=$1; else v=$1} END {printf("%.1fW", (i*v)/1000000000000)}' /sys/class/power_supply/BAT1/current_now /sys/class/power_supply/BAT1/voltage_now 2>/dev/null)

POWER_LIMITS=$(~/scripts/fedora-sway/config/waybar/scripts/power_status.sh | jq -r '.text' 2>/dev/null)

# --- Hardware Utilization ---
RAM=$(free -m | awk '/Mem:/ { printf("%.1f%% (%.1fGB)", $3/$2 * 100.0, $3/1024.0) }')
CPU_UTIL=$(top -bn1 | grep "Cpu(s)" | awk '{printf("%.1f%%", $2 + $4)}')
CPU_TEMP=$(awk '{printf("%.1f°C", $1/1000)}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null)

# --- Media & Network ---
VOL=$(amixer get Master | awk -F'[][]' '/Left:/ { print $2 }')
BACKLIGHT=$(brightnessctl -P g)
# Backlight alt icon: 

# Find the wireless interface dynamically (e.g., wlp2s0) and grab stats instantly via 'iw'
WIFI_IFACE=$(ls /sys/class/net | grep -m 1 -E '^wl')
if [ -n "$WIFI_IFACE" ]; then
    # Convert dBm to an approximate percentage and grab SSID in one pass
    NETWORK=$(iw dev "$WIFI_IFACE" link 2>/dev/null | awk -F': ' '
        /SSID/ {ssid=$2}
        /signal/ {
            sub(/ dBm/, "", $2);
            sig=2*($2+100);
            if(sig>100) sig=100;
            if(sig<0) sig=0;
        }
        END {if (ssid) printf "%s (%d%%)", ssid, sig; else print "Disconnected"}
    ')
else
    NETWORK="No Wi-Fi Interface"
fi

# --- Final Output ---
echo " $RAM |  $CPU_UTIL  $CPU_TEMP |  $BATT_LEVEL% $BATT_STATUS $POWER_DRAW | $POWER_LIMITS|   $NETWORK |  $VOL | 💡$BACKLIGHT%"
