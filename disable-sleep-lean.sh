#!/bin/bash

# Configuration
CRITICAL_BATT=20 # The battery percentage at which the Mac should be allowed to sleep
SLEEP_DISABLED=0

# Ensure the script is run with root privileges (required for pmset)
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script requires root privileges to modify power settings."
  echo "Please run using: sudo $0"
  exit 1
fi

# Cleanup function to restore default power settings
cleanup() {
    echo -e "\n[i] Interruption caught or exit condition met."
    if [ $SLEEP_DISABLED -eq 1 ]; then
        echo "[i] Re-enabling system sleep..."
        pmset -a disablesleep 0
        SLEEP_DISABLED=0
        echo "[✓] Sleep successfully re-enabled. System returned to normal."
    fi
    exit 0
}

# Trap signals: 
# INT (Ctrl+C), TERM (kill command), HUP (terminal closed), QUIT, and EXIT
trap cleanup EXIT INT TERM HUP QUIT

# Disable sleep
echo "[i] Disabling system sleep..."
pmset -a disablesleep 1
SLEEP_DISABLED=1
echo "[✓] Sleep disabled. Mac will now act as a headless server."
echo "[i] Monitoring battery... Press Ctrl+C at any time to exit and revert settings."

# Infinite loop to monitor battery status
while true; do
    # Check if the Mac is currently drawing from battery power
    if pmset -g batt | grep -q "Battery Power"; then
        
        # Extract the current battery percentage
        BATT_PCT=$(pmset -g batt | grep -Eo '[0-9]+%' | head -n 1 | tr -d '%')
        
        # Safely check if the percentage is an integer and below the threshold
        if [ -n "$BATT_PCT" ] && [ "$BATT_PCT" -eq "$BATT_PCT" ] 2>/dev/null; then
            if [ "$BATT_PCT" -le "$CRITICAL_BATT" ]; then
                echo -e "\n[!] CRITICAL WARNING: Battery is at ${BATT_PCT}%."
                echo "[!] Re-enabling sleep to prevent hard power loss and data corruption."
                # Calling exit triggers the EXIT trap, which runs the cleanup function safely
                exit 0 
            fi
        fi
    fi
    
    # Wait for 60 seconds before checking the battery again.
    # Running `sleep` in the background and using `wait $!` ensures that 
    # if you press Ctrl+C, the script intercepts it immediately rather than 
    # waiting for the 60-second sleep cycle to finish.
    sleep 60 &
    wait $!
done
