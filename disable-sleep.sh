#!/bin/bash

# Configuration
CRITICAL_BATT=5      # Battery % to trigger emergency sleep
CHECK_INTERVAL=180   # Seconds between battery checks
SCRIPT_INITIALIZED=0 # Tracks if main setup was completed
VNC_WAS_ENABLED=0
NOTIFY_PORT=10000

# Function to send notification to the SSH client
send_notification() {
    local msg="$1"
    # Try to send to the reverse tunneled port on localhost
    # Use a 1-second timeout to avoid hanging if the tunnel is down
    echo "$msg" | nc -w 1 localhost $NOTIFY_PORT >/dev/null 2>&1 || true
}

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script requires root privileges (sudo)."
  exit 1
fi

# Prompt for VNC
read -p "Enable VNC? [y/N]: " vnc_input < /dev/tty
vnc_input=${vnc_input:-n}

# Prompt for Sleep
read -p "Disable sleep? [y/N]: " sleep_input < /dev/tty
sleep_input=${sleep_input:-n}

# Function to restore original settings on exit
cleanup() {
    # Remove traps to prevent recursion
    trap - EXIT INT TERM HUP QUIT

    echo -e "\n[i] Interruption caught. Restoring system power settings..."
    if [ $SCRIPT_INITIALIZED -eq 1 ]; then
        if [[ "$sleep_input" =~ ^[Yy]$ ]]; then
            # Restore system sleep (0 = allow, 1 = disable)
            pmset -a disablesleep 0
            echo "[✓] System sleep restored to normal."
        fi

        # Restore display sleep to a standard 10 minutes
        pmset -a displaysleep 10
        pmset -b displaysleep 2
        echo "[✓] Display sleep settings restored to normal."

        # Disable VNC if it was enabled by this script
        if [ $VNC_WAS_ENABLED -eq 1 ]; then
            /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off
            echo "[✓] VNC disabled."
        fi
    fi
    echo "(Graceful script exit)"
}

# Trap signals for clean exit
# We trap EXIT to ensure cleanup runs on any exit.
# We trap specific signals to trigger an exit (which then triggers the EXIT trap).
trap cleanup EXIT
trap "exit 1" INT TERM HUP QUIT

# --- ENABLE SERVER MODE ---
echo "[i] Initiating Headless Server Mode..."

# Disable System Sleep conditionally
if [[ "$sleep_input" =~ ^[Yy]$ ]]; then
    # Disable System Sleep (Prevents lid-close sleep)
    pmset -a disablesleep 1
    echo "[✓] System sleep disabled."
else
    echo "[i] System sleep remains enabled."
fi

# Disable Display Sleep (Idle timer)
#pmset -a displaysleep 0
pmset -a displaysleep 1
echo "[✓] Display idle sleep set to 1 minute."

# Enable VNC conditionally
if [[ "$vnc_input" =~ ^[Yy]$ ]]; then
    /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -clientopts -setvnclegacy -vnclegacy yes -restart -agent -privs -all
    VNC_WAS_ENABLED=1
    echo "[✓] VNC enabled."
else
    echo "[i] VNC remains disabled."
fi

# Sleep display now
pmset displaysleepnow
echo "[✓] Screen turned off."

#./check-brightness.sh

SCRIPT_INITIALIZED=1

# Print hardware stats
~/Desktop/scripts/report-hw-status.sh

echo "[i] Monitoring energy... (Ctrl+C to stop)"
echo "--------------------------------------------------------------------------------"

PREV_BATT_PCT=""
PREV_POWER_SOURCE=""

while true; do
    # 1. Gather Basic Info
    POWER_SOURCE=$(pmset -g batt | head -n 1 | cut -d\' -f2)
    BATT_PCT=$(pmset -g batt | grep -Eo '[0-9]+%' | head -n 1 | tr -d '%')
    
    # 2. Only print if the Power Source or Battery % has changed
    if [ "$POWER_SOURCE" != "$PREV_POWER_SOURCE" ] || [ "$BATT_PCT" != "$PREV_BATT_PCT" ]; then
        
        # Calculate Battery Draw (Watts) via ioreg
        BATT_DRAW=$(ioreg -rw0 -c AppleSmartBattery | awk '/"Voltage" =/ {v=$3} /"Amperage" =/ {a=$3} END { if(a>2^63) a-=2^64; w=(v*a/1000000); printf "%.2fW\n", w}')
        
        # Calculate Total System Power Consumption via powermetrics (100ms sample)
        SYS_POWER=$(powermetrics -n 1 -i 100 --samplers smc,cpu_power 2>/dev/null | grep -iE "Combined Power|System Total power" | head -n 1 | awk '{ if ($0 ~ /mW/) { printf "%.2fW", $(NF-1)/1000 } else { print $(NF-1) "W" } }')
        
        TIME=$(date "+%Y-%m-%d %H:%M:%S")
        MSG="Batt: ${BATT_PCT:-N/A}% | Source: $POWER_SOURCE | Draw: $BATT_DRAW"
        echo "[$TIME] Update -> $MSG | Sys Power: ${SYS_POWER:-Unknown}"
        
        # Send notification to the SSH client
        if [ $SCRIPT_INITIALIZED -eq 1 ]; then
            send_notification "$MSG"
        fi
        
        PREV_POWER_SOURCE="$POWER_SOURCE"
        PREV_BATT_PCT="$BATT_PCT"
    fi

    # 3. Handle Critical Battery Case
    if [ "$POWER_SOURCE" = "Battery Power" ] && [ "$BATT_PCT" -le "$CRITICAL_BATT" ]; then
        MSG="CRITICAL BATTERY (${BATT_PCT}%). Re-enabling sleep to prevent shutdown."
        echo -e "\n[!] $MSG"
        send_notification "$MSG"
        exit 0 
    fi
    
    # 4. Sleep and Wait (or manual trigger)
    if read -s -t "$CHECK_INTERVAL" -n 1 < /dev/tty; then
        echo -e "\n[i] Manual trigger: Reporting hardware status..."
        ~/Desktop/scripts/report-hw-status.sh
    fi
done
