#!/bin/bash

echo "Checking GlobalProtect status..."

# Check if the GlobalProtect app is currently running in the background
if pgrep "GlobalProtect" > /dev/null; then
    echo "Status: ON. Preparing to stop..."
    echo "Please use Touch ID to authorize shutting down the background service."
    
    # Unload the system daemon (This triggers the Touch ID prompt)
    sudo launchctl unload /Library/LaunchDaemons/com.paloaltonetworks.gp.pangps.plist
    
    # Unload the user agent and kill the app UI
    launchctl unload /Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist 2>/dev/null
    killall GlobalProtect 2>/dev/null
    
    echo "GlobalProtect has been successfully turned OFF."
else
    echo "Status: OFF. Preparing to start..."
    echo "Please use Touch ID to authorize starting the background service."
    
    # Load the system daemon (This triggers the Touch ID prompt)
    sudo launchctl load -w /Library/LaunchDaemons/com.paloaltonetworks.gp.pangps.plist
    
    # Load the user agent and open the app UI
    #launchctl load -w /Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist 2>/dev/null
    open -a GlobalProtect
    
    echo "GlobalProtect has been successfully turned ON."
fi

# Close the Terminal window automatically after 3 seconds
#sleep 3
#killall Terminal
