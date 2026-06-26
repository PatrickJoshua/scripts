#!/bin/bash

# --- Setup Cache Variables ---
CACHE_FILE="/tmp/tmux_slow_metrics.cache"
CACHE_TIMEOUT=90 # Update slow metrics every 90 seconds
CURRENT_TIME=$(date +%s)

# Check if cache file exists and get its age, otherwise force an update
if [ -f "$CACHE_FILE" ]; then
    FILE_TIME=$(stat -c %Y "$CACHE_FILE")
    AGE=$((CURRENT_TIME - FILE_TIME))
else
    AGE=999 
fi

# --- SLOW METRICS (Cached) ---
if [ "$AGE" -ge "$CACHE_TIMEOUT" ]; then
    # 1. Fetch Power Limits
    POWER_LIMITS=$(~/scripts/fedora-sway/config/waybar/scripts/power_status.sh | jq -r '.text' 2>/dev/null)
    
    # 2. Fetch Network
    WIFI_IFACE=$(ls /sys/class/net | grep -m 1 -E '^wl')
    if [ -n "$WIFI_IFACE" ]; then
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

    # Save to cache separated by a pipe (|)
    echo "${POWER_LIMITS}|${NETWORK}" > "$CACHE_FILE"
else
    # Read variables instantly from the cache file
    IFS='|' read -r POWER_LIMITS NETWORK < "$CACHE_FILE"
fi

# --- FAST METRICS (Live) ---

# Battery Status & Icons
BATT_LEVEL=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null)
BATT_STATUS=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null)

if [[ "$BATT_STATUS" == "Not charging" ]]; then
	BATT_STATUS=""
elif [[ "$BATT_STATUS" == "Charging" ]]; then
	BATT_STATUS=""
else
	BATT_STATUS=""
fi

# Battery Draw
POWER_DRAW=$(awk '{if (NR==1) i=$1; else v=$1} END {printf("%.1fW", (i*v)/1000000000000)}' /sys/class/power_supply/BAT1/current_now /sys/class/power_supply/BAT1/voltage_now 2>/dev/null)

# Hardware 
RAM=$(free -m | awk '/Mem:/ { printf("%.1f%% (%.1fGB)", $3/$2 * 100.0, $3/1024.0) }')
#CPU_UTIL=$(top -bn1 | grep "Cpu(s)" | awk '{printf("%.1f%%", $2 + $4)}')
CPU_TEMP=$(awk '{printf("%.1f°C", $1/1000)}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null)

# Media
VOL=$(amixer get Master | awk -F'[][]' '/Left:/ { print $2 }')
BACKLIGHT=$(brightnessctl -P g 2>/dev/null)


#CPU Util efficient method
# 1. Grab the first snapshot of CPU counters
read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
TOTAL1=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE1=$((idle + iowait))

# 2. Wait a tiny fraction of a second to establish a delta
sleep 0.2

# 3. Grab the second snapshot
read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
TOTAL2=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE2=$((idle + iowait))

# 4. Calculate the utilization percentage using awk for floating-point math
CPU_UTIL=$(awk -v t1="$TOTAL1" -v t2="$TOTAL2" -v i1="$IDLE1" -v i2="$IDLE2" '
  BEGIN {
    total = t2 - t1;
    idle = i2 - i1;
    if (total > 0) printf("%.1f%%", 100 * (total - idle) / total);
    else print "0.0%";
  }
')

# --- Final Output ---
FULL_OUTPUT="|  $RAM |  $CPU_UTIL  $CPU_TEMP | $BATT_STATUS $BATT_LEVEL% $POWER_DRAW | $POWER_LIMITS|  $NETWORK |  $VOL | 💡$BACKLIGHT% |"

WIDTH="$1"
if [ -n "$WIDTH" ] && [ "$((WIDTH - 30))" -lt "${#FULL_OUTPUT}" ]; then
    COMPACT_OUTPUT="$POWER_LIMITS $NETWORK  $VOL 💡$BACKLIGHT%  $RAM  $CPU_UTIL  $CPU_TEMP $BATT_STATUS $BATT_LEVEL% $POWER_DRAW"
    echo "$COMPACT_OUTPUT"
else
    echo "$FULL_OUTPUT"
fi
