#!/bin/bash

# Configuration
CRITICAL_BATT=5      # Battery % to trigger emergency sleep
CHECK_INTERVAL=180   # Seconds between battery checks
SCRIPT_INITIALIZED=0 # Tracks if main setup was completed
VNC_WAS_ENABLED=0
NOTIFY_PORT=10000
MAIN_PID=$$

# Safe logging helper that writes to file and attempts to write to stdout,
# ignoring I/O errors and ONLY attempting terminal output if a TTY is present.
log_status() {
    local TIME=$(date "+%Y-%m-%d %H:%M:%S")
    # Only add the timestamp to the file log, keep terminal output clean
    echo -e "[$TIME] $1" >> /tmp/disable-sleep.log
    if [ -t 1 ]; then
        echo -e "$1" 2>/dev/null || true
    fi
}

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

# Parse arguments
SKIP_PROMPTS=0
NON_INTERACTIVE=0
while getopts "xn" opt; do
  case $opt in
    x)
      SKIP_PROMPTS=1
      ;;
    n)
      NON_INTERACTIVE=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [ $NON_INTERACTIVE -eq 1 ] && [ $SKIP_PROMPTS -eq 0 ]; then
  echo "Error: The -n (non-interactive) flag requires the -x (skip prompts) flag." >&2
  exit 1
fi

if [ $SKIP_PROMPTS -eq 1 ]; then
    vnc_input="n"
    sleep_input="n"
    echo "[i] Skipping prompts (-x), using defaults (VNC: n, Sleep: n)"
else
    # Prompt for VNC
    read -p "Enable VNC? [y/N]: " vnc_input < /dev/tty
    vnc_input=${vnc_input:-n}

    # Prompt for Sleep
    read -p "Disable sleep? [y/N]: " sleep_input < /dev/tty
    sleep_input=${sleep_input:-n}
fi

INTERRUPTED=0

# Function to restore original settings on exit
cleanup() {
    # Remove traps to prevent recursion
    trap - EXIT INT TERM HUP QUIT

    local IS_WATCHDOG=0
    if [ "$BASHPID" != "$MAIN_PID" ]; then
        IS_WATCHDOG=1
    fi

    # If I am the main script, kill the watchdog so it doesn't also run cleanup
    if [ $IS_WATCHDOG -eq 0 ] && [ -n "$WATCHDOG_PID" ]; then
        kill $WATCHDOG_PID 2>/dev/null || true
    fi
    
    # Kill the background sleep if it is running so it doesn't linger
    if [ -n "$SLEEP_PID" ]; then
        kill $SLEEP_PID 2>/dev/null || true
    fi
    pkill -P $MAIN_PID sleep 2>/dev/null || true

    log_status "\n[i] Interruption caught. Restoring system power settings..."
    if [ $SCRIPT_INITIALIZED -eq 1 ]; then
        if [[ "$sleep_input" =~ ^[Yy]$ ]]; then
            # Restore system sleep (0 = allow, 1 = disable)
            pmset -a disablesleep 0 >> /tmp/disable-sleep.log 2>&1
            log_status "[✓] System sleep restored to normal."
        fi

        # Restore display sleep to a standard 10 minutes
        pmset -a displaysleep 10 >> /tmp/disable-sleep.log 2>&1
        pmset -b displaysleep 2 >> /tmp/disable-sleep.log 2>&1
        log_status "[✓] Display sleep settings restored to normal."

        # Disable VNC if it was enabled by this script
        if [ $VNC_WAS_ENABLED -eq 1 ]; then
            /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off >> /tmp/disable-sleep.log 2>&1
            log_status "[✓] VNC disabled."
        fi
    fi
    log_status "(Graceful script exit)"
    
    if [ $IS_WATCHDOG -eq 1 ]; then
        # We are the watchdog. Kill the stuck main script.
        kill -9 $MAIN_PID 2>/dev/null || true
        exit 0
    else
        # We are the main script.
        if [ $INTERRUPTED -eq 1 ]; then
            exit 130
        fi
        exit 0
    fi
}

# Trap signals for clean exit
trap 'INTERRUPTED=1; cleanup' INT TERM HUP QUIT
trap cleanup EXIT

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
~/Desktop/scripts/report-hw-status.sh --detailed

echo "[i] Monitoring energy... (Ctrl+C to stop)"
echo "--------------------------------------------------------------------------------"

PREV_BATT_PCT=""
PREV_POWER_SOURCE=""

# Start a watchdog to detect if the SSH connection dropped
if [ $NON_INTERACTIVE -eq 1 ]; then
    (
        while true; do
            # 1. Did the main script die unexpectedly (e.g., kill -9)?
            if ! kill -0 $MAIN_PID 2>/dev/null; then
                log_status "\n[!] Main process died unexpectedly. Watchdog taking over cleanup."
                cleanup
            fi

            # 2. Did the reverse tunnel drop? (SSH disconnected)
            if ! nc -z localhost $NOTIFY_PORT >/dev/null 2>&1; then
                log_status "\n[!] SSH tunnel dropped. Watchdog taking over cleanup."
                cleanup
            fi
            sleep 5
        done
    ) &
    WATCHDOG_PID=$!
fi

while true; do
    # 1. Gather Basic Info
    POWER_SOURCE=$(pmset -g batt | head -n 1 | cut -d\' -f2)
    BATT_PCT=$(pmset -g batt | grep -Eo '[0-9]+%' | head -n 1 | tr -d '%')
    
    # 2. Only print if the Power Source or Battery % has changed
    if [ "$POWER_SOURCE" != "$PREV_POWER_SOURCE" ] || [ "$BATT_PCT" != "$PREV_BATT_PCT" ]; then
        
        # Calculate Battery Draw (Watts) via ioreg
        BATT_DRAW=$(ioreg -rw0 -c AppleSmartBattery | awk '/"Voltage" =/ {v=$3} /"Amperage" =/ {a=$3} END { if(a>2^63) a-=2^64; w=(v*a/1000000); printf "%.2fW\n", w}')
        
        # Calculate Total System Power Consumption via powermetrics (100ms sample)
        SYS_POWER=$(powermetrics -n 1 -i 100 --samplers cpu_power,gpu_power,ane_power 2>/dev/null | grep -iE "Combined Power|System Total power" | head -n 1 | awk '{ if ($0 ~ /mW/) { printf "%.2fW", $(NF-1)/1000 } else { printf "%.2fW", $(NF-1) } }')
        
        TIME=$(date "+%Y-%m-%d %H:%M:%S")
        MSG="Batt: ${BATT_PCT:-N/A}% | Source: $POWER_SOURCE | Draw: $BATT_DRAW | Sys Power: ${SYS_POWER:-Unknown}"
        echo "[$TIME] $MSG"
        
        # Send notification to the SSH client
        # Only send if this isn't the first pass (PREV_POWER_SOURCE will be empty on first pass)
        if [ $SCRIPT_INITIALIZED -eq 1 ] && [ -n "$PREV_POWER_SOURCE" ]; then
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
    if [ $NON_INTERACTIVE -eq 1 ]; then
        sleep "$CHECK_INTERVAL" &
        SLEEP_PID=$!
        wait $SLEEP_PID
        SLEEP_PID=""
    else
        if read -s -t "$CHECK_INTERVAL" -n 1 < /dev/tty; then
            echo -e "\n[i] Manual trigger: Reporting hardware status..."
            ~/Desktop/scripts/report-hw-status.sh --detailed
        fi
    fi
done
