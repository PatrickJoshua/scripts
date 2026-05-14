#!/bin/bash

# Function to safely re-enable sleep
restore_sleep() {
    echo -e "\nRe-enabling sleep mode..."
    sudo pmset -a disablesleep 0
    echo "Sleep re-enabled. Safe to pack up!"
    exit 0
}

# Catch Ctrl+C or terminal termination to ensure sleep is ALWAYS re-enabled
trap restore_sleep SIGINT SIGTERM

echo "Disabling sleep mode (you may be prompted for your Mac password)..."
sudo pmset -a disablesleep 1
echo "✅ Sleep mode is DISABLED. You can now close the lid."
echo ""

# Wait silently for a single key press
read -n 1 -s -r -p "Press ANY key to re-enable sleep and exit..."

# Run the restore function when a key is pressed
restore_sleep
