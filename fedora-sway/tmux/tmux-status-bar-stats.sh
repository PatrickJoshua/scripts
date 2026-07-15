#!/bin/bash

# --- Input Arguments ---
# $1 = "tty" or "default" (from tmux client_termname)
# $2 = Width of the client window (from tmux client_width)
IS_TTY=$([ "$1" = "tty" ] || [ "$TERM" = "linux" ] && echo 1 || echo 0)
WIDTH=${2:-999} # Fallback to 999 if no width provided

# --- Icons Setup ---
if [ "$IS_TTY" -eq 1 ]; then
    IC_MENU="" IC_CPU="" IC_TEMP="" IC_WIFI="" IC_VOL="" IC_LGT=""
else
    IC_MENU="" IC_CPU="" IC_TEMP="" IC_WIFI="" IC_VOL="" IC_LGT="💡"
fi

# --- Setup Cache Variables ---
CACHE_FILE="/tmp/tmux_slow_metrics.cache"
CPU_CACHE_FILE="/tmp/tmux_cpu_metrics.cache"
CACHE_TIMEOUT=90
CURRENT_TIME=$(date +%s)

# --- SLOW METRICS (Cached) ---
if [ -f "$CACHE_FILE" ]; then
    FILE_TIME=$(stat -c %Y "$CACHE_FILE")
    AGE=$((CURRENT_TIME - FILE_TIME))
else
    AGE=999 
fi

if [ "$AGE" -ge "$CACHE_TIMEOUT" ]; then
    POWER_LIMITS=$(~/scripts/fedora-sway/config/waybar/scripts/power_status.sh --tmux 2>/dev/null)
    
    WIFI_IFACE=$(ls /sys/class/net | grep -m 1 -E '^wl')
    if [ -n "$WIFI_IFACE" ]; then
        # Keeping awk here as iw output parsing is complex for pure bash
        NETWORK=$(iw dev "$WIFI_IFACE" link 2>/dev/null | awk -F': ' '
            /SSID/ {
                ssid=$2;
                sub(/^_owetm_/, "", ssid);
                sub(/[0-9]+$/, "", ssid);
            }
            /signal/ {
                sub(/ dBm/, "", $2); sig=2*($2+100);
                if(sig>100) sig=100; if(sig<0) sig=0;
            }
            END {if (ssid) printf "%s (%d%%)", ssid, sig; else print "Disconnected"}
        ')
    else
        NETWORK="No Wi-Fi Interface"
    fi
    echo "${POWER_LIMITS}|${NETWORK}" > "$CACHE_FILE"
else
    IFS='|' read -r POWER_LIMITS NETWORK < "$CACHE_FILE"
fi

# --- FAST METRICS (Zero/Low Fork) ---

# Battery Status (Zero Fork)
read -r BATT_LEVEL < /sys/class/power_supply/BAT1/capacity 2>/dev/null
read -r BATT_STATUS < /sys/class/power_supply/BAT1/status 2>/dev/null

if [ "$IS_TTY" -eq 1 ]; then
    IC_BATT=""
elif [[ "$BATT_STATUS" == "Not charging" ]]; then
    IC_BATT=""
elif [[ "$BATT_STATUS" == "Charging" ]]; then
    IC_BATT=""
else
    IC_BATT=""
fi

# Battery Draw (1 Fork - integer math via bash to save awk)
read -r BATT_VOLT < /sys/class/power_supply/BAT1/voltage_now 2>/dev/null
read -r BATT_CURR < /sys/class/power_supply/BAT1/current_now 2>/dev/null
if [ -n "$BATT_VOLT" ] && [ -n "$BATT_CURR" ]; then
    # Bash does integer math natively. Result in Watts.
    POWER_DRAW="$(( (BATT_VOLT / 1000) * (BATT_CURR / 1000) / 1000000 ))W"
else
    POWER_DRAW="0W"
fi

# Hardware: RAM (Zero Fork - Bash native parsing)
while read -r key value _; do
    case "$key" in
        MemTotal:) MEM_TOTAL=$value ;;
        MemAvailable:) MEM_AVAIL=$value ;;
    esac
done < /proc/meminfo
MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
RAM="$((100 * MEM_USED / MEM_TOTAL))% ($((MEM_USED / 1024 / 1024))GB)"

# Hardware: Temp (Zero Fork)
read -r TEMP_RAW < /sys/class/thermal/thermal_zone0/temp 2>/dev/null
CPU_TEMP="$((TEMP_RAW / 1000))°C"

# Hardware: CPU Utilization (Zero Fork, Cache-based Delta)
read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
CUR_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
CUR_IDLE=$((idle + iowait))

if [ -f "$CPU_CACHE_FILE" ]; then
    read -r PREV_TOTAL PREV_IDLE < "$CPU_CACHE_FILE"
else
    PREV_TOTAL=0 PREV_IDLE=0
fi

echo "$CUR_TOTAL $CUR_IDLE" > "$CPU_CACHE_FILE"

DIFF_TOTAL=$((CUR_TOTAL - PREV_TOTAL))
DIFF_IDLE=$((CUR_IDLE - PREV_IDLE))

if [ "$DIFF_TOTAL" -gt 0 ]; then
    CPU_UTIL="$(( 100 * (DIFF_TOTAL - DIFF_IDLE) / DIFF_TOTAL ))%"
else
    CPU_UTIL="0%"
fi

# Media (Required forks for hardware commands)
VOL=$(amixer get Master | awk -F'[][]' '/Left:/ { sub(/%/, "", $2); print $2 }')
BACKLIGHT=$(brightnessctl -P g 2>/dev/null)

# --- Final Output ---
FULL_OUTPUT="| $IC_MENU $RAM | $IC_CPU $CPU_UTIL $IC_TEMP $CPU_TEMP | $IC_BATT $BATT_LEVEL% $POWER_DRAW | $POWER_LIMITS% | $IC_WIFI $NETWORK | $IC_VOL $VOL% | $IC_LGT$BACKLIGHT% |"

# Strip extra spaces if TTY mode cleared icons
FULL_OUTPUT=$(echo "$FULL_OUTPUT" | tr -s ' ')

if [ "$((WIDTH - 30))" -lt "${#FULL_OUTPUT}" ]; then
    COMPACT_OUTPUT="$POWER_LIMITS $IC_WIFI $NETWORK $IC_VOL $VOL% $IC_LGT $BACKLIGHT% $IC_MENU $RAM $IC_CPU $CPU_UTIL $IC_TEMP $CPU_TEMP $IC_BATT $BATT_LEVEL% $POWER_DRAW"
    FINAL_OUT=$(echo "$COMPACT_OUTPUT" | tr -s ' ')
else
    FINAL_OUT="$FULL_OUTPUT"
fi

# Strip non-ASCII/special characters in raw TTY mode to prevent status bar duplication in tmux
if [ "$IS_TTY" -eq 1 ]; then
    LC_ALL=C
    FINAL_OUT="${FINAL_OUT//[^ -~]/}"
fi

echo "$FINAL_OUT"
